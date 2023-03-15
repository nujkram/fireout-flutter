import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  const CustomButton(
      {Key? key,
      required this.onPressed,
      this.textStyle,
      this.bgColor = Colors.blue,
      this.borderRadius = 25,
      required this.text,
      this.minimumSize = const Size(88, 44),
      this.elevation = 0})
      : super(key: key);
  final VoidCallback? onPressed;
  final TextStyle? textStyle;
  final Color? bgColor;
  final double borderRadius;
  final String text;
  final Size? minimumSize;
  final double? elevation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: minimumSize?.height,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          elevation: elevation,
          minimumSize: minimumSize,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
          ),
          backgroundColor: bgColor,
        ),
        onPressed: onPressed,
        child: Text(text, style: textStyle),
      ),
    );
  }
}
