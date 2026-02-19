import 'package:flutter/material.dart';

class DocumentDatesRow extends StatefulWidget {
    final Function(String) onIssueDateChanged;
  final Function(String) onExpiryDateChanged;

  const DocumentDatesRow({
    super.key,
    required this.onIssueDateChanged,
    required this.onExpiryDateChanged,
  });
  @override
  State<DocumentDatesRow> createState() => _DocumentDatesRowState();
}

class _DocumentDatesRowState extends State<DocumentDatesRow> {
  final TextEditingController _issueDateCtrl = TextEditingController();
  final TextEditingController _expiryDateCtrl = TextEditingController();

  Future<void> _pickDate(TextEditingController controller,Function(String) onDateChanged) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
     final formattedDate =
        "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
    setState(() {
      controller.text = formattedDate;
    });
    onDateChanged(formattedDate);
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
          Expanded(
            child: TextField(
              controller: _issueDateCtrl,
              readOnly: true,
              decoration: InputDecoration(
                hintText: "Issue Date",
                filled: true,
                fillColor: const Color.fromARGB(255, 233, 232, 232),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 10,
                ),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                suffixIcon: Icon(Icons.calendar_today, size: 18),
              ),
              onTap: () => _pickDate(_issueDateCtrl,widget.onIssueDateChanged),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _expiryDateCtrl,
              readOnly: true,
              decoration: InputDecoration(
                hintText: "Expiry Date",
                filled: true,
                fillColor: const Color.fromARGB(255, 233, 232, 232),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 10,
                ),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                suffixIcon: Icon(Icons.calendar_today, size: 18),
              ),
              onTap: () => _pickDate(_expiryDateCtrl,widget.onExpiryDateChanged),
            ),
          ),
        ],
      ),
    );
  }
}
