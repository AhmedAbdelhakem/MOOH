import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'; // ضروري للـ kIsWeb
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'UI/login_screen.dart';
import 'UI/Library_screen.dart';
import 'Services/firebase_options.dart'; // لازم تكون عملته بـ flutterfire configure

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // للويب لازم تمرر FirebaseOptions
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    // للأندرويد و iOS
    await Firebase.initializeApp();
  }

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: isLoggedIn ? const LibraryScreen() : const SignInScreen(),
    );
  }
}