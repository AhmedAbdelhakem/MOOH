import 'package:flutter/material.dart';
import 'package:mooh/UI/home_screen.dart';
import 'UI/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LibraryScreen(),
    );
  }
}