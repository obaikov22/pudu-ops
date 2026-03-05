import 'package:flutter/material.dart';

class DisabledScreen extends StatelessWidget {
  final String message;

  const DisabledScreen({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF0A04B).withValues(alpha: 0.15),
                    border: Border.all(
                      color: const Color(0xFFF0A04B).withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: Color(0xFFF0A04B),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'PUDU-OPS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Temporarily Unavailable',
                  style: TextStyle(
                    color: Color(0xFFF0A04B),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13151C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF1E2130),
                    ),
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFF8B92A5),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
