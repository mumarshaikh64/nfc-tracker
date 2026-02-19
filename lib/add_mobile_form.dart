import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:nfc_manager/nfc_manager.dart';

// Dummy placeholders — replace with your actual widgets
import 'passport_image_uploader.dart';
import 'nationality_row.dart';
import 'document_dates_row.dart';
import 'dob_gender_row.dart';

class AddRecordMobile extends StatefulWidget {
  final Function(bool) onWrite;

  const AddRecordMobile({super.key, required this.onWrite});

  @override
  State<AddRecordMobile> createState() => _AddRecordMobileState();
}

class _AddRecordMobileState extends State<AddRecordMobile> {
  bool isPassport = true;
  File? passportImageFile;
  File? passSizeImageFile;

  final docCodeController = TextEditingController();
  final docNumberController = TextEditingController();
  final surnameController = TextEditingController();
  final givenNameController = TextEditingController();
  final nationalityController = TextEditingController();
  final nationalityIssueController = TextEditingController();
  final issueDateController = TextEditingController();
  final expiryDateController = TextEditingController();
  final dobController = TextEditingController();
  final genderController = TextEditingController();
  final mrzIdController = TextEditingController();
  final pNumberController = TextEditingController();

  // New fields
  final placeOfBirthController = TextEditingController();
  final nationalIdNoController = TextEditingController();
  final countryCodeController = TextEditingController();
  final typeController = TextEditingController();
  final contentAuthenticityController = TextEditingController();
  final chipAuthenticityController = TextEditingController();
  final expirationStatusController = TextEditingController();

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// --- Type Switch (Passport / Card)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isPassport = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isPassport
                              ? Color.fromARGB(255, 56, 56, 146)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Passport",
                          style: TextStyle(
                            color: isPassport ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isPassport = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: !isPassport
                              ? Color.fromARGB(255, 56, 56, 146)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Card",
                          style: TextStyle(
                            color: !isPassport ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            /// --- Image Upload Section
            Row(
              children: [
                Expanded(
                  child: PassportImageUploader(
                    previewHeight: 150,
                    previewWidth: 150,
                    title: "Select Passport Size Image",
                    onImageSelected: (File file) {
                      setState(() => passSizeImageFile = file);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PassportImageUploader(
                    previewHeight: 150,
                    previewWidth: 150,
                    title: "Select ${isPassport ? "Passport" : "Card"} Image",
                    onImageSelected: (File file) {
                      setState(() => passportImageFile = file);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            /// --- Text Fields
            _buildTextField("Enter ${isPassport ? 'Passport' : 'Card'} Number",
                docCodeController),
            _buildTextField("Enter Surname", surnameController),
            _buildTextField("Enter Given Name", givenNameController),
            _buildTextField("Enter ${isPassport ? 'ID' : 'Personal ID'} Number",
                docNumberController),
            _buildTextField("Enter Phone Number", pNumberController),
            const SizedBox(height: 10),

            NationalityRow(
              onNationalityChanged: (d) =>
                  setState(() => nationalityController.text = d ?? ''),
              onIssueNationalityChanged: (d) =>
                  setState(() => nationalityIssueController.text = d ?? ''),
              isSelected: isPassport,
            ),
            const SizedBox(height: 10),

            DocumentDatesRow(
              onExpiryDateChanged: (d) =>
                  setState(() => expiryDateController.text = d),
              onIssueDateChanged: (d) =>
                  setState(() => issueDateController.text = d),
            ),
            const SizedBox(height: 10),

            DobGenderRow(
              onDobChanged: (d) {
                setState(() {
                  dobController.text = d.toString();
                });
              },
              onGenderChanged: (g) => genderController.text = g ?? '',
            ),
            const SizedBox(height: 10),

            /// --- New Passport Fields
            _buildTextField("Place of Birth", placeOfBirthController),
            _buildTextField("National ID No", nationalIdNoController),
            _buildTextField("Country Code", countryCodeController),
            _buildTextField("Type (Passport/Card)", typeController),
            _buildTextField(
                "Content Authenticity", contentAuthenticityController),
            _buildTextField("Chip Authenticity", chipAuthenticityController),
            _buildTextField("Expiration Status", expirationStatusController),
            const SizedBox(height: 10),

            _buildTextField("Enter MRZ ID", mrzIdController, multiline: true),
            const SizedBox(height: 20),

            /// --- Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _resetForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
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
                    onPressed: _saveData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 56, 56, 146),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Save",
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            /// --- MRZ Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                "MRZ ID: ${mrzIdController.text.isEmpty ? 'Not generated' : mrzIdController.text}",
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool multiline = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        maxLines: multiline ? 3 : 1,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  void _resetForm() {
    setState(() {
      docCodeController.clear();
      docNumberController.clear();
      surnameController.clear();
      givenNameController.clear();
      nationalityController.clear();
      nationalityIssueController.clear();
      issueDateController.clear();
      expiryDateController.clear();
      dobController.clear();
      genderController.clear();
      mrzIdController.clear();
      pNumberController.clear();
      placeOfBirthController.clear();
      nationalIdNoController.clear();
      countryCodeController.clear();
      typeController.clear();
      contentAuthenticityController.clear();
      chipAuthenticityController.clear();
      expirationStatusController.clear();
      passportImageFile = null;
      passSizeImageFile = null;
    });
  }

  Future<void> _saveData() async {
    if (docCodeController.text.isEmpty ||
        givenNameController.text.isEmpty ||
        passportImageFile == null ||
        passSizeImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please fill all required fields and upload images")));
      return;
    }

    setState(() {
      isLoading = true;
    });

    widget.onWrite(true);
    try {
      var uri = Uri.parse("http://31.97.227.51:3300/users");
      var request = http.MultipartRequest("POST", uri);

      request.fields['docCode'] = docCodeController.text;
      request.fields['docNumber'] = docNumberController.text;
      request.fields['surname'] = surnameController.text;
      request.fields['givenName'] = givenNameController.text;
      request.fields['pNumber'] = pNumberController.text;
      request.fields['nationality'] = nationalityController.text;
      request.fields['nationalityIssue'] = nationalityIssueController.text;
      request.fields['issueDate'] = issueDateController.text;
      request.fields['expiryDate'] = expiryDateController.text;
      request.fields['dob'] = dobController.text;
      request.fields['gender'] = genderController.text;
      request.fields['mrzId'] = mrzIdController.text;
      request.fields['placeOfBirth'] = placeOfBirthController.text;
      request.fields['nationalIdNo'] = nationalIdNoController.text;
      request.fields['countryCode'] = countryCodeController.text;
      request.fields['type'] = typeController.text;
      request.fields['contentAuthenticity'] =
          contentAuthenticityController.text;
      request.fields['chipAuthenticity'] = chipAuthenticityController.text;
      request.fields['expirationStatus'] = expirationStatusController.text;

      request.files.add(await http.MultipartFile.fromPath(
        'passportImage',
        passportImageFile!.path,
        contentType: MediaType('image', 'jpeg'),
      ));

      request.files.add(await http.MultipartFile.fromPath(
        'passSizeImage',
        passSizeImageFile!.path,
        contentType: MediaType('image', 'jpeg'),
      ));

      var response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Saved successfully!")));
        String url =
            "http://31.97.227.51:3300/users/view/${jsonDecode(resBody)['userId']}";

        if (!(Platform.isAndroid || Platform.isIOS)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("NFC not supported on this platform")));
          widget.onWrite(false); // Reset state
          setState(() => isLoading = false);
          return;
        }

        bool isAvailable = await NfcManager.instance.isAvailable();
        if (!isAvailable) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("NFC not available on this device.")));
          widget.onWrite(false); // Reset state
          setState(() => isLoading = false);
          return;
        }

        NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
          final ndef = Ndef.from(tag);
          if (ndef == null || !ndef.isWritable) {
            debugPrint("Tag not writable");
            NfcManager.instance.stopSession(errorMessage: 'Not writable');
            setState(() => isLoading = false);
            return;
          }
          final record = NdefRecord.createUri(Uri.parse(url));
          final message = NdefMessage([record]);
          try {
            await ndef.write(message);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("✅ URL written successfully!.")));
            }
            NfcManager.instance.stopSession();
            widget.onWrite(false); // Resume reading
            setState(() => isLoading = false);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text("❌ Write failed: $e")));
            }
            NfcManager.instance.stopSession(errorMessage: e.toString());
            widget.onWrite(false); // Resume reading
            setState(() => isLoading = false);
          }
        });
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Failed to save: $resBody")));
        widget.onWrite(false); // Resume reading if save failed
        setState(() => isLoading = false);
      }
    } catch (e) {
      widget.onWrite(false); // Resume reading if error
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}
