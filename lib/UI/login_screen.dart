import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../Component/button.dart';
import '../Component/input_field.dart';
import '../Models/validator.dart';
import 'home_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

bool isChecked = false;

class _SignInScreenState extends State<SignInScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset("assets/images/Logo-MOOH1.svg"),
              SizedBox(height: 30),
              inputField(
                context: context,
                label: "Email",
                validator: (value) => emailValidator(value.toString()),
                controller: emailController,
                prefixIcon: Icon(Icons.person_outlined,color: Colors.black.withOpacity(0.5), size: 20,),
              ),
              SizedBox(height: 10),
              inputField(
                context: context,
                label: "Password",
                validator: (value) => passwordValidator(value.toString()),
                controller: passwordController,
                obscureText: isPasswordVisable,
                prefixIcon: Icon(Icons.lock_outline_rounded,color: Colors.black.withOpacity(0.5), size: 20,),
                suffixIcon: myIconWidget(),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    isChecked = !isChecked;
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: isChecked,
                      onChanged: (bool? value) {
                        setState(() {
                          isChecked = value!;
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3),
                      ),
                      side: const BorderSide(color: Colors.black),
                      activeColor: Colors.black,
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
              SizedBox(height: 10),
              myStyledButton(texts: 'Login', onPressed: () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget myIconWidget() {
    return InkWell(
        onTap: () {
          isPasswordVisable = !isPasswordVisable;
          setState(() {});
        },
        child: isPasswordVisable
            ? Icon(
          Icons.visibility_off_outlined,
          size: 22,
          color: Colors.grey[500],
        )
            : Icon(
          Icons.visibility_off_outlined,
          size: 22,
          color: Colors.grey[500],
        ));
  }

  void onLoginSuccess() {
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) {
            return const HomeScreen();
          },
        ));
  }

  void onLoginFailure(String errorMessage) {
    SnackBar snackBar = SnackBar(
      content: Text(errorMessage),
      action: SnackBarAction(
        label: 'Ok',
        onPressed: () {},
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
