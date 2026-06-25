import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

late final Pointer<Void> _SCARD_PCI_T0;
late final Pointer<Void> _SCARD_PCI_T1;

bool _isSuccessResponse(Uint8List resp) {
  if (resp.length < 2) return false;
  return resp[resp.length - 2] == 0x90 && resp[resp.length - 1] == 0x00;
}

Uint8List sendApdu(ConnectedCard card, List<int> apdu) {
  return card.transmit(Uint8List.fromList(apdu));
}

// ===========================================================================
// URL prefix table (NFC Forum URI identifier codes)
// ===========================================================================
const Map<int, String> _urlPrefixes = {
  0x00: '',
  0x01: 'http://www.',
  0x02: 'https://www.',
  0x03: 'http://',
  0x04: 'https://',
  0x05: 'tel:',
  0x06: 'mailto:',
};

// ===========================================================================
// WRITE — URL record (mobile ke saath compatible)
// Mobile NfcManager bhi URL (0x55) likhta hai, hum bhi same format mein likhein
// ===========================================================================
bool writeNdefUrl(ConnectedCard card, String url) {
  // Find best prefix
  int prefixCode = 0x00;
  String urlBody = url;

  if (url.startsWith('https://www.')) {
    prefixCode = 0x02;
    urlBody = url.substring('https://www.'.length);
  } else if (url.startsWith('http://www.')) {
    prefixCode = 0x01;
    urlBody = url.substring('http://www.'.length);
  } else if (url.startsWith('https://')) {
    prefixCode = 0x04;
    urlBody = url.substring('https://'.length);
  } else if (url.startsWith('http://')) {
    prefixCode = 0x03;
    urlBody = url.substring('http://'.length);
  }

  final urlBytes = utf8.encode(urlBody);

  // payload = prefixCode + urlBody bytes
  final payload = <int>[prefixCode, ...urlBytes];

  // NDEF record: 0xD1 = MB+ME+SR+TNF(0x01)
  final ndef = <int>[
    0xD1, // header — FIXED constant (not computed)
    0x01, // type length = 1
    payload.length, // payload length
    0x55, // type = 'U' (URL)
    ...payload,
  ];

  // TLV wrap: 0x03 <len> <ndef bytes> 0xFE
  if (ndef.length > 0xFF) {
    print('NDEF too large');
    return false;
  }
  final tlv = <int>[0x03, ndef.length, ...ndef, 0xFE];

  return _writePages(card, tlv);
}

// ===========================================================================
// WRITE — Text record (plain text, type 'T')
// ===========================================================================
bool writeNdefText(ConnectedCard card, String text) {
  final langBytes = utf8.encode('en');
  final textBytes = utf8.encode(text);

  final payload = <int>[
    langBytes.length & 0x3F, // status byte: UTF-8 encoding, lang length
    ...langBytes,
    ...textBytes,
  ];

  // NDEF record: 0xD1 = MB+ME+SR+TNF(0x01) — FIXED
  final ndef = <int>[
    0xD1, // header FIXED
    0x01, // type length = 1
    payload.length, // payload length
    0x54, // type = 'T' (Text)
    ...payload,
  ];

  if (ndef.length > 0xFF) {
    print('NDEF too large');
    return false;
  }
  final tlv = <int>[0x03, ndef.length, ...ndef, 0xFE];

  return _writePages(card, tlv);
}

// Write bytes to tag pages (4 bytes per page, starting at page 4)
bool _writePages(ConnectedCard card, List<int> tlv) {
  final bytes = Uint8List.fromList(tlv);
  int page = 4;
  int offset = 0;

  while (offset < bytes.length) {
    final chunk = List<int>.filled(4, 0x00);
    for (int i = 0; i < 4 && offset < bytes.length; i++, offset++) {
      chunk[i] = bytes[offset];
    }
    final apdu = <int>[0xFF, 0xD6, 0x00, page & 0xFF, 0x04, ...chunk];
    final resp = sendApdu(card, apdu);
    if (!_isSuccessResponse(resp)) {
      print(
          'Failed writing page $page: ${resp.map((b) => b.toRadixString(16)).toList()}');
      return false;
    }
    page++;
  }
  print('NDEF write complete');
  return true;
}

// ===========================================================================
// READ — handles BOTH URL (0x55) and Text (0x54) records
// Mobile se likha hua URL bhi padh sakta hai, PC ka text bhi
// ===========================================================================

class NdefReadResult {
  final String type; // 'url' or 'text'
  final String value; // full URL string or plain text

  NdefReadResult({required this.type, required this.value});

  @override
  String toString() => 'NdefReadResult(type=$type, value=$value)';
}

