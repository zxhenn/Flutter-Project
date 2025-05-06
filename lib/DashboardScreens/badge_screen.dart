import 'package:flutter/material.dart';
import '/addition/top_header.dart';

class BadgeScreen extends StatelessWidget {
  const BadgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const TopHeader(), // 👈 Add this!

              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Badge Screen',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
