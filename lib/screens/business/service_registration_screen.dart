import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/business_model.dart';
import '../../models/service_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import 'business_dashboard_screen.dart';

/// Service categories available when registering a service.
const List<String> kServiceCategories = [
  'Corte y peinado',
  'Color y tinte',
  'Tratamiento capilar',
  'Manicura y pedicura',
  'Masaje',
  'Facial',
  'Depilación',
  'Barbería',
  'Maquillaje',
  'Consulta médica',
  'Terapia física',
  'Entrenamiento personal',
  'Otro',
];

/// Duration options (in minutes) for a service.
const List<int> kDurationOptions = [15, 30, 45, 60, 90, 120, 150, 180];

/// Screen that lets a business owner register a new service for one of their
/// businesses.
///
/// The flow:
///   - Step 1: Select the business the service belongs to.
///   - Step 2: Enter service name, category, description.
///   - Step 3: Set price and duration.
///
/// On completion the service document is written to
/// `/negocios/{businessId}/servicios/{id}` via [FirestoreService.createService],
/// then redirects to [BusinessDashboardScreen].
class ServiceRegistrationScreen extends StatefulWidget {
  const ServiceRegistrationScreen({
    super.key,
    this.initialBusinessId,
    this.startAtServiceInfoStep = false,
  });

  final String? initialBusinessId;
  final bool startAtServiceInfoStep;

  @override
  State<ServiceRegistrationScreen> createState() =>
      _ServiceRegistrationScreenState();
}