/// Reads NDEF from NFC tag — handles URL (mobile) and Text (PC) records
/// Fixed: properly skips CC/header bytes, handles 3-byte TLV length
NdefReadResult? readNdef(ConnectedCard card) {
  // -----------------------------------------------------------------------
  // Step 1: Read pages until 0xFE terminator or 256 bytes max
  // -----------------------------------------------------------------------
  int page = 4;
  final fullData = <int>[];

  while (fullData.length < 256) {
    final apdu = <int>[0xFF, 0xB0, 0x00, page & 0xFF, 0x04];
    final resp = sendApdu(card, apdu);

    if (resp.length < 3 || !_isSuccessResponse(resp)) {
      print('Read stopped at page $page');
      break;
    }

    final data = resp.sublist(0, resp.length - 2);
    fullData.addAll(data);

    if (data.contains(0xFE)) break;
    page++;
  }

  if (fullData.isEmpty) {
    print('No data read from tag');
    return null;
  }

  print(
      'Raw data: ${fullData.map((b) => b.toRadixString(16).padLeft(2, '0')).toList()}');

  // -----------------------------------------------------------------------
  // Step 2: Scan for TLV 0x03 properly
  // Skip NULL TLVs (0x00), stop at terminator (0xFE)
  // Each TLV: [type] [length or FF+2bytes] [value...]
  // -----------------------------------------------------------------------
  int i = 0;
  while (i < fullData.length) {
    final tlvType = fullData[i];
    i++;

    if (tlvType == 0x00) continue; // NULL TLV — skip, no length byte
    if (tlvType == 0xFE) break; // Terminator TLV — stop

    if (i >= fullData.length) break;

    // Read length
    int tlvLen;
    if (fullData[i] == 0xFF) {
      // 3-byte length format
      if (i + 2 >= fullData.length) {
        print('3-byte length incomplete');
        return null;
      }
      tlvLen = (fullData[i + 1] << 8) | fullData[i + 2];
      i += 3;
    } else {
      tlvLen = fullData[i];
      i += 1;
    }

    if (tlvType == 0x03) {
      // ✅ Found NDEF message TLV
      print('Found NDEF TLV at offset ${i - 2}, length=$tlvLen');

      if (i + tlvLen > fullData.length) {
        print(
            'NDEF payload incomplete: need ${i + tlvLen}, have ${fullData.length}');
        return null;
      }

      final ndefBytes = fullData.sublist(i, i + tlvLen);
      return _parseNdefRecord(ndefBytes);
    } else {
      // Other TLV — skip its value bytes
      i += tlvLen;
    }
  }

  print('No NDEF TLV (0x03) found');
  return null;
}

NdefReadResult? _parseNdefRecord(List<int> ndef) {
  print(
      'Parsing NDEF: ${ndef.map((b) => b.toRadixString(16).padLeft(2, '0')).toList()}');

  if (ndef.length < 4) {
    print('NDEF record too short: ${ndef.length} bytes');
    return null;
  }

  // NDEF record structure (Short Record, SR=1):
  // [0] header byte  (MB ME CF SR IL TNF)
  // [1] type length  (always 1 for well-known)
  // [2] payload length
  // [3] type byte    (0x54='T' or 0x55='U')
  // [4..] payload

  final header = ndef[0];
  final tnf = header & 0x07;
  final typeLen = ndef[1];
  final payloadLen = ndef[2];
  final recordType = ndef[3];

  print(
      'header=0x${header.toRadixString(16)} tnf=$tnf typeLen=$typeLen payloadLen=$payloadLen type=0x${recordType.toRadixString(16)}');

  if (tnf != 0x01) {
    print(
        'Unsupported TNF: 0x${tnf.toRadixString(16)} (expected 0x01 Well-Known)');
    return null;
  }
  if (typeLen != 1) {
    print('Unexpected type length: $typeLen');
    return null;
  }
  if (4 + payloadLen > ndef.length) {
    print(
        'Payload overflow: claims $payloadLen bytes but only ${ndef.length - 4} available');
    return null;
  }

  final payload = ndef.sublist(4, 4 + payloadLen);

  // -----------------------------------------------------------------------
  // URL record — Type 'U' = 0x55
  // payload[0] = URI prefix code
  // payload[1..] = URI body (without prefix)
  // -----------------------------------------------------------------------
  if (recordType == 0x55) {
    if (payload.isEmpty) {
      print('Empty URL payload');
      return null;
    }

    const prefixes = {
      0x00: '',
      0x01: 'http://www.',
      0x02: 'https://www.',
      0x03: 'http://',
      0x04: 'https://',
      0x05: 'tel:',
      0x06: 'mailto:',
    };

    final prefixCode = payload[0];
    final urlBody = utf8.decode(payload.sublist(1));
    final prefix = prefixes[prefixCode] ?? '';
    final fullUrl = '$prefix$urlBody';

    print('✅ Read URL: $fullUrl');
    return NdefReadResult(type: 'url', value: fullUrl);
  }

  // -----------------------------------------------------------------------
  // Text record — Type 'T' = 0x54
  // payload[0] = status byte (bit7=encoding, bits5-0=lang length)
  // payload[1..langLen] = language code (e.g. 'en')
  // payload[1+langLen..] = text
  // -----------------------------------------------------------------------
  if (recordType == 0x54) {
    if (payload.isEmpty) {
      print('Empty Text payload');
      return null;
    }

    final statusByte = payload[0];
    final langLen = statusByte & 0x3F;

    if (1 + langLen > payload.length) {
      print(
          'Malformed text: langLen=$langLen but only ${payload.length} payload bytes');
      return null;
    }

    final text = utf8.decode(payload.sublist(1 + langLen));
    print('✅ Read Text: $text');
    return NdefReadResult(type: 'text', value: text);
  }

  print('Unknown record type byte: 0x${recordType.toRadixString(16)}');
  return null;
}

