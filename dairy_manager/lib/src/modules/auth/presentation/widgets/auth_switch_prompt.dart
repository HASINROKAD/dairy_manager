import 'package:flutter/material.dart';

class AuthSwitchPrompt extends StatelessWidget {
  const AuthSwitchPrompt({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(onPressed: onTap, child: Text(label)),
    );
  }
}
