// // ignore_for_file: sized_box_for_whitespace, deprecated_member_use, unnecessary_null_comparison

// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';

// import 'package:flutter/material.dart';
// // import 'package:flutter_image_compress/flutter_image_compress.dart';
// import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:ndef/ndef.dart' as ndef;
// import 'package:image/image.dart' as img; // for resizing

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   String _nfcData = "Scan an NFC tag...";
//   Map<String, dynamic> nfcData = {};

//   // Write tab variables
//   String selectedType = "Text";
//   final TextEditingController _controller = TextEditingController();
//   String writeStatus = "";

//   File? _pickedImage;
//   final ImagePicker _picker = ImagePicker();

//   Future<void> _pickImage() async {
//     final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
//     if (image != null) {
//       setState(() {
//         _pickedImage = File(image.path);
//       });
//     }
//   }

//   bool _isBase64(String str) {
//     try {
//       if (str.isEmpty) return false;

//       // Remove whitespace / line breaks
//       String cleaned = str.replaceAll(RegExp(r'\s+'), '');

//       // Optional: Fix padding
//       while (cleaned.length % 4 != 0) {
//         cleaned += "=";
//       }

//       // Try decode
//       base64Decode(cleaned);
//       return true;
//     } catch (_) {
//       return false;
//     }
//   }

//   Future<void> _startNFCRead() async {
//     Map<String, dynamic> data = {};
//     try {
//       NFCTag tag = await FlutterNfcKit.poll();
//       data['nfcId'] = tag.id;
//       data['standard'] = tag.standard;
//       data['type'] = tag.ndefType ?? tag.type;
//       data['sak'] = tag.sak;
//       data['protocol'] = tag.protocolInfo;
//       data['applicationData'] = tag.applicationData;
//       data['hiLayerResponse'] = tag.hiLayerResponse;

//       try {
//         List<ndef.NDEFRecord> records = await FlutterNfcKit.readNDEFRecords();
//         if (records.isNotEmpty) {
//           for (var record in records) {
//             String payloadText = "";
//             try {
//               payloadText = utf8.decode(record.payload!);
//             } catch (_) {
//               payloadText = record.payload.toString();
//             }

//             // Strip language prefix (en, etc.)
//             if (payloadText.length > 2) {
//               payloadText = payloadText.substring(2);
//             }

//             print(
//               "📡 Payload: $payloadText is Converted ${_isBase64(payloadText)}",
//             );

//             if (payloadText.startsWith("n")) {
//               payloadText = payloadText.substring(1);
//             }

//             // ✅ If Base64 Image
//             if (_isBase64(payloadText)) {
//               try {
//                 // Fix padding if needed
//                 String textImage = payloadText;
//                 while (textImage.length % 4 != 0) {
//                   textImage += "=";
//                 }

//                 Uint8List imgBytes = base64Decode(payloadText);
//                 data['result'] = imgBytes; // ✅ Save as image bytes
//               } catch (e) {
//                 print("❌ Base64 decode failed: $e");
//                 data['result'] = "(Invalid image data)";
//               }
//             } else {
//               // Normal text / link
//               data['result'] = payloadText;
//             }
//           }
//         } else {
//           data['result'] = "\n(No NDEF records found)";
//         }
//       } catch (e) {
//         data['result'] = "\n(NDEF read failed: $e)";
//       }

//       setState(() {
//         nfcData = data;
//       });

//       await FlutterNfcKit.finish();
//     } catch (e) {
//       setState(() {
//         _nfcData = "Error: $e";
//       });
//     }
//   }

//   // Yeh function image ko compress karke ~120 bytes ka Base64 return karega
//   Future<String> getSmallBase64(Uint8List originalBytes) async {
//     // Step 1: Compress (resize + low quality)
//     Uint8List? compressed = await FlutterImageCompress.compressWithList(
//       originalBytes,
//       minHeight: 10, // super small size
//       minWidth: 10,
//       quality: 10, // very low quality
//     );

//     if (compressed == null) {
//       throw Exception("Compression failed");
//     }

//     // Step 2: Limit raw bytes (Base64 ~33% bada hota hai)
//     // 90 bytes raw ≈ 120 bytes Base64
//     Uint8List limited = compressed.length > 90
//         ? compressed.sublist(0, 90)
//         : compressed;

//     // Step 3: Convert to Base64
//     String base64Img = base64Encode(limited);

