import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../theme.dart';

class SmsService {
  static Future<Map<String, dynamic>> alertFamily({
    required String transcript,
    required String analysis,
    required int probability,
    required String familyPhone,
  }) async {
    final baseUrl = kIsWeb ? 'http://localhost:8000' : kBackendUrl;
    final response = await http
        .post(
          Uri.parse('$baseUrl/alert-family'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'transcript':   transcript,
            'analysis':     analysis,
            'probability':  probability,
            'family_phone': familyPhone,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return {'success': true, 'body': jsonDecode(response.body)};
    } else {
      return {'success': false, 'error': 'Server error: ${response.statusCode}'};
    }
  }
}
