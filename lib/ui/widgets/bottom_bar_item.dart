import 'package:flutter/material.dart';
import 'package:fireout/constant/colors.dart';

class BottomBarItem extends StatelessWidget {
  const BottomBarItem(
      {Key? key,
      this.isSelected = false,
      this.assetImage = '',
      this.label = '',
      required this.onTap})
      : super(key: key);
  final bool isSelected;
  final String assetImage;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              top: 0,
              child: AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  width: 70,
                  padding: const EdgeInsets.only(top: 4),
                  decoration: isSelected
                      ? BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: CColors.gradient,
                          ),
                          borderRadius: BorderRadius.circular(25),
                        )
                      : null,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              top: 4,
              child: Column(
                children: [
                  ImageIcon(AssetImage(assetImage), color: Colors.white),
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
