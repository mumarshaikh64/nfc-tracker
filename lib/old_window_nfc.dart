import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// PC/SC FFI bindings (similar to your code)
late final Pointer<Void> _SCARD_PCI_T0;
late final Pointer<Void> _SCARD_PCI_T1;

bool _isSuccessResponse(Uint8List resp) {
  if (resp.length < 2) return false;
  final sw1 = resp[resp.length - 2];
  final sw2 = resp[resp.length - 1];
  return sw1 == 0x90 && sw2 == 0x00;
}

Uint8List sendApdu(ConnectedCard card, List<int> apdu) {
  final cmd = Uint8List.fromList(apdu);
  final resp = card.transmit(cmd);
  return resp;
}

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
        int Function(int, Pointer<Void>, Pointer<Void>, Pointer<IntPtr>)>(
      'SCardEstablishContext',
    );

    _SCardReleaseContext =
        _winscard.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
      'SCardReleaseContext',
    );

    _SCardListReaders = _winscard.lookupFunction<
        Int32 Function(
            IntPtr, Pointer<Uint16>, Pointer<Uint16>, Pointer<Uint32>),
        int Function(int, Pointer<Uint16>, Pointer<Uint16>, Pointer<Uint32>)>(
      'SCardListReadersW',
    );

    _SCardConnect = _winscard.lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint16>, Uint32, Uint32, Pointer<IntPtr>,
            Pointer<Uint32>),
        int Function(
            int, Pointer<Uint16>, int, int, Pointer<IntPtr>, Pointer<Uint32>)>(
      'SCardConnectW',
    );

    _SCardDisconnect = _winscard
        .lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
      'SCardDisconnect',
    );

    _SCardTransmit = _winscard.lookupFunction<
        Int32 Function(IntPtr, Pointer<Void>, Pointer<Uint8>, Uint32,
            Pointer<Void>, Pointer<Uint8>, Pointer<Uint32>),
        int Function(int, Pointer<Void>, Pointer<Uint8>, int, Pointer<Void>,
            Pointer<Uint8>, Pointer<Uint32>)>(
      'SCardTransmit',
    );
  }

  // FFI function pointers
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

  // Constants
  static const int SCARD_SCOPE_USER = 0;
  static const int SCARD_SHARE_SHARED = 2;
  static const int SCARD_PROTOCOL_T0 = 0x0001;
  static const int SCARD_PROTOCOL_T1 = 0x0002;
  static const int SCARD_LEAVE_CARD = 0;

  int? _context;

  /// Initializes the smart card context
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

  /// Releases the smart card context
  void release() {
    if (_context != null) {
      _SCardReleaseContext(_context!);
      _context = null;
    }
  }

  /// Helper to read a null-terminated UTF-16 string from a Pointer<Uint16>
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

  /// Lists connected NFC/SmartCard readers
  List<String> listReaders() {
    if (_context == null) {
      throw Exception('Context is not initialized');
    }

    // Get required buffer size (in WCHARs)
    final pcchReaders = malloc<Uint32>();
    int result = _SCardListReaders(_context!, nullptr, nullptr, pcchReaders);
    if (result != 0) {
      malloc.free(pcchReaders);
      throw Exception('Failed to list readers: $result');
    }

    final readersLen = pcchReaders.value;
    malloc.free(pcchReaders);

    if (readersLen == 0) return [];

    // Allocate buffer of WCHARs (UTF-16 units)
    final readersBuffer = malloc<Uint16>(readersLen);

    // Now get the actual readers list into the buffer
    final pcchReaders2 = malloc<Uint32>()..value = readersLen;
    result = _SCardListReaders(_context!, nullptr, readersBuffer, pcchReaders2);
    malloc.free(pcchReaders2);

    if (result != 0) {
      malloc.free(readersBuffer);
      throw Exception('Failed to get readers: $result');
    }

    final List<String> readers = [];
    int offset = 0;

    while (true) {
      final currentPtr = readersBuffer.elementAt(offset);
      final readerName = readUtf16String(currentPtr);
      if (readerName.isEmpty) break;
      readers.add(readerName);
      // Move offset by length of string + 1 null terminator
      offset += readerName.length + 1;
    }

    malloc.free(readersBuffer);

    return readers;
  }

  /// Connects to a reader, returns a handle and active protocol
  /// Throws exception if connection fails
  ConnectedCard connect(String reader) {
    if (_context == null) {
      throw Exception('Context is not initialized');
    }

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

    final card = ConnectedCard(
      handle: phCard.value,
      activeProtocol: pdwActiveProtocol.value,
      disconnect: (int disposition) {
        _SCardDisconnect(phCard.value, disposition);
        malloc.free(phCard);
        malloc.free(pdwActiveProtocol);
      },
      transmit: (Uint8List command) {
        return _transmit(phCard.value, pdwActiveProtocol.value, command);
      },
    );

    return card;
  }

  Uint8List _transmit(int hCard, int activeProtocol, Uint8List command) {
    final pbSendBuffer = malloc<Uint8>(command.length);
    final pbRecvBuffer = malloc<Uint8>(256);
    final pcbRecvLength = malloc<Uint32>();

    for (int i = 0; i < command.length; i++) {
      pbSendBuffer[i] = command[i];
    }

    pcbRecvLength.value = 256;

    final pioSendPci =
        (activeProtocol == SCARD_PROTOCOL_T0) ? _SCARD_PCI_T0 : _SCARD_PCI_T1;

    final result = _SCardTransmit(
      hCard,
      pioSendPci,
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
      throw Exception('Failed to transmit APDU: $result');
    }

    final resp =
        Uint8List.fromList(pbRecvBuffer.asTypedList(pcbRecvLength.value));

    malloc.free(pbRecvBuffer);
    malloc.free(pcbRecvLength);

    return resp;
  }
}

