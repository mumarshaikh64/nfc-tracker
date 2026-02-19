import 'package:flutter/material.dart';

class NationalityRow extends StatefulWidget {
  final Function(String?) onNationalityChanged;
  bool isSelected;
  final Function(String?) onIssueNationalityChanged;
  NationalityRow(
      {super.key,
      required this.onNationalityChanged,
      required this.onIssueNationalityChanged,
      this.isSelected = true});

  @override
  State<NationalityRow> createState() => _NationalityRowState();
}

class _NationalityRowState extends State<NationalityRow> {
  String? _selectedNationality;
  String? _selectedIssueNationality;

  // Sample list of countries (can be expanded)
  final List<String> _countries = [
    "Afghanistan",
    "Australia",
    "Bangladesh",
    "Canada",
    "China",
    "France",
    "Germany",
    "India",
    "Italy",
    "Japan",
    "Pakistan",
    "Saudi Arabia",
    "South Africa",
    "Sri Lanka",
    "United Arab Emirates",
    "United Kingdom",
    "United States",
  ];

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    return Container(
      width: width,
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Nationality dropdown
          Expanded(
            // child: DropdownButtonFormField<String>(
            //   value: _selectedNationality,
            //   isExpanded: true,
            //   decoration: InputDecoration(
            //     hintText: "Nationality",
            //     filled: true,
            //     fillColor: const Color.fromARGB(255, 233, 232, 232),
            //     contentPadding: const EdgeInsets.symmetric(
            //       vertical: 0,
            //       horizontal: 10,
            //     ),
            //     border: OutlineInputBorder(borderSide: BorderSide.none),
            //   ),
            //   items: _countries.map((String country) {
            //     return DropdownMenuItem<String>(
            //       value: country,
            //       child: Text(country),
            //     );
            //   }).toList(),
            //   onChanged: (value) {
            //     setState(() {
            //       _selectedNationality = value;
            //     });
            //     widget.onNationalityChanged(value);
            //   },
            // ),
            child: TextField(
                    onChanged: (d) {
                      widget.onNationalityChanged(d);
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color.fromARGB(255, 233, 232, 232),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 10,
                      ),
                      hintText: "Nationalty",
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                  ),
          ),

          SizedBox(width: widget.isSelected ? 0 : 10),

          // Issue Nationality dropdown
          widget.isSelected
              ? SizedBox()
              : Expanded(
                  child: TextField(
                    onChanged: (d) {
                      widget.onIssueNationalityChanged(d);
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color.fromARGB(255, 233, 232, 232),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 10,
                      ),
                      hintText: "Issue Nationalty",
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
