import 'package:flutter/material.dart';

/// Password strength levels.
enum PasswordStrength { empty, weak, medium, strong }

/// Evaluates a password string and returns its strength level.
PasswordStrength evaluatePasswordStrength(String password) {
  if (password.isEmpty) return PasswordStrength.empty;

  int score = 0;
  if (password.length >= 8) score++;
  if (password.contains(RegExp(r'[A-Z]'))) score++;
  if (password.contains(RegExp(r'[a-z]'))) score++;
  if (password.contains(RegExp(r'[0-9]'))) score++;
  if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>\-_=+\[\]\\;]'))) {
    score++;
  }

  if (score <= 2) return PasswordStrength.weak;
  if (score <= 3) return PasswordStrength.medium;
  return PasswordStrength.strong;
}

/// A widget that shows a colour-coded strength bar and requirement checklist
/// for a password field. Rebuilds whenever [password] changes.
class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final strength = evaluatePasswordStrength(password);
    final (label, color) = switch (strength) {
      PasswordStrength.weak => ('Débil', Colors.red),
      PasswordStrength.medium => ('Media', Colors.orange),
      PasswordStrength.strong => ('Fuerte', Colors.green),
      PasswordStrength.empty => ('', Colors.grey),
    };

    final barCount = switch (strength) {
      PasswordStrength.weak => 1,
      PasswordStrength.medium => 2,
      PasswordStrength.strong => 3,
      PasswordStrength.empty => 0,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Strength bar
        Row(
          children: List.generate(3, (i) {
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: i < barCount ? color : Colors.grey[300],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        // Label
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Seguridad: $label',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Requirements checklist
        _Requirement(
          met: password.length >= 8,
          label: 'Mínimo 8 caracteres',
        ),
        _Requirement(
          met: password.contains(RegExp(r'[A-Z]')),
          label: 'Al menos una letra mayúscula',
        ),
        _Requirement(
          met: password.contains(RegExp(r'[a-z]')),
          label: 'Al menos una letra minúscula',
        ),
        _Requirement(
          met: password.contains(RegExp(r'[0-9]')),
          label: 'Al menos un número',
        ),
        _Requirement(
          met: password.contains(
              RegExp(r'[!@#\$%^&*(),.?":{}|<>\-_=+\[\]\\;]')),
          label: 'Al menos un carácter especial (!@#\$...)',
        ),
      ],
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({required this.met, required this.label});

  final bool met;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: met ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: met ? Colors.green[700] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