/// Legacy wrapper — returns just the string value (url or text)
/// Use this as drop-in replacement for old readNdefText()
String? readNdefText(ConnectedCard card) {
  final result = readNdef(card);
  return result?.value;
}

// ===========================================================================
// NfcService
// ===========================================================================

class NfcService {
  late final DynamicLibrary _winscard;

  NfcService() {
    _winscard = DynamicLibrary.open('winscard.dll');
    _SCARD_PCI_T0 =
        _winscard.lookup<Pointer<Void>>('g_rgSCardT0Pci') as Pointer<Void>;
    _SCARD_PCI_T1 =
        _winscard.lookup<Pointer<Void>>('g_rgSCardT1Pci') as Pointer<Void>;

    _SCardEstablishContext = _winscard.lookupFunction<
        Int32 Function(Uint32, Pointer<Void>, Pointer<Void>, Pointer<IntPtr>),
        int Function(int, Pointer<Void>, Pointer<Void>,
            Pointer<IntPtr>)>('SCardEstablishContext');

    _SCardReleaseContext =
        _winscard.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
            'SCardReleaseContext');

    _SCardListReaders = _winscard.lookupFunction<
        Int32 Function(
            IntPtr, Pointer<Uint16>, Pointer<Uint16>, Pointer<Uint32>),
        int Function(int, Pointer<Uint16>, Pointer<Uint16>,
            Pointer<Uint32>)>('SCardListReadersW');

