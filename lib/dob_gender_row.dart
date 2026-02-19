import 'package:flutter/material.dart';

class DobGenderRow extends StatefulWidget {
 final Function(DateTime) onDobChanged;
  final Function(String?) onGenderChanged;

  const DobGenderRow({
    super.key,
    required this.onDobChanged,
    required this.onGenderChanged,
  });
  @override
  State<DobGenderRow> createState() => _DobGenderRowState();
}

class _DobGenderRowState extends State<DobGenderRow> {
  DateTime? _selectedDob;
  String? _selectedGender;

  final List<String> _genders = ["Male", "Female", "Other"];

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDob) {
      setState(() {
        _selectedDob = picked;
      });
         widget.onDobChanged(picked); // <-- notify parent
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    return Container(
      width: width,
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Date of Birth field
          Expanded(
            child: GestureDetector(
              onTap: () => _pickDate(context),
              child: AbsorbPointer(
                child: TextFormField(
                  controller: TextEditingController(
                    text: _selectedDob == null
                        ? ""
                        : "${_selectedDob!.day}/${_selectedDob!.month}/${_selectedDob!.year}",
                  ),
                  decoration: InputDecoration(
                    hintText: "Date of Birth",
                    filled: true,
                    fillColor: const Color.fromARGB(255, 233, 232, 232),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 10,
                    ),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Gender dropdown
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedGender,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: "Gender",
                filled: true,
                fillColor: const Color.fromARGB(255, 233, 232, 232),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 10,
                ),
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
              items: _genders.map((String gender) {
                return DropdownMenuItem<String>(
                  value: gender,
                  child: Text(gender),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedGender = value;
                });
                widget.onGenderChanged(value); // <-- notify parent
              },
            ),
          ),
        ],
      ),
    );
  }
}
