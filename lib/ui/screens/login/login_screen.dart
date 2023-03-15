import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fireout/constant/colors.dart';
import 'package:fireout/cubit/bottom_nav_cubit.dart';
import 'package:fireout/ui/screens/login/widgets/textfield.dart';
import 'package:fireout/ui/widgets/custom_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  FirebaseAuth auth = FirebaseAuth.instance;
  TextEditingController phoneCtrl = TextEditingController();
  TextEditingController codeCtrl = TextEditingController();
  String verificationIdReceived = '';

  bool isComplete = false;
  bool isPhoneNotEmpty = false;
  bool isVisible = false;

  @override
  void initState() {
    super.initState();
    phoneCtrl.addListener(() {
      setState(() {
        isPhoneNotEmpty = phoneCtrl.text.isNotEmpty;
      });
    });
  }

  Widget _buildBody() {
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: Image.asset('assets/images/login_shade.png'),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 50, right: 35),
              child: SizedBox(
                  width: 300,
                  height: 300,
                  child: Image.asset('assets/images/fireout3_logo.png')),
            ),
            Container(
              margin: const EdgeInsets.only(left: 20, right: 20, top: 100),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomTextField(
                    label: 'Phone',
                    controller: phoneCtrl,
                    inputType: TextInputType.phone,
                  ),
                  CustomTextField(
                    label: 'Code',
                    controller: codeCtrl,
                    inputType: TextInputType.text,
                    isVisible: false,
                  ),
                  const SizedBox(height: 10),
                  CustomButton(
                    onPressed: (!isComplete)
                        ? null
                        : () {
                            if (phoneCtrl.text.isEmpty) return;

                            if (isVisible) {
                              bool isVerified = verifyCode() as bool;
                              if (isVerified) {
                                print('User verified');
                              }
                            } else {
                              verifyNumber();
                            }
                          },
                    text: (isVisible) ? 'Verify' : 'Login',
                    minimumSize: const Size(88, 35),
                    textStyle: const TextStyle(fontSize: 15),
                    borderRadius: 8,
                    bgColor: (!isComplete)
                        ? CColors.buttonGrey
                        : CColors.buttonGreen,
                  )
                ],
              ),
            )
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    setState(() {
      if (isPhoneNotEmpty) {
        isComplete = true;
      } else {
        isComplete = false;
      }
    });
    return BlocConsumer<BottomNavCubit, int>(
      listener: (context, state) {
        context.read<BottomNavCubit>().updateIndex(0);
      },
      builder: (context, state) {
        context.read<BottomNavCubit>().updateIndex(0);
        return Scaffold(
            backgroundColor: Theme.of(context).primaryColor,
            body: ConstrainedBox(
              constraints: const BoxConstraints.expand(),
              child: _buildBody(),
            ));
      },
    );
  }

  void verifyNumber() {
    auth.verifyPhoneNumber(
        phoneNumber: phoneCtrl.text,
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
        verificationId: verificationIdReceived, smsCode: codeCtrl.text);
    await auth.signInWithCredential(credentail).then((value) {
      return true;
    });
  }
}
