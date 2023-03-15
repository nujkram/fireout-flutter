import 'package:flutter/material.dart';

class GradientProgressBar extends StatelessWidget {
  final int percent;
  final LinearGradient gradient;
  final Color backgroundColor;

  const GradientProgressBar(
      {required this.percent,
      required this.gradient,
      this.backgroundColor = Colors.transparent,
      Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(5)),
        color: backgroundColor,
      ),
      child: Row(
        children: [
          Flexible(
            flex: percent,
            fit: FlexFit.tight,
            child: Container(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: const BorderRadius.all(Radius.circular(5)),
              ),
              child: const SizedBox(height: 13),
            ),
          ),
          Flexible(
            fit: FlexFit.tight,
            flex: 100 - percent,
            child: Container(
              decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: const BorderRadius.all(Radius.circular(5))),
              child: const SizedBox(height: 13),
            ),
          ),
        ],
      ),
    );
  }
}
