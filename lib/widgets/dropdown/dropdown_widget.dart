import 'package:flutter/material.dart';

class EditDropdown extends StatelessWidget {
  final String? selectedPosition;
  final Function(String?) onChanged;

  const EditDropdown(
      {Key? key, required this.selectedPosition, required this.onChanged})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 2),
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey),
        color: Colors.transparent,
      ),
      child: DropdownButton<String>(
        value: selectedPosition,
        isExpanded: true,
        hint: Text("Pilih posisi", style: TextStyle(fontSize: 12)),
        underline: SizedBox(),
        onChanged: onChanged,
        items: ["Striker", "Tekong", "Feeder"].map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value, style: TextStyle(fontSize: 12)),
          );
        }).toList(),
      ),
    );
  }
}
