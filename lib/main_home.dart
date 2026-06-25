// ignore_for_file: sized_box_for_whitespace, unused_local_variable
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_tracker/mobile_layout.dart';
import 'package:nfc_tracker/nfc_service.dart';

import '/pc_layout.dart';

class MainHome extends StatefulWidget {
  const MainHome({super.key});

  @override
  State<MainHome> createState() => _MainHomeState();
}

class _MainHomeState extends State<MainHome> {
  NfcService? nfc;

  String? _uid;
  String? _error;
  Timer? _pollTimer;
  bool _isScanning = false;
  bool isWrite = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      nfc = NfcService();
      startNfcScanning();
    } else if (Platform.isAndroid || Platform.isIOS) {
      _startReading();
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      _pollTimer?.cancel();
      nfc!.release();
    }
    super.dispose();
  }

  Future<void> _startReading() async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("NFC not available on this device.")),
      );
      return;
    }

    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      try {
        final ndef = Ndef.from(tag);
        if (ndef == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Not a valid NDEF tag.")),
          );
          NfcManager.instance.stopSession();
          return;
        }

        final message = await ndef.read();
        final records = message.records;

        for (final record in records) {
          if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
              record.payload.isNotEmpty &&
              record.payload.first == 0x55) {
            final url = String.fromCharCodes(record.payload.skip(1));
            debugPrint("URL found: $url");

            final uri = Uri.parse(url);
            final userId = uri.queryParameters['userId'];

            if (userId != null) {
              debugPrint("Extracted userId: $userId");
              await fetchUserById(userId);
            } else {
              debugPrint("No userId found in URL.");
            }
            break;
          }
        }
      } catch (e) {
        debugPrint("NFC Read Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error reading tag: $e")),
        );
      } finally {
        NfcManager.instance.stopSession();
      }
    });
  }

// void startNfcScanning() async {
//   if (!_isScanning) {
//     final initialized = nfc!.initialize();
//     if (!initialized) {
//       setState(() { _error = 'Failed to initialize NFC'; });
//       return;
//     }

//     _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
//       try {
//         final readers = nfc!.listReaders();
//         if (readers.isEmpty) {
//           setState(() { _error = 'No NFC readers found'; _uid = null; });
//           return;
//         }

//         final card = nfc!.connect(readers.first);

//         // UID check
//         final command = <int>[0xFF, 0xCA, 0x00, 0x00, 0x00];
//         final response = card.transmit(Uint8List.fromList(command));
//         final sw1 = response[response.length - 2];
//         final sw2 = response[response.length - 1];
//         if (sw1 != 0x90 || sw2 != 0x00) throw Exception('Failed to read UID');

//         // ✅ readNdef — handles both URL (mobile) and Text (PC) records
//         final result = readNdef(card);
//         card.disconnect(NfcService.SCARD_LEAVE_CARD);

//         if (result == null) {
//           setState(() { _error = 'No NDEF data on tag'; _uid = null; });
//           return;
//         }

//         String? userId;

//         if (result.type == 'url') {
//           // Mobile ne URL likha tha — userId query param se nikalo
//           // e.g. "https://example.com?userId=123"
//           final uri = Uri.tryParse(result.value);
//           userId = uri?.queryParameters['userId'];

//           // agar puri URL hi userId hai (koi query param nahi)
//           userId ??= result.value;

//         } else {
//           // PC ne plain text likha tha — directly userId hai
//           userId = result.value;
//         }

//         if (userId == null || userId.isEmpty) {
//           setState(() { _error = 'No userId found in tag'; _uid = null; });
//           return;
//         }

//         setState(() { _uid = userId; _error = null; });
//         print(userId);
//         await fetchUserById(userId);

//       } catch (e) {
//         setState(() { _error = e.toString(); _uid = null; });
//       }
//     });

