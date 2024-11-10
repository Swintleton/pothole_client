import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_helper.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? username;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  // Load the username from SharedPreferences
  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? 'User';  // Fetch the username or show 'User' if not available
    });
  }

  //Home page user inferface
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Pothole Detector'),  // Pothole Detector at the top
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              AuthHelper.logout(context, mounted); // Trigger logout when pressed
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Welcome, $username',  // Welcome message in the center
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
