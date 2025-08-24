import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fireout/constant/colors.dart';

class CustomTextField extends StatelessWidget {
  const CustomTextField(
      {Key? key,
      required this.label,
      this.inputType = TextInputType.text,
      this.isVisible = true,
      this.obscureText = false,
      required this.controller,
      this.onFocusChange,
      this.onChange,
      this.inputFormatters})
      : super(key: key);
  final String label;
  final bool isVisible;
  final bool obscureText;
  final TextInputType inputType;
  final TextEditingController controller;
  final Function(bool)? onFocusChange;
  final Function(String)? onChange;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Visibility(
        visible: isVisible,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.white),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: Focus(
                onFocusChange: onFocusChange,
                child: TextFormField(
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Cannot be empty';
                    }
                    return null;
                  },
                  onChanged: onChange,
                  keyboardType: inputType,
                  controller: controller,
                  obscureText: obscureText,
                  inputFormatters: inputFormatters,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    errorBorder: const OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.red,
                      ),
                    ),
                    // errorStyle: TextStyle(fontSize: 25),
                    contentPadding: const EdgeInsets.only(left: 10, right: 10),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: CColors.blue,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue.shade200),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ));
  }
}
