import 'package:flutter/material.dart';

Widget inputField({
  required BuildContext context,
  required String label,
  required FormFieldValidator<String>? validator,
  required TextEditingController? controller,
  Widget? suffixIcon,
  Widget? prefixIcon,
  bool obscureText = false,
  TextInputAction textInputAction = TextInputAction.next,
  TextInputType keyboardType = TextInputType.emailAddress,
}) {
  final screenWidth = MediaQuery.of(context).size.width;

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8), // Light pink background
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        cursorColor: Colors.black..withOpacity(0.5),
        validator: validator,
        controller: controller,
        obscureText: obscureText,
        textInputAction: textInputAction,
        keyboardType: keyboardType,
        style: TextStyle(
          fontFamily: 'Antenna',
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          prefix: Padding(padding: EdgeInsets.only(right: 30)),
          prefixIcon: prefixIcon ??
              Icon(
                Icons.person_outline,
                color: Colors.grey[100],
                size: screenWidth * 0.05, // Responsive icon size
              ),
          labelText: label,
          labelStyle: TextStyle(
            fontFamily: 'Antenna',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.black.withOpacity(0.5),
          ) ,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: InputBorder.none,
          suffixIcon: suffixIcon,
        ),
      ),
    ),
  );
}
