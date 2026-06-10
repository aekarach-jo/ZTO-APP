import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.prefixText,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.focusNode,
    this.readOnly = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final String? prefixText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixText: prefixText,
      ),
    );
  }
}