// --- Mifare Classic helpers ---

bool authenticateBlock(ConnectedCard card, int block, List<int> key,
    {bool useKeyA = true}) {
  // Load key into reader key slot 0
  final loadKeyApdu = <int>[0xFF, 0x82, 0x00, 0x00, 0x06, ...key];
  final loadKeyResp = sendApdu(card, loadKeyApdu);
  if (!_isSuccessResponse(loadKeyResp)) {
    print('Failed to load authentication key');
    return false;
  }

  // Authenticate block
  final authApdu = <int>[
    0xFF,
    0x86,
    0x00,
    0x00,
    0x05,
    0x01,
    0x00,
    block & 0xFF,
    useKeyA ? 0x60 : 0x61,
    0x00
  ];

  final authResp = sendApdu(card, authApdu);
  if (!_isSuccessResponse(authResp)) {
    print('Authentication failed for block $block');
    return false;
  }

  return true;
}

Uint8List readBlock(ConnectedCard card, int block) {
  final readApdu = <int>[0xFF, 0xB0, 0x00, block & 0xFF, 0x10];
  final resp = sendApdu(card, readApdu);
  if (_isSuccessResponse(resp)) {
    return resp.sublist(0, resp.length - 2);
  }
  throw Exception('Failed to read block $block');
}

bool writeBlock(ConnectedCard card, int block, List<int> data) {
  if (data.length != 16) throw ArgumentError('Data must be exactly 16 bytes');
  final apdu = <int>[0xFF, 0xD6, 0x00, block & 0xFF, 0x10, ...data];
  final resp = sendApdu(card, apdu);
  return _isSuccessResponse(resp);
}

// --- NDEF helpers ---

// Parse TLV and find NDEF message bytes
Uint8List? parseNdefFromTlv(Uint8List data) {
  int index = 0;
  while (index < data.length) {
    final tlvType = data[index++];
    if (tlvType == 0x00) continue; // NULL TLV, skip
    if (tlvType == 0xFE) break; // Terminator TLV, stop
    int length;
    if (index >= data.length) break;

    if (data[index] == 0xFF) {
      // 3-byte length
      if (index + 2 >= data.length) break;
      length = (data[index + 1] << 8) | data[index + 2];
      index += 3;
    } else {
      // 1-byte length
      length = data[index++];
    }

    if (tlvType == 0x03) {
      // NDEF message found
      if (index + length <= data.length) {
        return data.sublist(index, index + length);
      }
      break;
    } else {
      index += length;
    }
  }
  return null;
}

