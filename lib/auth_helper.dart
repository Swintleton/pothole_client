import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'login_page.dart';

class AuthHelper {
  static Future<void> logout(BuildContext context, bool mounted) async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');

    if (authToken != null) {
      final response = await http.post(
        Uri.parse('http://192.168.0.115:5000/logout'),
        headers: {
          'Authorization': authToken,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Clear the auth token and navigate to the login page, only if still mounted
        await prefs.remove('auth_token');
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
          );
        }
      } else {
        // Handle logout error
        print('Logout failed');
      }
    }
  }
}