import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Conditions'),
        backgroundColor: Colors.blue[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Text(
            '''
Welcome to Solitum!

By using this app, you agree to the following terms:

1. Use the app responsibly and with respect for others.
2. You are responsible for the accuracy of the data you input.
3. We do not collect sensitive information unless explicitly stated.
4. Your data is stored securely using Firebase services.
5. This app is designed for self-improvement and positive habit-building.
6. Abuse, hacking, or unauthorized use of the app is prohibited.
7. We may update these terms from time to time.

By continuing to use this app, you acknowledge and accept these terms.
            ''',
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
      ),
    );
  }
}
