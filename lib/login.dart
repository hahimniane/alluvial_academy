import 'dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Duration get loginTime => const Duration(milliseconds: 2250);

  Future<String?> _authUser(LoginData data) async {
    try {
      // Attempt to sign in the user
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
              email: data.name, password: data.password);
      return null;
    } on FirebaseAuthException catch (e) {
      // Handle Firebase-specific errors
      if (e.code == 'user-not-found') {
        return 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        return 'Wrong password provided.';
      }
      return 'Something went wrong. Please try again.';
    } catch (e) {
      // Handle any other errors
      return 'An unexpected error occurred. Please try again later.';
    }
  }

  Future<String?> _signupUser(SignupData data) async {
    try {
      // Attempt to create a new user
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: data.name!, password: data.password!);
      return null;
    } on FirebaseAuthException catch (e) {
      // Handle Firebase-specific errors
      if (e.code == 'weak-password') {
        return 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        return 'The account already exists for that email.';
      }
      return 'Something went wrong. Please try again.';
    } catch (e) {
      // Handle any other errors
      return 'An unexpected error occurred. Please try again later.';
    }
  }

  Future<String?> _recoverPassword(String name) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: name);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No user found for that email.';
      }
      return 'Something went wrong. Please try again.';
    } catch (e) {
      return 'An unexpected error occurred. Please try again later.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterLogin(
      theme: LoginTheme(
          pageColorDark: Colors.tealAccent, pageColorLight: Colors.yellow),
      title: 'Alluwal Academy',
      logo: const AssetImage('assets/LOGO.png'),
      onLogin: _authUser,
      // onSignup: _signupUser,
      loginProviders: const <LoginProvider>[
        // Add third-party login providers later if needed
      ],
      onSubmitAnimationCompleted: () {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => const DashboardPage(),
        ));
      },
      onRecoverPassword: _recoverPassword,
    );
  }
}
