import 'package:flutter/material.dart';

var userNameController = TextEditingController();
var emailController = TextEditingController();
var phoneController = TextEditingController();
var passwordController = TextEditingController();

bool isPasswordVisable = true;

String? passwordValidator(String value) {
  if (value.isEmpty) {
    return "Please enter password";
  }
  if (value.length < 6) {
    return "Password must be at least 6 characters";
  }
  bool passwordValid = RegExp(
    r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$',
  ).hasMatch(value);
  if (!passwordValid) {
    return "Password not valid";
  }
  return null;
}

String? emailValidator(String value) {
  if (value.isEmpty) {
    return "Please enter email";
  }
  bool emailValid = RegExp(
    r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
  ).hasMatch(value);
  if (!emailValid) {
    return "Email not valid";
  }
  return null;
}

String? phoneValidator(String value) {
  if (value.isEmpty) {
    return "Please enter phone number";
  }
  String pattern = r'^(?:[+0]9)?[0-9]{11}$';
  RegExp regExp = RegExp(pattern);
  if (!regExp.hasMatch(value)) {
    return "Please enter a valid mobile number";
  }
  return null;
}

String? usernameValidator(String value) {
  if (value.isEmpty) {
    return "Please enter username";
  }
  return null;
}