    _SCardConnect = _winscard.lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint16>, Uint32, Uint32, Pointer<IntPtr>,
            Pointer<Uint32>),
        int Function(int, Pointer<Uint16>, int, int, Pointer<IntPtr>,
            Pointer<Uint32>)>('SCardConnectW');

    _SCardDisconnect = _winscard.lookupFunction<Int32 Function(IntPtr, Uint32),
        int Function(int, int)>('SCardDisconnect');

    _SCardTransmit = _winscard.lookupFunction<
        Int32 Function(IntPtr, Pointer<Void>, Pointer<Uint8>, Uint32,
            Pointer<Void>, Pointer<Uint8>, Pointer<Uint32>),
        int Function(int, Pointer<Void>, Pointer<Uint8>, int, Pointer<Void>,
            Pointer<Uint8>, Pointer<Uint32>)>('SCardTransmit');
  }

  late final int Function(int, Pointer<Void>, Pointer<Void>, Pointer<IntPtr>)
      _SCardEstablishContext;
  late final int Function(int) _SCardReleaseContext;
  late final int Function(
      int, Pointer<Uint16>, Pointer<Uint16>, Pointer<Uint32>) _SCardListReaders;
  late final int Function(
          int, Pointer<Uint16>, int, int, Pointer<IntPtr>, Pointer<Uint32>)
      _SCardConnect;
  late final int Function(int, int) _SCardDisconnect;
  late final int Function(int, Pointer<Void>, Pointer<Uint8>, int,
      Pointer<Void>, Pointer<Uint8>, Pointer<Uint32>) _SCardTransmit;

  static const int SCARD_SCOPE_USER = 0;
  static const int SCARD_SHARE_SHARED = 2;
  static const int SCARD_PROTOCOL_T0 = 0x0001;
  static const int SCARD_PROTOCOL_T1 = 0x0002;
  static const int SCARD_LEAVE_CARD = 0;

  int? _context;

  bool initialize() {
    final phContext = malloc<IntPtr>();
    final result =
        _SCardEstablishContext(SCARD_SCOPE_USER, nullptr, nullptr, phContext);
    if (result != 0) {
      malloc.free(phContext);
      print('Failed to establish context: $result');
      return false;
    }
    _context = phContext.value;
    malloc.free(phContext);
    return true;
  }

  void release() {
    if (_context != null) {
      _SCardReleaseContext(_context!);
      _context = null;
    }
  }

  String readUtf16String(Pointer<Uint16> ptr) {
    final units = <int>[];
    int offset = 0;
    while (true) {
      final char = ptr.elementAt(offset).value;
      if (char == 0) break;
      units.add(char);
      offset++;
    }
    return String.fromCharCodes(units);
  }

  List<String> listReaders() {
    if (_context == null) throw Exception('Context is not initialized');

    final pcchReaders = malloc<Uint32>();
    int result = _SCardListReaders(_context!, nullptr, nullptr, pcchReaders);
    if (result != 0) {
      malloc.free(pcchReaders);
      throw Exception('Failed to list readers: $result');
    }

    final readersLen = pcchReaders.value;
    malloc.free(pcchReaders);
    if (readersLen == 0) return [];

    final readersBuffer = malloc<Uint16>(readersLen);
    final pcchReaders2 = malloc<Uint32>()..value = readersLen;
    result = _SCardListReaders(_context!, nullptr, readersBuffer, pcchReaders2);
    malloc.free(pcchReaders2);

    if (result != 0) {
      malloc.free(readersBuffer);
      throw Exception('Failed to get readers: $result');
    }

    final readers = <String>[];
    int offset = 0;
    while (true) {
      final readerName = readUtf16String(readersBuffer.elementAt(offset));
      if (readerName.isEmpty) break;
      readers.add(readerName);
      offset += readerName.length + 1;
    }

    malloc.free(readersBuffer);
    return readers;
  }

  ConnectedCard connect(String reader) {
    if (_context == null) throw Exception('Context is not initialized');

    final readerPtr = reader.toNativeUtf16().cast<Uint16>();
    final phCard = malloc<IntPtr>();
    final pdwActiveProtocol = malloc<Uint32>();

    final result = _SCardConnect(
      _context!,
      readerPtr,
      SCARD_SHARE_SHARED,
      SCARD_PROTOCOL_T0 | SCARD_PROTOCOL_T1,
      phCard,
      pdwActiveProtocol,
    );

    malloc.free(readerPtr);

    if (result != 0) {
      malloc.free(phCard);
      malloc.free(pdwActiveProtocol);
      throw Exception('Failed to connect to card: $result');
    }

    return ConnectedCard(
      handle: phCard.value,
      activeProtocol: pdwActiveProtocol.value,
      disconnect: (int disposition) {
        _SCardDisconnect(phCard.value, disposition);
        malloc.free(phCard);
        malloc.free(pdwActiveProtocol);
      },
      transmit: (Uint8List command) =>
          _transmit(phCard.value, pdwActiveProtocol.value, command),
    );
  }

  Uint8List _transmit(int hCard, int activeProtocol, Uint8List command) {
    final pbSendBuffer = malloc<Uint8>(command.length);
    final pbRecvBuffer = malloc<Uint8>(256);
    final pcbRecvLength = malloc<Uint32>()..value = 256;

    pbSendBuffer.asTypedList(command.length).setAll(0, command);

    Pointer<Void> pci;
    if (activeProtocol == SCARD_PROTOCOL_T0) {
      pci = _SCARD_PCI_T0;
    } else if (activeProtocol == SCARD_PROTOCOL_T1) {
      pci = _SCARD_PCI_T1;
    } else {
      malloc.free(pbSendBuffer);
      malloc.free(pbRecvBuffer);
      malloc.free(pcbRecvLength);
      throw Exception('Unsupported protocol: $activeProtocol');
    }

    final result = _SCardTransmit(
      hCard,
      pci,
      pbSendBuffer,
      command.length,
      nullptr,
      pbRecvBuffer,
      pcbRecvLength,
    );

    malloc.free(pbSendBuffer);

    if (result != 0) {
      malloc.free(pbRecvBuffer);
      malloc.free(pcbRecvLength);
      throw Exception('Transmit failed: $result');
    }

    final response =
        Uint8List.fromList(pbRecvBuffer.asTypedList(pcbRecvLength.value));
    malloc.free(pbRecvBuffer);
    malloc.free(pcbRecvLength);
    return response;
  }
}

// ===========================================================================
// ConnectedCard
// ===========================================================================

class ConnectedCard {
  final int handle;
  final int activeProtocol;
  final void Function(int disposition) disconnect;
  final Uint8List Function(Uint8List command) transmit;

  ConnectedCard({
    required this.handle,
    required this.activeProtocol,
    required this.disconnect,
    required this.transmit,
  });
}