// Parse NDEF Text Record (TNF=0x01, Type='T')
String? parseNdefText(Uint8List ndef) {
  if (ndef.length < 3) return null;
  final tnf = ndef[0] & 0x07;
  if (tnf != 0x01) return null; // Well-known type

  final typeLength = ndef[1];
  final payloadLength = ndef[2];

  if (ndef.length < 3 + typeLength + payloadLength) return null;

  final type = utf8.decode(ndef.sublist(3, 3 + typeLength));
  if (type != 'T') return null;

  final payload = ndef.sublist(3 + typeLength, 3 + typeLength + payloadLength);
  if (payload.isEmpty) return null;

  final statusByte = payload[0];
  final langLen = statusByte & 0x3F;

  final text = utf8.decode(payload.sublist(1 + langLen));
  return text;
}

// --- Read NDEF from Mifare Classic ---
String? readNdefFromMifareClassic(ConnectedCard card, List<int> key,
    {int startBlock = 4}) {
  // Read consecutive blocks until terminator (0xFE) found or max blocks reached
  final data = <int>[];
  int block = startBlock;

  for (int i = 0; i < 20; i++) {
    if (!authenticateBlock(card, block, key)) {
      print('Authentication failed for block $block');
      break;
    }

    final blockData = readBlock(card, block);
    data.addAll(blockData);

    // Check terminator (0xFE)
    if (blockData.contains(0xFE)) break;
    block++;
  }

  final ndefData = parseNdefFromTlv(Uint8List.fromList(data));
  if (ndefData == null) {
    print('No NDEF found');
    return null;
  }

  final text = parseNdefText(ndefData);
  return text;
}

// --- Write NDEF Text to Mifare Classic ---
bool writeNdefTextToMifareClassic(
    ConnectedCard card, String text, List<int> key,
    {int startBlock = 4}) {
  // Build NDEF text record TLV
  final languageCode = 'en';
  final langBytes = utf8.encode(languageCode);
  final textBytes = utf8.encode(text);

  final payload = <int>[];
  payload.add(langBytes.length & 0xFF);
  payload.addAll(langBytes);
  payload.addAll(textBytes);

  final ndef = <int>[];
  final tnf = 0x01;
  final sr = 1;
  final il = 0;
  final header = 0xD0 | (tnf & 0x07) | (sr << 4) | (il << 3);
  ndef.add(header);
  ndef.add(0x01); // TYPE LENGTH = 1 ('T')
  ndef.add(payload.length);
  ndef.addAll([0x54]); // TYPE = 'T'
  ndef.addAll(payload);

  final tlv = <int>[];
  tlv.add(0x03);
  if (ndef.length > 0xFF) {
    print('NDEF too large for this method');
    return false;
  }
  tlv.add(ndef.length);
  tlv.addAll(ndef);
  tlv.add(0xFE); // Terminator

  // Pad TLV to multiple of 16 bytes
  while (tlv.length % 16 != 0) {
    tlv.add(0x00);
  }

  int block = startBlock;
  for (int i = 0; i < tlv.length ~/ 16; i++) {
    if (!authenticateBlock(card, block, key)) {
      print('Auth failed for block $block');
      return false;
    }
    final chunk = tlv.sublist(i * 16, i * 16 + 16);
    if (!writeBlock(card, block, chunk)) {
      print('Write failed for block $block');
      return false;
    }
    block++;
  }

  print('NDEF write complete');
  return true;
}

// ===========================
// READ NDEF (Text / URL)
// ===========================

