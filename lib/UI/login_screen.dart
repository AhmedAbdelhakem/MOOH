import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';  // استدعاء مكتبة جوجل
import '../Component/button.dart';
import '../Component/input_field.dart';
import '../Models/validator.dart';
import 'home_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool isChecked = false;
  bool isPasswordVisible = true;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isChecked = prefs.getBool('remember') ?? false;
      if (isChecked) {
        emailController.text = prefs.getString('email') ?? '';
        passwordController.text = prefs.getString('password') ?? '';
      }
    });
  }

  Future<void> _saveCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (isChecked) {
      await prefs.setString('email', emailController.text);
      await prefs.setString('password', passwordController.text);
      await prefs.setBool('remember', true);
    } else {
      await prefs.remove('email');
      await prefs.remove('password');
      await prefs.setBool('remember', false);
    }
  }

  Future<void> _onLoginPressed() async {
    try {
      final email = emailController.text.trim();
      final password = passwordController.text;

      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_user_id', userCredential.user!.uid);

      await _saveCredentials();

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LibraryScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Login failed';
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password provided.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is badly formatted.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    }
  }

  // دالة تسجيل الدخول باستخدام حساب جوجل
  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // المستخدم ألغى تسجيل الدخول
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_user_id', userCredential.user!.uid);

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LibraryScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Sign-In failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset("assets/images/Logo-MOOH1.svg"),
                const SizedBox(height: 30),
                inputField(
                  context: context,
                  label: "Email",
                  validator: (value) => emailValidator(value.toString()),
                  controller: emailController,
                  prefixIcon: Icon(
                    Icons.person_outlined,
                    color: Colors.black.withOpacity(0.5),
                    size: 20,
                  ),
                ),
                const SizedBox(height: 10),
                inputField(
                  context: context,
                  label: "Password",
                  validator: (value) => passwordValidator(value.toString()),
                  controller: passwordController,
                  obscureText: isPasswordVisible,
                  prefixIcon: Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.black.withOpacity(0.5),
                    size: 20,
                  ),
                  suffixIcon: _passwordToggleIcon(),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isChecked = !isChecked;
                    });
                  },
                  child: Row(
                    children: [
                      Checkbox(
                        value: isChecked,
                        onChanged: (value) {
                          setState(() {
                            isChecked = value!;
                          });
                        },
                        activeColor: Colors.black,
                        side: const BorderSide(color: Colors.black),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Remember Me",
                        style: TextStyle(
                          fontFamily: 'Antenna',
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                myStyledButton(
                  texts: 'Login',
                  onPressed: _onLoginPressed,
                ),
                const SizedBox(height: 20),
                const Text('OR', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                myStyledButton(
                  texts: 'Sign in with Google',
                  onPressed: _signInWithGoogle,
                  // لو عندك طريقة لتغيير شكل الزر حطها هنا عشان يظهر زي زر جوجل
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordToggleIcon() {
    return InkWell(
      onTap: () {
        setState(() {
          isPasswordVisible = !isPasswordVisible;
        });
      },
      child: Icon(
        isPasswordVisible
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        color: Colors.grey[500],
      ),
    );
  }
}
