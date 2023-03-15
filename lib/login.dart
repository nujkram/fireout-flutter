import 'package:firebase_auth/firebase_auth.dart';
import 'package:fireout/user_dashboard.dart';
import 'package:flutter/material.dart';
import 'dart:developer';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  FirebaseAuth auth = FirebaseAuth.instance;
  TextEditingController phoneController = TextEditingController();
  TextEditingController codeController = TextEditingController();
  String verificationIdReceived = '';
  bool isVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Mobile Authentication')),
        body: Container(
          margin: const EdgeInsets.all(64),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone),
              const SizedBox(
                height: 10,
              ),
              Visibility(
                visible: isVisible,
                child: TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Code'),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              ElevatedButton(
                  onPressed: () {
                    if (isVisible) {
                      bool isVerified = verifyCode() as bool;
                      if (isVerified) {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const UserDashboard()));
                      }
                    } else {
                      verifyNumber();
                    }
                  },
                  child: Text(isVisible ? 'Login' : 'Verify'))
            ],
          ),
        ));
  }

  void verifyNumber() {
    auth.verifyPhoneNumber(
        phoneNumber: phoneController.text,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await auth
              .signInWithCredential(credential)
              .then((value) => {log('You are logged in', name: 'fireout')});
        },
        verificationFailed: (FirebaseAuthException exception) {},
        codeSent: (String verificationId, int? resendToken) {
          verificationIdReceived = verificationId;
          isVisible = true;
          setState(() {});
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          verificationIdReceived = verificationId;
        });
  }

  void verifyCode({result = false}) async {
    PhoneAuthCredential credentail = PhoneAuthProvider.credential(
        verificationId: verificationIdReceived, smsCode: codeController.text);
    await auth.signInWithCredential(credentail).then((value) {
      return true;
    });
  }
}
