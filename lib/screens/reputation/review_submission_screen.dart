import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/review_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';

class ReviewSubmissionScreen extends StatefulWidget {
  const ReviewSubmissionScreen({super.key});

  @override
  State<ReviewSubmissionScreen> createState() => _ReviewSubmissionScreenState();
}

class _ReviewSubmissionScreenState extends State<ReviewSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _appointmentIdController = TextEditingController();
  final _targetIdController = TextEditingController();
  final _commentController = TextEditingController();

  ReviewTargetType _targetType = ReviewTargetType.business;
  int _rating = 5;
  bool _submitting = false;

  @override
  void dispose() {
    _appointmentIdController.dispose();
    _targetIdController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_formKey.currentState?.validate() != true) return;

    final authService = context.read<AuthService>();
    final uid = authService.currentUser?.uid;
    if (uid == null) {
      _showSnack('No hay sesión activa.', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final review = GazuReview(
        appointmentId: _appointmentIdController.text.trim(),
        authorId: uid,
        targetType: _targetType,
        targetId: _targetIdController.text.trim(),
        rating: _rating,
        comment: _commentController.text.trim(),
        createdAt: DateTime.now(),
      );
      await context.read<FirestoreService>().submitReview(review);
      if (!mounted) return;
      _showSnack('¡Gracias! Tu reseña fue enviada.');
      Navigator.of(context).pop();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.scaffoldCharcoal),
      appBar: AppBar(
        backgroundColor: const Color(AppColors.scaffoldCharcoal),
        foregroundColor: Colors.white,
        title: const Text('Calificar servicio'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                key: const Key('reviewAppointmentIdField'),
                controller: _appointmentIdController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('ID de cita finalizada'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'El ID de cita es obligatorio' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ReviewTargetType>(
                key: const Key('reviewTargetTypeDropdown'),
                value: _targetType,
                dropdownColor: const Color(0xFF2C2C2C),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Perfil a calificar'),
                items: const [
                  DropdownMenuItem(
                    value: ReviewTargetType.business,
                    child: Text('Negocio'),
                  ),
                  DropdownMenuItem(
                    value: ReviewTargetType.staff,
                    child: Text('Staff'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _targetType = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('reviewTargetIdField'),
                controller: _targetIdController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  _targetType == ReviewTargetType.business
                      ? 'ID del negocio'
                      : 'ID del staff',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'El ID del perfil es obligatorio' : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Calificación:',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Slider(
                      key: const Key('reviewRatingSlider'),
                      value: _rating.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '$_rating',
                      onChanged: (v) => setState(() => _rating = v.round()),
                    ),
                  ),
                  Text('$_rating ⭐',
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
              TextFormField(
                key: const Key('reviewCommentField'),
                controller: _commentController,
                style: const TextStyle(color: Colors.white),
                minLines: 3,
                maxLines: 5,
                decoration: _inputDecoration('Reseña'),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'La reseña es obligatoria';
                  if (value.length < 10) return 'Mínimo 10 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('submitReviewButton'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(AppColors.primaryOrange),
                  foregroundColor: Colors.white,
                ),
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_submitting ? 'Enviando...' : 'Enviar reseña'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(AppColors.primaryOrange)),
      ),
      errorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red),
      ),
    );
  }
}

String responderTypeFromRole(UserRole role) {
  switch (role) {
    case UserRole.business:
      return 'business';
    case UserRole.staff:
      return 'staff';
    case UserRole.user:
      return 'user';
  }
}