//     print("📏 Final Base64 size: ${base64Img.length} bytes");
//     print("🖼 Base64: $base64Img");

//     return base64Img;
//   }

//   Future<String?> compressImageForNFC(
//     Uint8List originalBytes,
//     int maxSize,
//   ) async {
//     int quality = 90;
//     Uint8List? compressed;
//     while (quality > 10) {
//       compressed = await FlutterImageCompress.compressWithList(
//         originalBytes,
//         minHeight: 20,
//         minWidth: 20,
//         quality: quality,
//       );

//       if (compressed.length <= maxSize) {
//         return base64Encode(compressed);
//       }
//       quality -= 10; // reduce further
//     }

//     // ❌ Too big even after max compression
//     return null;
//   }

//   Future<String> createTinyImage() async {
//     // 1x1 white image create
//     final image = img.Image(width: 1, height: 1);
//     image.setPixel(0, 0, img.ColorFloat16.rgb(255, 0, 0));

//     // Encode as PNG
//     final pngBytes = Uint8List.fromList(img.encodePng(image));

//     print("Image bytes length: ${pngBytes.length}"); // ~67 bytes ✅

//     // Save as file
//     // final file = File("tiny.png");
//     // await file.writeAsBytes(pngBytes);

//     // Convert to base64 for NFC
//     final base64Img = base64Encode(pngBytes);
//     print("Base64 length: ${base64Img.length}");
//     print("Base64: $base64Img");
//     return base64Img;
//   }

//   Future<void> _startNFCWrite() async {
//     try {
//       NFCTag tag = await FlutterNfcKit.poll();
//       print("Tag capacity: ${tag.ndefCapacity} bytes");

//       ndef.NDEFRecord record;

//       switch (selectedType) {
//         case "Text":
//           record = ndef.TextRecord(text: _controller.text, language: "en");
//           break;
//         case "Link":
//           record = ndef.UriRecord.fromString(_controller.text);
//           break;
//         case "Number":
//           record = ndef.TextRecord(text: _controller.text, language: "en");
//           break;
//         case "Image":
//           if (_pickedImage != null) {
//             Uint8List bytes = await _pickedImage!.readAsBytes();
//             // String? base64Img = await compressImageForNFC(bytes, 90);
//             // print(base64Img);

//             // // Check size before writing
//             // if (base64Img == null) {
//             //   // 90 bytes raw ≈ 120 Base64, adjust as needed
//             //   setState(() {
//             //     writeStatus =
//             //         "❌ Image too large (${bytes.length} bytes). Use a smaller image.";
//             //   });
//             //   await FlutterNfcKit.finish();
//             //   return; // Stop writing
//             // }
//             String base64Img = await createTinyImage();
//             record = ndef.TextRecord(text: base64Img, language: "en");
//           } else {
//             setState(() {
//               writeStatus = "❌ No image selected";
//             });
//             await FlutterNfcKit.finish();
//             return;
//           }
//           break;
//         default:
//           record = ndef.TextRecord(text: _controller.text, language: "en");
//       }

//       // Write record
//       await FlutterNfcKit.writeNDEFRecords([record]);
//       await FlutterNfcKit.finish();

//       setState(() {
//         writeStatus = "✅ Successfully written $selectedType data to NFC tag!";
//       });
//     } catch (e) {
//       print(e);
//       setState(() {
//         writeStatus = "❌ Error writing: $e";
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     double width = MediaQuery.of(context).size.width;
//     double height = MediaQuery.of(context).size.height;

