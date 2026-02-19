import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nfc_tracker/nfc_service.dart';
import '/dob_gender_row.dart';
import '/document_dates_row.dart';
import '/nationality_row.dart';
import '/passport_image_uploader.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

typedef OnWrite = Function(bool);

class PcLayout extends StatefulWidget {
  final Map<String, dynamic> nfcData;
  final VoidCallback onRefresh;
  final NfcService? nfc;
  final OnWrite onWrite;

  const PcLayout(
      {Key? key,
      required this.nfcData,
      this.nfc,
      required this.onWrite,
      required this.onRefresh})
      : super(key: key);
  @override
  State<PcLayout> createState() => _PcLayoutState();
}

class _PcLayoutState extends State<PcLayout> {
  bool isSelected = true;
  void onChange() {
    setState(() {
      isSelected = !isSelected;
    });
  }

  final TextEditingController docCodeController = TextEditingController();
  final TextEditingController surnameController = TextEditingController();
  final TextEditingController givenNameController = TextEditingController();
  final TextEditingController docNumberController = TextEditingController();
  final TextEditingController pNumberController = TextEditingController();
  final TextEditingController nationalityController = TextEditingController();
  final TextEditingController nationalityIssueController =
      TextEditingController();
  final TextEditingController issueDateController = TextEditingController();
  final TextEditingController expiryDateController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController genderController = TextEditingController();
  final TextEditingController mrzIdController = TextEditingController();

  // New fields
  final TextEditingController placeOfBirthController = TextEditingController();
  final TextEditingController nationalIdNoController = TextEditingController();
  final TextEditingController countryCodeController = TextEditingController();
  final TextEditingController typeController = TextEditingController();
  final TextEditingController contentAuthenticityController =
      TextEditingController();
  final TextEditingController chipAuthenticityController =
      TextEditingController();
  final TextEditingController expirationStatusController =
      TextEditingController();

  File? passportImageFile;
  File? passSizeImageFile;

  void clearForm() {
    docCodeController.clear();
    surnameController.clear();
    givenNameController.clear();
    docNumberController.clear();
    pNumberController.clear();
    nationalityController.clear();
    nationalityIssueController.clear();
    issueDateController.clear();
    expiryDateController.clear();
    dobController.clear();
    genderController.clear();
    mrzIdController.clear();
    placeOfBirthController.clear();
    nationalIdNoController.clear();
    countryCodeController.clear();
    typeController.clear();
    contentAuthenticityController.clear();
    chipAuthenticityController.clear();
    expirationStatusController.clear();

    setState(() {
      passportImageFile = null;
      passSizeImageFile = null;
    });
  }

  Future<void> onSaveNFCId(String id) async {
    // final nfc = NfcService();
    // if (!widget.initialize()) {
    //   if (kDebugMode) {
    //     print('Could not initialize NFC service');
    //   }
    //   return;
    // }

    if (widget.nfc == null) {
      if (kDebugMode) {
        print('NFC Service not available (not Windows)');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('NFC writing is only supported on Windows currently.')),
      );
      return;
    }

    final readers = widget.nfc!.listReaders();
    if (kDebugMode) {
      print('Readers found: $readers');
    }
    if (readers.isEmpty) {
      if (kDebugMode) {
        print('No NFC readers found');
      }
      widget.nfc!.release();
      return;
    }

    final reader = readers.first;
    print('Connecting to reader: $reader');

