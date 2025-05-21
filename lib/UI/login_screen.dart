import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../Component/input_field.dart';
import '../Models/validator.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

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
              Text("data"),
              SizedBox(height: 10,),
              inputField(
                label: 'Email',
                validator: (value) => emailValidator(value.toString()),
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: SvgPicture.asset("assets/user.svg"),
              ),
              SizedBox(height: 10),
              inputField(
                label: 'Password',
                validator: (value) => passwordValidator(value.toString()),
                controller: passwordController,
                keyboardType: TextInputType.visiblePassword,
                suffixIcon: SvgPicture.asset("assets/eye.svg"),
                prefixIcon: SvgPicture.asset("assets/lock.svg"),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