//     return DefaultTabController(
//       length: 2,
//       child: Scaffold(
//         appBar: AppBar(
//           backgroundColor: const Color.fromARGB(255, 39, 78, 144),
//           title: const Text(
//             "NFC Tracker",
//             style: TextStyle(
//               fontSize: 28,
//               fontWeight: FontWeight.w700,
//               color: Colors.white,
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 _startNFCRead();
//               },
//               child: Text(
//                 "NFC Read",
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           ],
//           bottom: TabBar(
//             indicatorSize: TabBarIndicatorSize.label,
//             indicatorColor: Colors.white,
//             labelStyle: TextStyle(
//               fontWeight: FontWeight.w600,
//               color: Colors.white,
//             ),
//             unselectedLabelColor: Colors.white.withOpacity(0.6),
//             tabs: [
//               Tab(text: "Read"),
//               Tab(text: "Write"),
//             ],
//           ),
//         ),
//         body: TabBarView(
//           physics: const NeverScrollableScrollPhysics(),
//           children: [
//             // ===== READ TAB =====
//             Container(
//               width: width,
//               height: height,
//               child: nfcData.isEmpty
//                   ? Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Text(_nfcData, textAlign: TextAlign.center),
//                         const SizedBox(height: 20),
//                         ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             minimumSize: Size(width * 0.9, 40),
//                             backgroundColor: const Color.fromARGB(
//                               255,
//                               39,
//                               78,
//                               144,
//                             ),
//                           ),
//                           onPressed: _startNFCRead,
//                           child: const Text(
//                             "Start Reading",
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                       ],
//                     )
//                   : ListView.separated(
//                       separatorBuilder: (context, i) =>
//                           const Divider(height: 2),
//                       itemCount: nfcData.keys.length,
//                       shrinkWrap: true,
//                       itemBuilder: (context, i) {
//                         String key = nfcData.keys.elementAt(i);
//                         print(nfcData[key]);
//                         if (nfcData[key] is Uint8List) {
//                           Uint8List imgBytes = Uint8List.fromList(nfcData[key]);

//                           print(
//                             Uint8List.fromList(List<int>.from(nfcData[key])),
//                           );
//                           return ListTile(
//                             title: Text(
//                               key.toUpperCase(),
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             subtitle: Image.memory(
//                               imgBytes,
//                               height: 120,
//                               fit: BoxFit.cover,
//                             ),
//                           );
//                         } else {
//                           String? value = nfcData[key];
//                           if (value != null && value.contains(".jpg")) {
//                             return ListTile(
//                               title: Text(
//                                 key.toUpperCase(),
//                                 style: const TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               subtitle: Image.file(
//                                 File(value),
//                                 height: 120,
//                                 fit: BoxFit.cover,
//                               ),
//                             );
//                           } else if (value != null &&
//                               value.startsWith("image:")) {
//                             Uint8List bytes = base64Decode(
//                               value.replaceFirst("image:", ""),
//                             );

//                             return ListTile(
//                               title: Text(
//                                 key.toUpperCase(),
//                                 style: const TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               subtitle: Image.memory(
//                                 bytes,
//                                 height: 120,
//                                 fit: BoxFit.cover,
//                               ),
//                             );
//                           }

//                           return ListTile(
//                             title: Text(
//                               key == "nfcId" ? "NFC ID" : key.toUpperCase(),
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             subtitle: Text(value ?? "N/A"),
//                           );
//                         }
//                       },
//                     ),
//             ),

//             // ===== WRITE TAB =====
//             Container(
//               width: width,
//               height: height,
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     "Write to NFC",
//                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 20),

//                   DropdownButtonFormField<String>(
//                     value: selectedType,
//                     decoration: const InputDecoration(
//                       labelText: "Select Data Type",
//                       border: OutlineInputBorder(),
//                     ),
//                     items: ["Text", "Link", "Number", "Image"].map((type) {
//                       return DropdownMenuItem(value: type, child: Text(type));
//                     }).toList(),
//                     onChanged: (val) {
//                       setState(() {
//                         selectedType = val!;
//                         _controller.clear();
//                         _pickedImage = null;
//                       });
//                     },
//                   ),
//                   const SizedBox(height: 20),

//                   if (selectedType == "Image") ...[
//                     ElevatedButton(
//                       onPressed: _pickImage,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color.fromARGB(255, 39, 78, 144),
//                       ),
//                       child: const Text(
//                         "Pick Image",
//                         style: TextStyle(color: Colors.white),
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//                     if (_pickedImage != null)
//                       Image.file(_pickedImage!, height: 150, fit: BoxFit.cover),
//                   ] else ...[
//                     TextField(
//                       controller: _controller,
//                       decoration: InputDecoration(
//                         labelText: "Enter $selectedType",
//                         border: const OutlineInputBorder(),
//                       ),
//                     ),
//                   ],
//                   const SizedBox(height: 20),

//                   ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                       minimumSize: Size(width * 0.9, 45),
//                       backgroundColor: const Color.fromARGB(255, 39, 78, 144),
//                     ),
//                     onPressed: _startNFCWrite,
//                     child: const Text(
//                       "Write to NFC",
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 10),
//                   Text(
//                     writeStatus,
//                     style: const TextStyle(
//                       fontWeight: FontWeight.w500,
//                       color: Colors.black87,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
