import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

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

bool writeNdefText(ConnectedCard card, String text) {
  // Build simple NDEF Text record (UTF-8)
  final payload = <int>[];
  final languageCode = 'en';
  final langBytes = utf8.encode(languageCode);
  final textBytes = utf8.encode(text);

  // status byte: UTF-8 + length of language
  payload.add(langBytes.length & 0xFF);
  payload.addAll(langBytes);
  payload.addAll(textBytes);

  // NDEF record header (short record)
  final ndef = <int>[];
  final tnf = 0x01; // well-known
  final sr = 1; // short record
  final il = 0;
  final header = 0xD0 | (tnf & 0x07) | (sr << 4) | (il << 3);
  ndef.add(
      header); // 0xD1 or 0xD0 commonly; using D0 for no ID and short record
  ndef.add(0x01); // TYPE LENGTH = 1 ('T')
  ndef.add(payload.length); // PAYLOAD LENGTH (since SR = short record)
  ndef.addAll([0x54]); // TYPE = 'T'
  ndef.addAll(payload);

  // Wrap in NDEF TLV: 0x03 <len> <ndef> 0xFE (terminator)
  final tlv = <int>[];
  tlv.add(0x03);
  if (ndef.length < 0xFF) {
    tlv.add(ndef.length);
  } else {
    // for simplicity we don't handle large NDEFs here
    print('NDEF too large');
    return false;
  }
  tlv.addAll(ndef);
  tlv.add(0xFE);

  // Now write TLV into tag memory pages. For NTAG21x, user memory starts at page 4 (page = 4..)
// We'll write 4 bytes at a time (pages are 4 bytes)
  final bytes = Uint8List.fromList(tlv);
  int page = 4; // common start page for NDEF on many Type 2 tags
  int offset = 0;

  while (offset < bytes.length) {
    // build 4-byte chunk (pad with 0x00)
    final chunk = List<int>.filled(4, 0x00);
    for (int i = 0; i < 4 && offset < bytes.length; i++, offset++) {
      chunk[i] = bytes[offset];
    }

    // ACR122 write page APDU: FF D6 00 <page> 04 <4 bytes>
    final apdu = <int>[0xFF, 0xD6, 0x00, page & 0xFF, 0x04, ...chunk];
    final resp = sendApdu(card, apdu);
    if (!_isSuccessResponse(resp)) {
      print(
          'Failed writing page $page: ${resp.map((b) => b.toRadixString(16))}');
      return false;
    }
    page++;
  }

  print('NDEF write complete');
  return true;
}

String? readNdefText(ConnectedCard card) {
  int page = 4;
  final fullData = <int>[];

  while (true) {
    // Read 4 bytes (1 page) using APDU: FF B0 00 <page> 04
    final apdu = <int>[0xFF, 0xB0, 0x00, page & 0xFF, 0x04];
    final resp = sendApdu(card, apdu);
    if (resp.length < 2) {
      print('Invalid response');
      return null;
    }

    // Extract data (excluding status words)
    final data = resp.sublist(0, resp.length - 2);
    fullData.addAll(data);

    // Check for terminator TLV 0xFE
    if (data.contains(0xFE) || fullData.length > 64) {
      break;
    }
    page++;
  }

  // Parse NDEF TLV: 0x03 <length> <NDEF payload> 0xFE
  final index03 = fullData.indexOf(0x03);
  if (index03 == -1 || index03 + 1 >= fullData.length) {
    print('No NDEF TLV found');
    return null;
  }

  final length = fullData[index03 + 1];
  final ndefStart = index03 + 2;

  if (ndefStart + length > fullData.length) {
    print('NDEF payload incomplete');
    return null;
  }

  final ndef = fullData.sublist(ndefStart, ndefStart + length);

  // Check if it's a text record (TNF 0x01, type 'T')
  if (ndef.length < 4 || ndef[0] != 0xD1 || ndef[3] != 0x54) {
    print('Not a text NDEF record');
    return null;
  }

  final payloadLength = ndef[2];
  final statusByte = ndef[4];
  final langCodeLen = statusByte & 0x3F;

  if (5 + langCodeLen > ndef.length) {
    print('Malformed NDEF payload');
    return null;
  }

  // final textBytes = ndef.sublist(5 + langCodeLen, 5 + payloadLength);
  // final textBytes = ndef.sublist(5 + langCodeLen, 5 + payloadLength);
  // return utf8.decode(textBytes);
  try {
    final payloadLength = ndef[2];
    final statusByte = ndef[4];
    final langCodeLen = statusByte & 0x3F;
    final textStart = 5 + langCodeLen;
    final textBytes =
        ndef.sublist(textStart, textStart + payloadLength - langCodeLen - 1);
    return utf8.decode(textBytes);
  } catch (e) {
    print('NDEF parsing error: $e');
    return null;
  }
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

    pbSendBuffer.asTypedList(command.length).setAll(0, command);
    pcbRecvLength.value = 256;

    // Select correct PCI based on protocol
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

    final response = pbRecvBuffer.asTypedList(pcbRecvLength.value);
    malloc.free(pbRecvBuffer);
    malloc.free(pcbRecvLength);
    return Uint8List.fromList(response);
  }
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
