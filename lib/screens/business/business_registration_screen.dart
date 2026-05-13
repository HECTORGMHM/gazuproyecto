import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/business_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import 'business_dashboard_screen.dart';

// TODO(#2): Wire Google Maps picker in Step 2 once issue #10
// (Épica: Geolocalización y mapa) is implemented.

/// Categories available for a business (issue #2 – Gestión de negocios).
const List<String> kBusinessCategories = [
  'Belleza y estética',
  'Barbería',
  'Salud y bienestar',
  'Fitness',
  'Veterinaria',
  'Gastronomía',
  'Educación',
  'Otro',
];

/// Ordered list of weekdays for the schedule step.
const List<String> kWeekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

/// Multi-step registration screen for the "Alta de Negocio" flow.
///
/// Implements three steps using [Stepper]:
/// - Step 1: Business name and category.
/// - Step 2: Location placeholder + logo upload.
/// - Step 3: Weekly schedule configuration.
///
/// On completion it writes the business document to `/negocios/` via
/// [FirestoreService.createBusiness] and navigates to [BusinessDashboardScreen].
///
/// Related issues: #2 (Gestión de negocios), #10 (Geolocalización).
class BusinessRegistrationScreen extends StatefulWidget {
  const BusinessRegistrationScreen({super.key});

  @override
  State<BusinessRegistrationScreen> createState() =>
      _BusinessRegistrationScreenState();
}

