import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'login_page.dart';

class AuthHelper {
  static Future<void> logout(BuildContext context, bool mounted) async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');

    if (authToken != null) {
      await http.post(
        Uri.parse('http://192.168.0.115:5000/logout'),
        headers: {
          'Authorization': authToken,
          'Content-Type': 'application/json',
        },
      );

      // Clear the auth token and navigate to the login page, only if still mounted
      await prefs.remove('auth_token');
      if (mounted) {
        // Clear all stored user data
        await prefs.clear(); 

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  // Retrieve stored user role
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');  // Ensure 'user_role' is saved with this key on login
  }

  // Retrieve stored user ID
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');  // Ensure 'user_id' is saved with this key on login
  }

  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
}