//     _isScanning = true;
//   }
// }

  void startNfcScanning() async {
    if (!_isScanning) {
      final initialized = nfc!.initialize();
      if (!initialized) {
        setState(() {
          _error = 'Failed to initialize NFC';
        });
        return;
      }

      _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        try {
          final readers = nfc!.listReaders();
          if (readers.isEmpty) {
            setState(() {
              _error = 'No NFC readers found';
              _uid = null;
            });
            return;
          }

          final card = nfc!.connect(readers.first);

          // UID check
          final command = <int>[0xFF, 0xCA, 0x00, 0x00, 0x00];
          final response = card.transmit(Uint8List.fromList(command));
          final sw1 = response[response.length - 2];
          final sw2 = response[response.length - 1];
          if (sw1 != 0x90 || sw2 != 0x00) throw Exception('Failed to read UID');

          final result = readNdef(card);
          card.disconnect(NfcService.SCARD_LEAVE_CARD);

          if (result == null) {
            setState(() {
              _error = 'No NDEF data on tag';
              _uid = null;
            });
            return;
          }

          String? userId;

          if (result.type == 'url') {
            // Mobile URL format: http://31.97.227.51:3300/users/view/60
            // userId URL ke last segment mein hota hai
            final uri = Uri.tryParse(result.value);
            if (uri != null) {
              // Pehle query param check karo: ?userId=123
              userId = uri.queryParameters['userId'];

              // Agar query param nahi toh path ka last segment lo
              // e.g. /users/view/60  →  '60'
              if (userId == null || userId.isEmpty) {
                final segments =
                    uri.pathSegments.where((s) => s.isNotEmpty).toList();
                if (segments.isNotEmpty) {
                  userId = segments.last;
                }
              }
            }
          } else {
            // PC ne plain text (userId) likha tha
            userId = result.value.trim();
          }

          if (userId == null || userId.isEmpty) {
            setState(() {
              _error = 'No userId found in tag';
              _uid = null;
            });
            return;
          }

          print('userId extracted: $userId');
          setState(() {
            _uid = userId;
            _error = null;
          });
          await fetchUserById(userId);
        } catch (e) {
          setState(() {
            _error = e.toString();
            _uid = null;
          });
        }
      });

      _isScanning = true;
    }
  }

  Map<String, dynamic> nfcData = <String, dynamic>{};
  Future<void> fetchUserById(String userId) async {
    final url = Uri.parse('http://31.97.227.51:3300/users/fetch/$userId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      setState(() {
        nfcData = data;
      });
    } else {
      print('Error fetching user: ${response.statusCode}');
    }
  }

  void stopNfcScanning() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isScanning = false;
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (width < 600) {
            return MobileLayout(
              onWrite: (d) {
                setState(() {
                  isWrite = d;
                });
                if (d) {
                  // STOP READING
                  if (Platform.isWindows) {
                    setState(() {
                      _isScanning =
                          true; // Mark as busy/scanning so startNfcScanning doesn't re-trigger immediately? Or maybe this logic is intended to block.
                    });
                    stopNfcScanning();
                  } else if (Platform.isAndroid || Platform.isIOS) {
                    // Mobile: Stop reading session
                    NfcManager.instance.stopSession().catchError((_) {});
                  }
                } else {
                  // START READING
                  if (Platform.isWindows) {
                    startNfcScanning();
                  } else if (Platform.isAndroid || Platform.isIOS) {
                    _startReading();
                  }
                }
              },
            );
          } else {
            return PcLayout(
              nfcData: nfcData,
              nfc: nfc,
              onRefresh: () {
                setState(() {
                  _isScanning = false;
                });
                if (Platform.isWindows) {
                  startNfcScanning();
                } else if (Platform.isAndroid || Platform.isIOS) {
                  _startReading();
                }
              },
              onWrite: (d) {
                setState(() {
                  isWrite = d;
                });
                if (d) {
                  if (Platform.isWindows) {
                    setState(() {
                      _isScanning = true;
                    });
                    stopNfcScanning();
                  } else if (Platform.isAndroid || Platform.isIOS) {
                    NfcManager.instance.stopSession().catchError((_) {});
                  }
                } else {
                  if (Platform.isWindows) {
                    startNfcScanning();
                  } else if (Platform.isAndroid || Platform.isIOS) {
                    _startReading();
                  }
                }
              },
            );
          }
        },
      ),
    );
  }
}
