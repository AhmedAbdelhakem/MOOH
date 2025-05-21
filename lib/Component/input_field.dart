import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Widget inputField({
  required String label,
  required FormFieldValidator<String>? validator,
  required TextEditingController? controller,
  Widget? suffixIcon,
  Widget? prefixIcon,
  bool obscureText = false,
  TextInputAction textInputAction = TextInputAction.next,
  TextInputType keyboardType = TextInputType.name,
}) {
  return Container(
    height: 45,
    decoration: const BoxDecoration(
      color: Color(0xfff5f8fa),
    ),
    child: TextFormField(
      cursorColor: Colors.grey,
      validator: validator,
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      style: GoogleFonts.redHatDisplay(fontSize: 16, height: 1.7),
      decoration: InputDecoration(
        fillColor: Colors.grey.withOpacity(0.4), // This won't have an effect unless `filled: true` is set
        labelText: label,
        labelStyle: GoogleFonts.redHatDisplay(fontSize: 16),
        contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 12),
        border: InputBorder.none,
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
      ),
    ),
  );
}