class _BusinessRegistrationScreenState
    extends State<BusinessRegistrationScreen> {
  // ---------------------------------------------------------------------------
  // Step tracking
  // ---------------------------------------------------------------------------
  int _currentStep = 0;

  // ---------------------------------------------------------------------------
  // Step 1 – Basic info
  // ---------------------------------------------------------------------------
  final _step1Key = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  String? _selectedCategory;

  // ---------------------------------------------------------------------------
  // Step 2 – Location + logo
  // ---------------------------------------------------------------------------
  // TODO(#10): Replace fixed GeoPoint with a real map picker once the
  // Épica: Geolocalización issue is implemented.
  GeoPoint _ubicacion = const GeoPoint(19.4326, -99.1332); // CDMX default
  File? _logoFile;
  String? _logoUrl;

  // ---------------------------------------------------------------------------
  // Step 3 – Schedule
  // ---------------------------------------------------------------------------
  // Initial schedule: all days open 09:00–18:00.
  final Map<String, Map<String, String>> _horarios = {
    for (final day in kWeekdays) day: {'open': '09:00', 'close': '18:00'},
  };

  // ---------------------------------------------------------------------------
  // Submission state
  // ---------------------------------------------------------------------------
  bool _submitting = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _logoFile = File(picked.path));
  }

  Future<String?> _uploadLogo(String ownerId) async {
    if (_logoFile == null) return null;
    final ext = _logoFile!.path.split('.').last.toLowerCase();
    final ref = FirebaseStorage.instance
        .ref('negocios/$ownerId/${DateTime.now().millisecondsSinceEpoch}.$ext');
    await ref.putFile(_logoFile!);
    return ref.getDownloadURL();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final authService = context.read<AuthService>();
      final firestoreService = context.read<FirestoreService>();
      final uid = authService.currentUser?.uid;

      if (uid == null) {
        _showError('No hay sesión activa.');
        return;
      }

      // Upload logo if selected.
      _logoUrl = await _uploadLogo(uid);

      final business = GazuBusiness(
        ownerId: uid,
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        categoria: _selectedCategory ?? '',
        ubicacion: _ubicacion,
        horarios: Map.from(_horarios),
        status: BusinessStatus.pending,
        logoUrl: _logoUrl,
        createdAt: DateTime.now(),
      );

      await firestoreService.createBusiness(business);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const BusinessDashboardScreen()),
      );
    } catch (e) {
      _showError('Error al registrar el negocio: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  bool _stepIsValid(int step) {
    switch (step) {
      case 0:
        return _step1Key.currentState?.validate() == true &&
            _selectedCategory != null;
      default:
        return true;
    }
  }

  void _onStepContinue() {
    if (_currentStep == 0 && !_stepIsValid(0)) {
      _step1Key.currentState?.validate();
      return;
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  // ---------------------------------------------------------------------------
  // Schedule helpers
  // ---------------------------------------------------------------------------

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay _parseTime(String s) {
    final parts = s.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: int.tryParse(parts.last) ?? 0,
    );
  }

  Future<void> _pickTime(String day, String slot) async {
    final initial = _parseTime(_horarios[day]![slot]!);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: slot == 'open' ? 'Hora de apertura' : 'Hora de cierre',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _horarios[day]![slot] = _formatTime(picked));
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.scaffoldCharcoal),
      appBar: AppBar(
        backgroundColor: const Color(AppColors.scaffoldCharcoal),
        foregroundColor: Colors.white,
        title: const Text('Registrar negocio'),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: const Color(AppColors.primaryOrange),
            secondary: const Color(AppColors.primaryOrange),
            surface: const Color(0xFF2C2C2C),
          ),
        ),
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepContinue: _onStepContinue,
          onStepCancel: _onStepCancel,
          controlsBuilder: _buildControls,
          steps: [
            _buildStep1(),
            _buildStep2(),
            _buildStep3(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, ControlsDetails details) {
    final isLast = _currentStep == 2;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(AppColors.primaryOrange),
              foregroundColor: Colors.white,
            ),
            onPressed: _submitting ? null : details.onStepContinue,
            child: _submitting && isLast
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(isLast ? 'Finalizar' : 'Siguiente'),
          ),
          if (_currentStep > 0) ...[
            const SizedBox(width: 12),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              onPressed: details.onStepCancel,
              child: const Text('Atrás'),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 – Basic info
  // ---------------------------------------------------------------------------

  Step _buildStep1() {
    return Step(
      title: const Text('Información básica',
          style: TextStyle(color: Colors.white)),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      content: Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('businessNameField'),
              controller: _nombreController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                label: 'Nombre del negocio',
                icon: Icons.storefront_outlined,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'El nombre es obligatorio';
                }
                if (v.trim().length < 3) {
                  return 'Mínimo 3 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('businessDescriptionField'),
              controller: _descripcionController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                label: 'Descripción del negocio',
                icon: Icons.description_outlined,
              ),
              validator: (v) {
                if (v != null && v.trim().length > 280) {
                  return 'Máximo 280 caracteres (actualmente: ${v.trim().length})';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const Key('businessCategoryDropdown'),
              value: _selectedCategory,
              dropdownColor: const Color(0xFF2C2C2C),
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                label: 'Categoría',
                icon: Icons.category_outlined,
              ),
              items: kBusinessCategories
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
              validator: (v) =>
                  v == null ? 'Selecciona una categoría' : null,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 – Location + logo
  // ---------------------------------------------------------------------------

  Step _buildStep2() {
    return Step(
      title: const Text('Ubicación y logo',
          style: TextStyle(color: Colors.white)),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Location placeholder – TODO(#10): Replace with map picker.
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.map_outlined, color: Colors.white54, size: 36),
                const SizedBox(height: 8),
                const Text(
                  'Ubicación: Ciudad de México (por defecto)',
                  style: TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Lat ${_ubicacion.latitude.toStringAsFixed(4)}, '
                  'Lng ${_ubicacion.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Logo upload
          GestureDetector(
            onTap: _pickLogo,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _logoFile != null
                      ? const Color(AppColors.primaryOrange)
                      : Colors.white24,
                ),
              ),
              child: _logoFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_logoFile!, fit: BoxFit.cover),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            color: Colors.white54, size: 36),
                        SizedBox(height: 8),
                        Text(
                          'Subir logo (opcional)',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3 – Schedule
  // ---------------------------------------------------------------------------

  Step _buildStep3() {
    return Step(
      title: const Text('Horarios', style: TextStyle(color: Colors.white)),
      isActive: _currentStep >= 2,
      content: Column(
        children: kWeekdays.map((day) => _buildDayRow(day)).toList(),
      ),
    );
  }

  Widget _buildDayRow(String day) {
    final open = _horarios[day]!['open']!;
    final close = _horarios[day]!['close']!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              _capitalize(day),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          _TimeChip(
            label: open,
            onTap: () => _pickTime(day, 'open'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('–', style: TextStyle(color: Colors.white54)),
          ),
          _TimeChip(
            label: close,
            onTap: () => _pickTime(day, 'close'),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white54),
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

// ---------------------------------------------------------------------------
// Small helper widget
// ---------------------------------------------------------------------------

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: const TextStyle(
              color: Color(AppColors.primaryOrange), fontSize: 13),
        ),
      ),
    );
  }
}
