import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fireout/constant/colors.dart';

extension on String {
  String initials() {
    String result = "";
    List<String> words = split(" ");
    for (var element in words) {
      if (element.isNotEmpty && result.length < 2) {
        result += element[0];
      }
    }
    return result.trim().toUpperCase();
  }
}

class AccountItem extends StatelessWidget {
  const AccountItem(
      {Key? key,
      required this.imageUrl,
      this.avatarStrokeColor = Colors.blue,
      required this.title,
      required this.subtitle,
      this.isCurrentUser = false})
      : super(key: key);
  final String imageUrl;
  final Color avatarStrokeColor;
  final String? title;
  final String subtitle;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    String _toString({String? value}) {
      return String.fromCharCodes(
        value!.runes.toList(),
      );
    }

    String _textConfiguration() {
      var newText = title == null || title == '' || title == ' '
          ? 'a'
          : _toString(value: title);
      // newText = upperCase! ? newText.toUpperCase() : newText;
      var arrayLeeters = newText.trim().split(' ');

      if (arrayLeeters.length > 1 && arrayLeeters.length == 2) {
        return '${arrayLeeters[0][0].trim()}${arrayLeeters[1][0].trim()}';
      }

      return newText[0];
    }

    Color _colorBackgroundConfig() {
      Color? backgroundColor;
      if (RegExp(r'[A-Z]|').hasMatch(
        _textConfiguration(),
      )) {
        backgroundColor =
            CColors.colorData[_textConfiguration()[0].toLowerCase().toString()];
      }
      return backgroundColor!;
    }

    return Row(
      children: [
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: avatarStrokeColor)),
              height: 60,
              width: 60,
            ),
            Positioned(
              right: 0,
              left: 0,
              top: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: !imageUrl.contains('https')
                    ? CircleAvatar(
                        backgroundColor: _colorBackgroundConfig(),
                        child: Text(
                          isCurrentUser
                              ? subtitle.initials()
                              : title!.initials(),
                          style: const TextStyle(
                              fontSize: 23, color: Colors.white),
                        ),
                      )
                    : CircleAvatar(
                        radius: 30,
                        foregroundImage: NetworkImage(imageUrl),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AutoSizeText(
                title!,
                style: GoogleFonts.poppins(
                    fontSize: isCurrentUser ? 13 : 18, color: Colors.white),
              ),
              AutoSizeText(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: isCurrentUser ? 18 : 13,
                  color: isCurrentUser ? Colors.white : Colors.white70,
                ),
                textAlign: TextAlign.left,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
