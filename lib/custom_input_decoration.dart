import 'package:flutter/material.dart';
const Color primaryColor = Color(0xFF106C70);

final InputDecorationTheme customInputDecorationTheme = InputDecorationTheme(
  iconColor: primaryColor,
  labelStyle: TextStyle(color: Colors.black), // Default label color
  floatingLabelStyle: TextStyle(color: primaryColor), // On focus
  focusedBorder: UnderlineInputBorder(
    borderSide: BorderSide(color: primaryColor),
  ),
  enabledBorder: UnderlineInputBorder(
    borderSide: BorderSide(color: Colors.grey),
  ),
);
