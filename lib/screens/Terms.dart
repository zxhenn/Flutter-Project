import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Terms and Conditions'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to Solitum',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'By using this app, you agree to the following terms:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _buildTermItem(
              number: '1',
              text: 'Use the app responsibly and with respect for others.',
            ),
            const SizedBox(height: 16),
            _buildTermItem(
              number: '2',
              text: 'You are responsible for the accuracy of the data you input.',
            ),
            const SizedBox(height: 16),
            _buildTermItem(
              number: '3',
              text: 'We do not collect sensitive information unless explicitly stated.',
            ),
            const SizedBox(height: 16),
            _buildTermItem(
              number: '4',
              text: 'Your data is stored securely using Firebase services.',
            ),
            const SizedBox(height: 16),
            _buildTermItem(
              number: '5',
              text: 'This app is designed for self-improvement and positive habit-building.',
            ),
            const SizedBox(height: 16),
            _buildTermItem(
              number: '6',
              text: 'Abuse, hacking, or unauthorized use of the app is prohibited.',
            ),
            const SizedBox(height: 16),
            _buildTermItem(
              number: '7',
              text: 'We may update these terms from time to time.',
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                'By continuing to use this app, you acknowledge and accept these terms.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue[900],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Last updated: ${DateTime.now().year}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTermItem({required String number, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number.',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