    try {
      final card = widget.nfc!.connect(reader);
      print('Connected with protocol: ${card.activeProtocol}');
      final command = Uint8List.fromList([0xFF, 0xCA, 0x00, 0x00, 0x00]);
      final response = card.transmit(command);
      final sw1 = response[response.length - 2];
      final sw2 = response[response.length - 1];

      if (sw1 != 0x90 || sw2 != 0x00) {
        throw Exception('Failed to read UID');
      }

      final uidBytes = response.sublist(0, response.length - 2);
      final uid = uidBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(':')
          .toUpperCase();
      print('Tag UID: $uid');
      final ok1 = writeNdefText(card, '$id');
      print('NDEF write: $ok1');
      widget.onWrite(false);
      clearForm();
      // 3. ✅ Show result
      final snackBar = SnackBar(
        content: Text(
            ok1 ? 'Card UID saved successfully!' : 'Failed to save Card UID!'),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      card.disconnect(NfcService.SCARD_LEAVE_CARD);
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading card: $e')),
      );
    } finally {
      widget.nfc?.release();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final purple = const Color(0xFF800080);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Check screen size
        bool isWide = constraints.maxWidth > 800;

        Widget leftPanel = Expanded(
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  width: width,
                  child: const Text(
                    "Add New Record",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
                const Divider(),
                Card(
                  margin: EdgeInsets.symmetric(horizontal: 10),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: 0.5,
                      color: const Color.fromARGB(255, 72, 72, 72),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SizedBox(
                    width: width,
                    height: height * 0.06,
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              onChange();
                            },
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                vertical: 5,
                                horizontal: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color.fromARGB(255, 25, 63, 188)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "Passport",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isSelected ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              onChange();
                            },
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                vertical: 5,
                                horizontal: 5,
                              ),
                              decoration: BoxDecoration(
                                color: !isSelected
                                    ? const Color.fromARGB(255, 25, 63, 188)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "Card",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      !isSelected ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: width,
                  height: isWide ? height * 0.7 : null,
                  margin: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(width: 1, color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(
                          alignment: Alignment.topCenter,
                          child: Column(
                            children: [
                              Container(
                                width: width - 30,
                                height: height * 0.3,
                                child: Center(
                                  child: PassportImageUploader(
                                    previewHeight: 160,
                                    previewWidth: 140,
                                    title: "Select Passport Size Image",
                                    // maxBytes:
                                    //     90000, // e.g. 90KB limit (set as you want)
                                    onImageSelected: (File file) {
                                      if (file.path.isNotEmpty) {
                                        // removed / cleared
                                        setState(() {
                                          passSizeImageFile = file;
                                        });
                                      } else {
                                        print(
                                          'Selected file path: ${file.path}  size: ${file.lengthSync()}',
                                        );
                                        // Upload or save or write to NFC...
                                      }
                                    },
                                  ),
                                ),
                                // Replace with PassportImageUploader
                              ),
                              Container(
                                width: width - 30,
                                height: height * 0.3,
                                child: Center(
                                  child: PassportImageUploader(
                                    title:
                                        "Select ${isSelected ? "Passport" : "Card Front/Back"} Image",
                                    previewHeight: 160,
                                    previewWidth: 140,
                                    // maxBytes:
                                    //     90000, // e.g. 90KB limit (set as you want)
                                    onImageSelected: (File file) {
                                      if (file.path.isNotEmpty) {
                                        // removed / cleared

                                        setState(() {
                                          passportImageFile = file;
                                        });
                                      } else {
                                        print(
                                          'Selected file path: ${file.path}  size: ${file.lengthSync()}',
                                        );
                                        // Upload or save or write to NFC...
                                      }
                                    },
                                  ),
                                ),
                                // Replace with PassportImageUploader
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Container(
                          width: width,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 15),
                                _buildTextField(
                                    "Enter  ${isSelected ? 'Passport' : 'Card'} Number",
                                    docCodeController),
                                const SizedBox(height: 10),
                                _buildTextField(
                                    "Enter Surname", surnameController),
                                const SizedBox(height: 10),
                                _buildTextField(
                                    "Enter Given Name", givenNameController),
                                const SizedBox(height: 10),
                                _buildTextField(
                                    "Enter ${isSelected ? 'ID' : 'Personal ID'} Number",
                                    docNumberController),
                                const SizedBox(height: 5),
                                // _buildTextField(
                                //     "Enter Personal Number", pNumberController),
                                // Replace with your custom widgets
                                NationalityRow(
                                    onNationalityChanged: (d) {
                                      setState(() {
                                        nationalityController.text = d!;
                                      });
                                    },
                                    onIssueNationalityChanged: (d) {
                                      setState(() {
                                        nationalityIssueController.text = d!;
                                      });
                                    },
                                    isSelected: isSelected),
                                SizedBox(height: 0),
                                DocumentDatesRow(
                                  onExpiryDateChanged: (d) {
                                    setState(() {
                                      expiryDateController.text = d;
                                    });
                                  },
                                  onIssueDateChanged: (d) {
                                    setState(() {
                                      issueDateController.text = d;
                                    });
                                  },
                                ),
                                DobGenderRow(
                                  onDobChanged: (d) {
                                    setState(() {
                                      dobController.text = d.toString();
                                    });
                                  },
                                  onGenderChanged: (g) {
                                    genderController.text = g!;
                                  },
                                ),
                                const SizedBox(height: 5),

                                _buildTextField(
                                    "Place of Birth", placeOfBirthController),
                                const SizedBox(height: 10),
                                _buildTextField(
                                    "National ID No", nationalIdNoController),
                                const SizedBox(height: 10),
                                _buildTextField(
                                    "Country Code", countryCodeController),
                                const SizedBox(height: 10),
                                _buildTextField(
                                    "Type (Passport/Card)", typeController),
                                const SizedBox(height: 10),
                                _buildTextField("Content Authenticity",
                                    contentAuthenticityController),
                                const SizedBox(height: 10),
                                _buildTextField("Chip Authenticity",
                                    chipAuthenticityController),
                                const SizedBox(height: 10),
                                _buildTextField("Expiration Status",
                                    expirationStatusController),
                                const SizedBox(height: 5),

                                _buildTextField("Enter MRZ ID", mrzIdController,
                                    multiline: true),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {},
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 18,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          "Reset",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          // 1. Basic validations
                                          print(passSizeImageFile);
                                          widget.onWrite(true);
                                          if (docCodeController.text.isEmpty ||
                                              // docNumberController.text.isEmpty ||
                                              // surnameController.text.isEmpty ||
                                              givenNameController
                                                  .text.isEmpty ||
                                              passportImageFile == null ||
                                              passSizeImageFile == null) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      "Please fill all required fields and upload images")),
                                            );
                                            return;
                                          }

                                          // 2. Create Multipart request
                                          var uri = Uri.parse(
                                              "http://localhost:3000/users"); // replace with real IP if needed
                                          var request = http.MultipartRequest(
                                              "POST", uri);

                                          request.fields['docCode'] =
                                              docCodeController.text;
                                          request.fields['docNumber'] =
                                              docNumberController.text;
                                          request.fields['surname'] =
                                              surnameController.text;
                                          request.fields['givenName'] =
                                              givenNameController.text;
                                          request.fields['pNumber'] =
                                              "pNumberController.text";
                                          request.fields['nationality'] =
                                              nationalityController.text;
                                          request.fields['nationalityIssue'] =
                                              nationalityIssueController.text;
                                          request.fields['issueDate'] =
                                              issueDateController.text;
                                          request.fields['expiryDate'] =
                                              expiryDateController.text;
                                          request.fields['dob'] =
                                              dobController.text;
                                          request.fields['gender'] =
                                              genderController.text;
                                          request.fields['mrzId'] =
                                              mrzIdController.text;
                                          request.fields['placeOfBirth'] =
                                              placeOfBirthController.text;
                                          request.fields['nationalIdNo'] =
                                              nationalIdNoController.text;
                                          request.fields['countryCode'] =
                                              countryCodeController.text;
                                          request.fields['type'] =
                                              typeController.text;
                                          request.fields[
                                                  'contentAuthenticity'] =
                                              contentAuthenticityController
                                                  .text;
                                          request.fields['chipAuthenticity'] =
                                              chipAuthenticityController.text;
                                          request.fields['expirationStatus'] =
                                              expirationStatusController.text;

                                          // Images
                                          if (passportImageFile != null) {
                                            request.files.add(
                                              await http.MultipartFile.fromPath(
                                                'passportImage',
                                                passportImageFile!.path,
                                                contentType:
                                                    MediaType('image', 'jpeg'),
                                              ),
                                            );
                                          }

                                          if (passSizeImageFile != null) {
                                            request.files.add(
                                              await http.MultipartFile.fromPath(
                                                'passSizeImage',
                                                passSizeImageFile!.path,
                                                contentType:
                                                    MediaType('image', 'jpeg'),
                                              ),
                                            );
                                          }

                                          // 3. Send request
                                          var response = await request.send();

                                          if (response.statusCode == 200) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      "Data saved successfully!")),
                                            );
                                            final resBody = await response
                                                .stream
                                                .bytesToString();
                                            final data = jsonDecode(resBody);
                                            await onSaveNFCId(
                                                data['userId'].toString());
                                            // TODO: Clear form
                                          } else {
                                            final resBody = await response
                                                .stream
                                                .bytesToString();
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      "Failed to save: $resBody")),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 18,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          "Save",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      Text("MRZ ID: ${mrzIdController.text}"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        Widget rightPanel = Expanded(
          child: Container(
            color: const Color(0xFFF9FAFB),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const Text(
                        "Identity Database",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827)),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: widget.onRefresh,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text("Refresh"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purple,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => widget.nfcData.clear()),
                        icon: const Icon(Icons.history, size: 18),
                        label: const Text("Clear"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search by passport or ID number...',
                            prefixIcon:
                                const Icon(Icons.search, color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: purple, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10)
                      ],
                    ),
                    child: UserDetailsWidget(userData: widget.nfcData),
                  ),
                ),
              ],
            ),
          ),
        );

        // Responsive: Row for wide, Column for narrow
        return isWide
            ? Row(children: [leftPanel, rightPanel])
            : Column(children: [leftPanel, rightPanel]);
      },
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller,
      {bool multiline = false}) {
    return SizedBox(
      height: multiline ? 70 : 35,
      child: TextFormField(
        controller: controller,
        maxLines: 4,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color.fromARGB(255, 233, 232, 232),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 10,
          ),
          hintText: hint,
          border: OutlineInputBorder(borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

class UserDetailsWidget extends StatelessWidget {
  final Map<String, dynamic> userData;
  const UserDetailsWidget({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    if (userData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text("No record selected",
              style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
      );
    }

    final purple = const Color(0xFF800080);
    final textLabel = Colors.grey.shade600;
    final textValue = Colors.black87;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: purple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: purple,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: "DATA"),
              Tab(text: "SECURITY"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDataTab(purple, textLabel, textValue),
                _buildSecurityTab(purple, textLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTab(Color purple, Color textLabel, Color textValue) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPremiumHeader("Identity Verification", purple),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPortrait(userData['passSizeImage']),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildSectionTitle("Personal Data", purple),
                    _buildDetailRow(
                        "Full Name",
                        "${userData['givenName'] ?? ''} ${userData['surname'] ?? ''}"
                            .toUpperCase(),
                        textLabel,
                        textValue),
                    _buildDetailRow("Gender / Sex", userData['gender'] ?? '---',
                        textLabel, textValue),
                    _buildDetailRow("Date of Birth", userData['dob'] ?? '---',
                        textLabel, textValue),
                    _buildDetailRow("Nationality",
                        userData['nationality'] ?? '---', textLabel, textValue),
                    _buildDetailRow(
                        "Place of Birth",
                        userData['placeOfBirth'] ?? '---',
                        textLabel,
                        textValue),
                    _buildDetailRow(
                        "National ID No",
                        userData['nationalIdNo'] ?? '---',
                        textLabel,
                        textValue),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          _buildSectionTitle("Passport Information", purple),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 5,
            children: [
              _buildDetailRow("Document Type", userData['docCode'] ?? 'P',
                  textLabel, textValue),
              _buildDetailRow("Country Code", userData['countryCode'] ?? '---',
                  textLabel, textValue),
              _buildDetailRow("Passport Number", userData['docNumber'] ?? '---',
                  textLabel, textValue),
              _buildDetailRow("Issue Date", userData['issueDate'] ?? '---',
                  textLabel, textValue),
              _buildDetailRow("Expiry Date", userData['expiryDate'] ?? '---',
                  textLabel, textValue),
              _buildDetailRow(
                  "Doc Type", userData['type'] ?? '---', textLabel, textValue),
            ],
          ),
          const SizedBox(height: 30),
          _buildSectionTitle("Security Verification", purple),
          _buildSecurityRow("Content Authenticity", "Verified Authentic", true),
          _buildSecurityRow("Chip Authenticity", "Hardware Verified", true),
          _buildSecurityRow("Expiration Status",
              userData['expirationStatus'] ?? "Valid Document", true),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSecurityTab(Color purple, Color textLabel) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMrzBlock("Machine Readable Zone (MRZ)",
              userData['mrzId'] ?? '---', textLabel),
          const SizedBox(height: 30),
          _buildSectionTitle("Document Scan", purple),
          _buildPassportImage(userData['passportImage']),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader(String title, Color purple) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: purple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: purple.withOpacity(0.1)),
      ),
      child: Text(
        title,
        style: TextStyle(
            color: purple,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color purple) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                  color: purple, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: purple,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildPortrait(String? path) {
    return Container(
      width: 140,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: path != null
            ? Image.network('http://31.97.227.51:3300/$path',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) =>
                    const Icon(Icons.person, size: 60, color: Colors.grey))
            : const Icon(Icons.person, size: 60, color: Colors.grey),
      ),
    );
  }

  Widget _buildDetailRow(
      String label, String value, Color textLabel, Color textValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 130,
              child: Text("$label:",
                  style: TextStyle(
                      color: textLabel,
                      fontSize: 13,
                      fontWeight: FontWeight.w500))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      color: textValue,
                      fontSize: 13,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildMrzBlock(String label, String value, Color textLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: textLabel, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)
            ],
          ),
          child: Text(
            value,
            style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 14,
                color: Color(0xFFE5E7EB),
                letterSpacing: 1.2,
                height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildPassportImage(String? path) {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        color: Colors.white,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: path != null
            ? Image.network('http://31.97.227.51:3300/$path',
                fit: BoxFit.contain)
            : const Icon(Icons.image, size: 60, color: Colors.grey),
      ),
    );
  }

  Widget _buildSecurityRow(String label, String status, bool isOk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isOk
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(status,
                    style: TextStyle(
                        color:
                            isOk ? Colors.green.shade700 : Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                const SizedBox(width: 4),
                Icon(isOk ? Icons.check_circle : Icons.error,
                    color: isOk ? Colors.green.shade700 : Colors.red.shade700,
                    size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
