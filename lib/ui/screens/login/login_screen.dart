import 'package:fireout/cubit/bottom_nav_cubit.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fireout/ui/screens/login/widgets/textfield.dart';

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
  bool isVisible = false;

  @override
  void initState() {
    super.initState();
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
}