class _ServiceRegistrationScreenState
    extends State<ServiceRegistrationScreen> {
  // ---------------------------------------------------------------------------
  // Step tracking
  // ---------------------------------------------------------------------------
  int _currentStep = 0;

  // ---------------------------------------------------------------------------
  // Step 1 – Business selection
  // ---------------------------------------------------------------------------
  GazuBusiness? _selectedBusiness;

  // ---------------------------------------------------------------------------
  // Step 2 – Service info
  // ---------------------------------------------------------------------------
  final _step2Key = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  String? _selectedCategory;

  // ---------------------------------------------------------------------------
  // Step 3 – Price and duration
  // ---------------------------------------------------------------------------
  final _step3Key = GlobalKey<FormState>();
  final _precioController = TextEditingController();
  int _duracion = 60;

  // ---------------------------------------------------------------------------
  // Submission state
  // ---------------------------------------------------------------------------
  bool _submitting = false;
  bool _didApplyInitialBusinessSelection = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Step navigation
  // ---------------------------------------------------------------------------

  bool _stepIsValid(int step) {
    switch (step) {
      case 0:
        return _selectedBusiness != null;
      case 1:
        return _step2Key.currentState?.validate() == true &&
            _selectedCategory != null;
      case 2:
        return _step3Key.currentState?.validate() == true;
      default:
        return true;
    }
  }

  void _onStepContinue() {
    if (_currentStep == 1) _step2Key.currentState?.validate();
    if (_currentStep == 2) _step3Key.currentState?.validate();

    if (!_stepIsValid(_currentStep)) return;

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
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final authService = context.read<AuthService>();
      final firestoreService = context.read<FirestoreService>();
      final uid = authService.currentUser?.uid;

      if (uid == null || _selectedBusiness == null) {
        _showError('No hay sesión activa o negocio seleccionado.');
        return;
      }

      final precio = double.tryParse(_precioController.text.trim()) ?? 0.0;

      final service = GazuService(
        businessId: _selectedBusiness!.id!,
        ownerId: uid,
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        precio: precio,
        duracion: _duracion,
        categoria: _selectedCategory ?? '',
        isActive: true,
        createdAt: DateTime.now(),
      );

      await firestoreService.createService(service);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servicio registrado correctamente ✓'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const BusinessDashboardScreen()),
      );
    } catch (e) {
      _showError('Error al registrar el servicio: $e');
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final uid = authService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(AppColors.scaffoldCharcoal),
      appBar: AppBar(
        backgroundColor: const Color(AppColors.scaffoldCharcoal),
        foregroundColor: Colors.white,
        title: const Text('Alta de Servicios'),
      ),
      body: StreamBuilder<List<GazuBusiness>>(
        stream: firestoreService.businessesStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final businesses = snapshot.data ?? [];

          if (businesses.isEmpty) {
            return const _NoBusinessPlaceholder();
          }

          if (!_didApplyInitialBusinessSelection &&
              widget.initialBusinessId != null) {
            final preselected = businesses
                .where((b) => b.id == widget.initialBusinessId)
                .toList();
            if (preselected.isNotEmpty) {
              _selectedBusiness = preselected.first;
              if (widget.startAtServiceInfoStep && _currentStep == 0) {
                _currentStep = 1;
              }
            }
            _didApplyInitialBusinessSelection = true;
          }

          return Theme(
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
                _buildStep1(businesses),
                _buildStep2(),
                _buildStep3(),
              ],
            ),
          );
        },
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
  // Step 1 – Business selection
  // ---------------------------------------------------------------------------

  Step _buildStep1(List<GazuBusiness> businesses) {
    return Step(
      title: const Text('Seleccionar negocio',
          style: TextStyle(color: Colors.white)),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: businesses.map((b) {
          final isSelected = _selectedBusiness?.id == b.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedBusiness = b),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? const Color(AppColors.primaryOrange)
                      : Colors.white24,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isSelected
                        ? const Color(AppColors.primaryOrange)
                        : Colors.white12,
                    child: const Icon(Icons.storefront, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.nombre,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        Text(b.categoria,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle,
                        color: Color(AppColors.primaryOrange)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 – Service info
  // ---------------------------------------------------------------------------

  Step _buildStep2() {
    return Step(
      title: const Text('Información del servicio',
          style: TextStyle(color: Colors.white)),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      content: Form(
        key: _step2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('serviceNameField'),
              controller: _nombreController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                label: 'Nombre del servicio',
                icon: Icons.design_services_outlined,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'El nombre es obligatorio';
                }
                if (v.trim().length < 3) return 'Mínimo 3 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const Key('serviceCategoryDropdown'),
              value: _selectedCategory,
              dropdownColor: const Color(0xFF2C2C2C),
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                label: 'Categoría',
                icon: Icons.category_outlined,
              ),
              items: kServiceCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
              validator: (v) => v == null ? 'Selecciona una categoría' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('serviceDescriptionField'),
              controller: _descripcionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: _inputDecoration(
                label: 'Descripción (opcional)',
                icon: Icons.notes_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3 – Price and duration
  // ---------------------------------------------------------------------------

  Step _buildStep3() {
    return Step(
      title: const Text('Precio y duración',
          style: TextStyle(color: Colors.white)),
      isActive: _currentStep >= 2,
      content: Form(
        key: _step3Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('servicePriceField'),
              controller: _precioController,
              style: const TextStyle(color: Colors.white),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: _inputDecoration(
                label: 'Precio (MXN)',
                icon: Icons.attach_money_outlined,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'El precio es obligatorio';
                }
                final price = double.tryParse(v.trim());
                if (price == null || price < 0) {
                  return 'Ingresa un precio válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Duración: $_duracion min',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kDurationOptions.map((mins) {
                final selected = _duracion == mins;
                return GestureDetector(
                  onTap: () => setState(() => _duracion = mins),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(AppColors.primaryOrange)
                          : const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? const Color(AppColors.primaryOrange)
                            : Colors.white24,
                      ),
                    ),
                    child: Text(
                      '$mins min',
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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
// Placeholder shown when the owner has no registered businesses
// ---------------------------------------------------------------------------

class _NoBusinessPlaceholder extends StatelessWidget {
  const _NoBusinessPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront_outlined,
                size: 80, color: Colors.white24),
            const SizedBox(height: 24),
            const Text(
              'Primero debes registrar un negocio para poder agregar servicios.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(AppColors.primaryOrange),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Registrar negocio'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