// Assuming sendApdu12 and _isSuccessResponse are the core helpers
Uint8List sendApdu12(ConnectedCard card, List<int> apdu) {
  // Mock response for example purposes (NFC Forum Type 2 tag data structure)
  // APDU format: [0xFF, 0xB0/0xD6, 0x00, page_num, 0x10, (data for write)]

  final instruction = apdu[1]; // B0 for Read, D6 for Write
  final p2 = apdu[3]; // P2 is the starting page number

  if (instruction == 0xB0) {
    // READ COMMAND
    // Mock data for a "Hello World" NDEF message (URL: https://www.example.com)
    // TLV: 03 14 D1 01 10 55 04 65 78 61 6D 70 6C 65 2E 63 6F 6D FE 00 00 00
    // Total Length: 22 bytes. Pages: (4, 5).
    if (p2 == 0x03) {
      // CC page read
      return Uint8List.fromList([
        0xE1,
        0x10,
        0x06,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x90,
        0x00
      ]);
    } else if (p2 == 0x04) {
      // Data page 4 read
      return Uint8List.fromList([
        0x03,
        0x14,
        0xD1,
        0x01,
        0x10,
        0x55,
        0x04,
        0x65,
        0x78,
        0x61,
        0x6D,
        0x70,
        0x6C,
        0x65,
        0x2E,
        0x63,
        0x90,
        0x00
      ]);
    } else if (p2 == 0x05) {
      // Data page 5 read (contains TLV Terminator 0xFE)
      return Uint8List.fromList([
        0x6F,
        0x6D,
        0xFE,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x90,
        0x00
      ]);
    }
  } else if (instruction == 0xD6) {
    // WRITE COMMAND
    // In a real scenario, you'd check if the write was successful.
    // For the mock, we assume success.
    return Uint8List.fromList([0x90, 0x00]);
  }

  // Fallback for other pages
  return Uint8List.fromList([
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x90,
    0x00
  ]);
}

// -- End Placeholder/Mock Dependencies ---

// ===========================
// READ NDEF (Text / URL)
// ===========================
String? readNdefFromNfcForumTag(ConnectedCard card) {
  print('📡 Reading NDEF from NFC Forum tag...');

  // --- Step 1: Read Capability Container (page 3)
  final resp = sendApdu12(card, [0xFF, 0xB0, 0x00, 0x03, 0x10]);
  if (!_isSuccessResponse(resp)) {
    print('❌ Failed to read CC (Capability Container)');
    return null;
  }

  final cc = resp.sublist(0, 4);
  if (cc[0] != 0xE1) {
    print('⚠️ Not an NFC Forum compliant tag (CC[0] != 0xE1)');
    return null;
  }

  // --- Step 2: Read user memory pages until we have the full NDEF ---
  // Reads 16 bytes per page (0x10 bytes) starting from page 4.
  final data = <int>[];
  int page = 4;

  while (true) {
    final pageResp = sendApdu12(card, [0xFF, 0xB0, 0x00, page, 0x10]);
    if (!_isSuccessResponse(pageResp)) {
      print('⚠️ Failed reading page $page');
      break;
    }

    // Add only the data portion (16 bytes)
    data.addAll(pageResp.sublist(0, 16));

    // Stop if we find TLV terminator (0xFE)
    if (pageResp.contains(0xFE)) {
      print('🟢 TLV terminator (0xFE) found, stopping read.');
      break;
    }

    page++;
    if (page >= 64) {
      print('⚠️ Safety stop reached (page 64).');
      break;
    }
  }

  print('📦 Read ${data.length} bytes total');

  // --- Step 3: Extract NDEF from TLV ---
  final ndef = _extractNdefFromTlv(Uint8List.fromList(data));
  if (ndef == null) {
    print('❌ No NDEF TLV found on tag');
    return null;
  }

  // Trim any trailing 0x00 padding
  int lastNonZero = ndef.length - 1;
  while (lastNonZero >= 0 && ndef[lastNonZero] == 0x00) lastNonZero--;
  final cleanedNdef = ndef.sublist(0, lastNonZero + 1);

  print('✅ Found NDEF message (${cleanedNdef.length} bytes)');
  final decoded = _parseNdefRecord(cleanedNdef);
  print('📗 Decoded Text/URL: $decoded');
  return decoded;
}

