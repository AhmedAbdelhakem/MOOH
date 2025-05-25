import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  void _onLoginPressed() async {

    await _saveCredentials();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('logged_user_id', emailController.text.trim());

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LibraryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
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
            ],
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