import 'package:flutter/material.dart';

class ViewRecordMobile extends StatefulWidget {
  final Map<String, dynamic> nfcData;
  final VoidCallback onRefresh;

  const ViewRecordMobile({
    super.key,
    required this.nfcData,
    required this.onRefresh,
  });

  @override
  State<ViewRecordMobile> createState() => _ViewRecordMobileState();
}

class _ViewRecordMobileState extends State<ViewRecordMobile>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _baseUrl = 'http://31.97.227.51:3300'; // Match server port

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nfcData.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("No record found")),
      );
    }

    final purple = const Color(0xFF800080);
    final textLabel = Colors.grey.shade600;
    final textValue = Colors.black87;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: purple,
        title: const Text(
          "Passport Chip Data",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: "DATA"),
            Tab(text: "SECURITY"),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 800;
          return Center(
            child: Container(
              constraints:
                  BoxConstraints(maxWidth: isWide ? 850 : double.infinity),
              margin: EdgeInsets.all(isWide ? 24 : 0),
              decoration: isWide
                  ? BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10)),
                      ],
                    )
                  : const BoxDecoration(color: Colors.white),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDataTab(purple, textLabel, textValue, isWide),
                  _buildSecurityTab(purple),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: LayoutBuilder(builder: (context, constraints) {
        bool isWide = MediaQuery.of(context).size.width > 800;
        return Container(
          color: isWide ? const Color(0xFFF3F4F6) : Colors.white,
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: SizedBox(
              width: isWide ? 300 : double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: purple,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  "Back",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDataTab(
      Color purple, Color textLabel, Color textValue, bool isWide) {
    return SingleChildScrollView(
      child: Column(
        children: [
          if (isWide) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("Personal Data", purple),
                        _buildInfoRow(
                            "Name:",
                            "${widget.nfcData['givenName'] ?? ''} ${widget.nfcData['surname'] ?? ''}"
                                .toUpperCase(),
                            textLabel,
                            textValue),
                        _buildInfoRow("Sex:", widget.nfcData['gender'] ?? '---',
                            textLabel, textValue),
                        _buildInfoRow(
                            "Date of Birth:",
                            widget.nfcData['dob'] ?? '---',
                            textLabel,
                            textValue),
                        _buildInfoRow(
                            "Nationality:",
                            widget.nfcData['nationality'] ?? '---',
                            textLabel,
                            textValue),
                        _buildInfoRow(
                            "Place of Birth:",
                            widget.nfcData['placeOfBirth'] ?? '---',
                            textLabel,
                            textValue),
                        _buildInfoRow(
                            "National ID No:",
                            widget.nfcData['nationalIdNo'] ?? '---',
                            textLabel,
                            textValue),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("Passport Information", purple),
                        _buildInfoRow("Type:", widget.nfcData['docCode'] ?? 'P',
                            textLabel, textValue),
                        _buildInfoRow(
                            "Country Code:",
                            widget.nfcData['countryCode'] ?? '---',
                            textLabel,
                            textValue),
                        _buildInfoRow(
                            "Passport No:",
                            widget.nfcData['docNumber'] ?? '---',
                            textLabel,
                            textValue),
                        _buildInfoRow(
                            "Date of Issue:",
                            widget.nfcData['issueDate'] ?? '---',
                            textLabel,
                            textValue),
                        _buildInfoRow(
                            "Date of Expiry:",
                            widget.nfcData['expiryDate'] ?? '---',
                            textLabel,
                            textValue),
                        _buildInfoRow("Type:", widget.nfcData['type'] ?? '---',
                            textLabel, textValue),
                        _buildInfoRow("Modifications:", "SEE PAGE 2", textLabel,
                            textValue),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildSectionHeader("Personal Data", purple),
            _buildInfoRow(
                "Name:",
                "${widget.nfcData['givenName'] ?? ''} ${widget.nfcData['surname'] ?? ''}"
                    .toUpperCase(),
                textLabel,
                textValue),
            _buildInfoRow("Sex:", widget.nfcData['gender'] ?? '---', textLabel,
                textValue),
            _buildInfoRow("Date of Birth:", widget.nfcData['dob'] ?? '---',
                textLabel, textValue),
            _buildInfoRow("Nationality:",
                widget.nfcData['nationality'] ?? '---', textLabel, textValue),
            _buildInfoRow("Place of Birth:",
                widget.nfcData['placeOfBirth'] ?? '---', textLabel, textValue),
            _buildInfoRow("National ID No:",
                widget.nfcData['nationalIdNo'] ?? '---', textLabel, textValue),
            _buildSectionHeader("Passport Information", purple),
            _buildInfoRow("Type:", widget.nfcData['docCode'] ?? 'P', textLabel,
                textValue),
            _buildInfoRow("Country Code:",
                widget.nfcData['countryCode'] ?? '---', textLabel, textValue),
            _buildInfoRow("Passport No:", widget.nfcData['docNumber'] ?? '---',
                textLabel, textValue),
            _buildInfoRow("Date of Issue:",
                widget.nfcData['issueDate'] ?? '---', textLabel, textValue),
            _buildInfoRow("Date of Expiry:",
                widget.nfcData['expiryDate'] ?? '---', textLabel, textValue),
            _buildInfoRow(
                "Type:", widget.nfcData['type'] ?? '---', textLabel, textValue),
            _buildInfoRow("Modifications:", "SEE PAGE 2", textLabel, textValue),
          ],
          _buildSectionHeader("Verification Result", purple),
          _buildVerificationRow(
              "Content Authenticity", "Authentic content", true),
          _buildVerificationRow("Chip Authenticity", "Authentic chip", true),
          _buildVerificationRow("Expiration Status",
              widget.nfcData['expirationStatus'] ?? "Not expired", true),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSecurityTab(Color purple) {
    final textLabel = Colors.grey.shade600;
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildSectionHeader("Machine Readable Zone", purple),
          _buildMrzSection(
              "MRZ ID", widget.nfcData['mrzId'] ?? '---', textLabel),
          const Divider(height: 40, indent: 20, endIndent: 20),
          _buildSectionHeader("Document Scan", purple),
          _buildImageSection(textLabel),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color purple) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: Text(
        title,
        style: TextStyle(
          color: purple,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      String label, String value, Color textLabel, Color textValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: LayoutBuilder(builder: (context, constraints) {
        bool isSmall = constraints.maxWidth < 300;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSmall) ...[
              Text(label,
                  style: TextStyle(
                      color: textLabel,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      color: textValue,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: constraints.maxWidth * 0.38,
                    child: Text(label,
                        style: TextStyle(
                            color: textLabel,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                          color: textValue,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
          ],
        );
      }),
    );
  }

  Widget _buildMrzSection(String label, String value, Color textLabel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: textLabel, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationRow(String label, String value, bool isOk) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              if (isOk)
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(Color textLabel) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Passport Document Details",
              style: TextStyle(
                  color: textLabel, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: widget.nfcData['passportImage'] != null
                  ? Container(
                      color: Colors.grey.shade50,
                      child: Image.network(
                        '$_baseUrl/${widget.nfcData['passportImage']}',
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => const Center(
                          child: Icon(Icons.broken_image,
                              size: 50, color: Colors.grey),
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.image, size: 50, color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }
}