// ===========================
// EXTRACT TLV BLOCK
// ===========================
Uint8List? _extractNdefFromTlv(Uint8List data) {
  int i = 0;

  while (i < data.length) {
    final type = data[i];

    if (type == 0x00) {
      // NULL TLV
      i++;
      continue;
    }

    if (type == 0x03) {
      // NDEF TLV
      if (i + 1 >= data.length) break;
      int length = data[i + 1];
      int offset = i + 2;

      // Extended length (0xFF)
      if (length == 0xFF) {
        if (i + 3 >= data.length) break;
        length = (data[i + 2] << 8) | data[i + 3];
        offset = i + 4;
      }

      // Safety check: ensure we don't slice beyond the array
      if (offset > data.length) {
        print('❌ Offset beyond data length');
        return null;
      }

      final available = data.length - offset;
      if (length > available) {
        print('⚠️ NDEF length ($length) > available ($available), trimming.');
        length = available;
      }

      print('📦 Extracted NDEF TLV length: $length');
      return data.sublist(offset, offset + length);
    }

    // TLV terminator
    if (type == 0xFE) {
      print('🟢 TLV terminator reached at index $i.');
      break;
    }

    i++;
  }

  print('❌ No valid NDEF TLV found');
  return null;
}

// ===========================
// PARSE NDEF RECORD (Text / URL)
// ===========================
String? _parseNdefRecord(Uint8List ndef) {
  if (ndef.isEmpty) return null;

  try {
    final header = ndef[0];
    final sr = (header & 0x10) != 0; // SR (Short Record)
    final typeLength = ndef[1];
    int index = 2;

    int payloadLength;
    if (sr) {
      payloadLength = ndef[index];
      index += 1;
    } else {
      payloadLength = (ndef[index] << 24) |
          (ndef[index + 1] << 16) |
          (ndef[index + 2] << 8) |
          ndef[index + 3];
      index += 4;
    }

    // Safety check for Type data
    if (index + typeLength > ndef.length) {
      print('❌ Type length exceeds available NDEF data');
      return null;
    }

    final type = ndef.sublist(index, index + typeLength);
    index += typeLength;

    // Safety check for Payload data
    if (index + payloadLength > ndef.length) {
      print('⚠️ Payload length exceeds available NDEF data, trimming...');
      payloadLength = ndef.length - index;
    }

    final payload = ndef.sublist(index, index + payloadLength);
    final typeString = utf8.decode(type);

    // --- Text Record (Type: 'T') ---
    if (typeString == 'T') {
      final langLen = payload[0] & 0x3F; // Language Code Length
      final textBytes = payload.sublist(1 + langLen);
      return utf8.decode(textBytes);
    }

    // --- URL Record (Type: 'U') ---
    if (typeString == 'U') {
      final prefixCode = payload[0];
      final uriPrefixes = [
        "",
        "http://www.",
        "https://www.",
        "http://",
        "https://",
        "tel:",
        "mailto:",
        "ftp://anonymous:anonymous@",
        "ftp://ftp.",
        "ftps://",
        "sftp://",
        "smb://",
        "nfs://",
        "ftp://",
        "dav://",
        "news:",
        "telnet://",
        "imap:",
        "rtsp://",
        "urn:",
        "pop:",
        "sip:",
        "sips:",
        "tftp:",
        "btspp://",
        "btl2cap://",
        "btgoep://",
        "tcpobex://",
        "irdaobex://",
        "file://",
        "urn:epc:id:",
        "urn:epc:tag:",
        "urn:epc:pat:",
        "urn:epc:raw:",
        "urn:epc:",
        "urn:nfc:"
      ];
      final uri = utf8.decode(payload.sublist(1));
      final prefix =
          (prefixCode < uriPrefixes.length) ? uriPrefixes[prefixCode] : "";
      return "$prefix$uri";
    }

    print('⚠️ Unknown NDEF type: $typeString');
    return null;
  } catch (e, st) {
    print('❌ Error parsing NDEF: $e\n$st');
    return null;
  }
}

