import 'package:flutter/material.dart';

const kGreen     = Color(0xFF22C55E);
const kNavy      = Color(0xFF0F172A);
const kDanger    = Color(0xFFEF4444);
const kGold      = Color(0xFFF59E0B);
const kLightGray = Color(0xFFF8FAFC);
const kMuted     = Color(0xFF64748B);

const kBackendUrl = String.fromEnvironment('BACKEND_URL',
    defaultValue: 'http://10.126.107.203');

ThemeData buildTheme() => ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      primaryColor: kGreen,
      fontFamily: 'Roboto',
      useMaterial3: true,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: kNavy),
        titleLarge:   TextStyle(fontSize: 28, fontWeight: FontWeight.bold,  color: kNavy),
        bodyLarge:    TextStyle(fontSize: 24, color: kNavy),
        labelLarge:   TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
