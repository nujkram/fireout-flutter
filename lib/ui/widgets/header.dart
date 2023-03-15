import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  final String text;

  const Header({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 36),
      child: Text(
        text,
        textAlign: TextAlign.start,
        style: Theme.of(context)
            .textTheme
            .headlineMedium!
            .apply(fontFamily: 'Poppins'),
      ),
    );
  }
}