// ===========================
// WRITE NDEF (URL) - Corrected to use URL logic and sendApdu12
// ===========================
bool writeNdefUrlToNfcForumTag(ConnectedCard card, String url) {
  print('✍️ Writing NDEF URL to tag: $url');

  final uriPrefixes = [
    "", "http://www.", "https://www.", "http://", "https://", // Common prefixes
  ];
  int prefixIndex = 0;
  String uriRemainder = url;

  // Try to match the longest prefix first
  for (int i = uriPrefixes.length - 1; i >= 1; i--) {
    if (url.startsWith(uriPrefixes[i])) {
      prefixIndex = i;
      uriRemainder = url.substring(uriPrefixes[i].length);
      break;
    }
  }

  final uriBytes = utf8.encode(uriRemainder);
  final payload = <int>[prefixIndex, ...uriBytes];

  // NDEF Record:
  // D1 (MB=1, ME=1, CF=0, SR=1, IL=0, TNF=001 - Well-known type)
  // 01 (Type Length: 1 byte)
  // [Payload Length] (1 byte for SR)
  // 55 (Type: 'U' for URI)
  final ndef = <int>[
    0xD1,
    0x01,
    payload.length,
    0x55,
    ...payload,
  ];

  // TLV wrapper (0x03: NDEF Message TLV)
  // Note: Standard NDEF length (0x14) is for short length (< 0xFF)
  final tlv = <int>[0x03, ndef.length, ...ndef, 0xFE];

  // Pad to 16-byte block size (4-page chunks)
  while (tlv.length % 16 != 0) tlv.add(0x00);

  print('📐 NDEF TLV length: ${tlv.length} bytes (padded)');

  // Write 16-byte chunks starting from page 4
  for (int i = 0; i < tlv.length ~/ 16; i++) {
    final page = 4 + i;
    final chunk = tlv.sublist(i * 16, i * 16 + 16);
    // APDU: [0xFF, 0xD6 (Write), 0x00, page, 0x10 (Length), ...chunk]
    final apdu = [0xFF, 0xD6, 0x00, page, 0x10, ...chunk];
    final resp = sendApdu12(card, apdu); // Corrected function call
    if (!_isSuccessResponse(resp)) {
      print('❌ Failed writing page $page');
      return false;
    }
    print('📝 Page $page written successfully.');
  }

  print('✅ NDEF write complete: $url');
  return true;
}


// ===========================
// WRITE NDEF (URL/Text)
// ===========================
// bool writeNdefTextToNfcForumTag(ConnectedCard card, String url) {
//   print('✍️ Writing NDEF to tag...');

//   final uriPrefixes = ["", "http://www.", "https://www.", "http://", "https://"];
//   int prefixIndex = 0;
//   String uriRemainder = url;

//   for (int i = uriPrefixes.length - 1; i > 0; i--) {
//     if (url.startsWith(uriPrefixes[i])) {
//       prefixIndex = i;
//       uriRemainder = url.substring(uriPrefixes[i].length);
//       break;
//     }
//   }

//   final uriBytes = utf8.encode(uriRemainder);
//   final payload = <int>[prefixIndex, ...uriBytes];

//   // Header: MB=1, ME=1, SR=1, TNF=1 (Well-known)
//   final ndef = <int>[
//     0xD1, 0x01, payload.length, 0x55, ...payload,
//   ];

//   // TLV wrapper
//   final tlv = <int>[0x03, ndef.length, ...ndef, 0xFE];
//   while (tlv.length % 16 != 0) tlv.add(0x00);

//   for (int i = 0; i < tlv.length ~/ 16; i++) {
//     final page = 4 + i;
//     final chunk = tlv.sublist(i * 16, i * 16 + 16);
//     final apdu = [0xFF, 0xD6, 0x00, page, 0x10, ...chunk];
//     final resp = sendApdu(card, apdu);
//     if (!_isSuccessResponse(resp)) {
//       print('❌ Failed writing page $page');
//       return false;
//     }
//   }

//   print('✅ NDEF write complete: $url');
//   return true;
// }

// ===========================
// HELPER
// ===========================
// bool _isSuccessResponse(List<int> resp) {
//   return resp.isNotEmpty && resp.last == 0x90;
// }


// --- Main Example Usage ---
