import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import 'verification_pending_screen.dart';

/// Official identification types accepted for business-owner KYC.
const List<String> kIdTypes = [
  'INE / IFE',
  'Pasaporte',
  'Cédula Profesional',
  'Licencia de Conducir',
];

/// Professional multi-step KYC (Know Your Customer) form shown to users with
/// [UserRole.business] who have not yet been verified.
///
/// Collects personal / official-ID data to prevent fraud and scams.
/// After submission the user's `verificationStatus` is set to `pending` and
/// they are redirected to [VerificationPendingScreen] while awaiting review.
class BusinessOwnerVerificationScreen extends StatefulWidget {
  /// Optional message shown at the top of Step 1 (e.g. rejection reason).
  final String? headerMessage;

  const BusinessOwnerVerificationScreen({super.key, this.headerMessage});

  @override
  State<BusinessOwnerVerificationScreen> createState() =>
      _BusinessOwnerVerificationScreenState();
}

class _BusinessOwnerVerificationScreenState
    extends State<BusinessOwnerVerificationScreen> {
  int _step = 0;
  bool _submitting = false;

  // ── Step 1: Datos personales ─────────────────────────────────────────────
  final _step1Key = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _rfcCtrl = TextEditingController();
  final _curpCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _businessEmailCtrl = TextEditingController();

  // ── Step 2: Identificación oficial ──────────────────────────────────────
  final _step2Key = GlobalKey<FormState>();
  String? _selectedIdType;
  File? _idFrontFile;
  File? _idBackFile;
  Uint8List? _idFrontBytes;
  Uint8List? _idBackBytes;
  String? _idFrontUrl;
  String? _idBackUrl;

  // ── Step 3: Términos y condiciones ───────────────────────────────────────
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _declarationTrue = false;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _rfcCtrl.dispose();
    _curpCtrl.dispose();
    _phoneCtrl.dispose();
    _businessEmailCtrl.dispose();
    super.dispose();
  }

  // ── Image helpers ────────────────────────────────────────────────────────

  Future<void> _pickImage({required bool isFront}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 88,
    );
    if (picked == null) return;
    final bytes = kIsWeb ? await picked.readAsBytes() : null;
    setState(() {
      if (isFront) {
        _idFrontFile = kIsWeb ? null : File(picked.path);
        _idFrontBytes = bytes;
      } else {
        _idBackFile = kIsWeb ? null : File(picked.path);
        _idBackBytes = bytes;
      }
    });
  }

  Future<String> _uploadIdImage({
    required File? file,
    required Uint8List? bytes,
    required String uid,
    required String side,
  }) async {
    final ext = file?.path.split('.').last.toLowerCase() ?? 'jpg';
    final ref = FirebaseStorage.instance.ref(
      'verificaciones/$uid/id_${side}_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    if (bytes != null) {
      await ref.putData(bytes);
    } else if (file != null) {
      await ref.putFile(file);
    } else {
      throw Exception('No se encontró imagen para subir.');
    }
    return ref.getDownloadURL();
  }

  // ── Submission ───────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_acceptedTerms || !_acceptedPrivacy || !_declarationTrue) {
      _showError('Debes aceptar todos los puntos para continuar.');
      return;
    }
    if (_idFrontFile == null && _idFrontBytes == null) {
      _showError('Debes subir la fotografía frontal de tu identificación.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final authService = context.read<AuthService>();
      final firestoreService = context.read<FirestoreService>();
      final uid = authService.currentUser?.uid;
      if (uid == null) throw Exception('No hay sesión activa.');

      _idFrontUrl = await _uploadIdImage(
        file: _idFrontFile,
        bytes: _idFrontBytes,
        uid: uid,
        side: 'front',
      );
      if (_idBackFile != null || _idBackBytes != null) {
        _idBackUrl = await _uploadIdImage(
          file: _idBackFile,
          bytes: _idBackBytes,
          uid: uid,
          side: 'back',
        );
      }

      await firestoreService.submitOwnerVerification(
        uid: uid,
        fullLegalName: _fullNameCtrl.text,
        rfc: _rfcCtrl.text,
        curp: _curpCtrl.text.trim().isEmpty ? null : _curpCtrl.text,
        phone: _phoneCtrl.text,
        businessEmail: _businessEmailCtrl.text,
        idType: _selectedIdType!,
        idFrontUrl: _idFrontUrl!,
        idBackUrl: _idBackUrl,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => const VerificationPendingScreen()),
      );
    } catch (e) {
      _showError('Error al enviar la verificación: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ── Step navigation ──────────────────────────────────────────────────────

  void _onContinue() {
    if (_step == 0) {
      if (!(_step1Key.currentState?.validate() ?? false)) return;
    }
    if (_step == 1) {
      if (!(_step2Key.currentState?.validate() ?? false)) return;
      if (_idFrontFile == null && _idFrontBytes == null) {
        _showError('Debes subir la fotografía frontal de tu identificación.');
        return;
      }
    }
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _onBack() {
    if (_step > 0) setState(() => _step--);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.scaffoldCharcoal),
      appBar: AppBar(
        backgroundColor: const Color(AppColors.scaffoldCharcoal),
        foregroundColor: Colors.white,
        title: const Text('Verificación de identidad'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () =>
                context.read<AuthService>().signOut(),
            icon: const Icon(Icons.logout, color: Colors.white54),
            label: const Text('Salir',
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.dark(
                  primary: const Color(AppColors.primaryOrange),
                  secondary: const Color(AppColors.primaryOrange),
                  surface: const Color(0xFF2C2C2C),
                ),
              ),
              child: Stepper(
                type: StepperType.vertical,
                currentStep: _step,
                onStepContinue: _onContinue,
                onStepCancel: _onBack,
                controlsBuilder: _buildControls,
                steps: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined,
                  color: Color(AppColors.primaryOrange), size: 22),
              const SizedBox(width: 10),
              Text(
                'Verificación requerida',
                style: TextStyle(
                  color: Colors.orange.shade200,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Para proteger a nuestros usuarios y evitar fraudes, '
            'necesitamos verificar tu identidad antes de publicar un negocio. '
            'Tu información es tratada con estricta confidencialidad.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          if (widget.headerMessage != null &&
              widget.headerMessage!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.headerMessage!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, ControlsDetails details) {
    final isLast = _step == 2;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(AppColors.primaryOrange),
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 44),
            ),
            onPressed: _submitting ? null : details.onStepContinue,
            child: _submitting && isLast
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(isLast ? 'Enviar verificación' : 'Siguiente'),
          ),
          if (_step > 0) ...[
            const SizedBox(width: 12),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              onPressed: _submitting ? null : details.onStepCancel,
              child: const Text('Atrás'),
            ),
          ],
        ],
      ),
    );
  }

  // ── Step 1: Datos personales ─────────────────────────────────────────────

  Step _buildStep1() {
    return Step(
      title: const Text('Datos del propietario',
          style: TextStyle(color: Colors.white)),
      subtitle: const Text('Información personal y fiscal',
          style: TextStyle(color: Colors.white54, fontSize: 12)),
      isActive: _step >= 0,
      state: _step > 0 ? StepState.complete : StepState.indexed,
      content: Form(
        key: _step1Key,
        child: Column(
          children: [
            _field(
              controller: _fullNameCtrl,
              label: 'Nombre completo legal',
              icon: Icons.person_outline,
              hint: 'Tal como aparece en tu identificación',
              validator: (v) {
                if (v == null || v.trim().length < 5) {
                  return 'Ingresa tu nombre completo (mín. 5 caracteres)';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _field(
              controller: _rfcCtrl,
              label: 'RFC',
              icon: Icons.badge_outlined,
              hint: 'Ej. HEGH900101AB1',
              textCapitalization: TextCapitalization.characters,
              validator: (v) {
                final val = v?.trim().toUpperCase() ?? '';
                // RFC format: 12 chars for moral, 13 for physical
                if (val.length < 12 || val.length > 13) {
                  return 'El RFC debe tener entre 12 y 13 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _field(
              controller: _curpCtrl,
              label: 'CURP (opcional)',
              icon: Icons.fingerprint,
              hint: 'Ej. HEGH900101HMCRMN05',
              textCapitalization: TextCapitalization.characters,
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.isNotEmpty && val.length != 18) {
                  return 'La CURP debe tener 18 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _field(
              controller: _phoneCtrl,
              label: 'Teléfono de contacto',
              icon: Icons.phone_outlined,
              hint: '10 dígitos',
              keyboardType: TextInputType.phone,
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.length < 10) {
                  return 'Ingresa un número de teléfono válido (10 dígitos)';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _field(
              controller: _businessEmailCtrl,
              label: 'Correo electrónico de negocio',
              icon: Icons.email_outlined,
              hint: 'Correo empresarial o de contacto',
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Identificación oficial ──────────────────────────────────────

  Step _buildStep2() {
    return Step(
      title: const Text('Identificación oficial',
          style: TextStyle(color: Colors.white)),
      subtitle: const Text('Fotografía de tu documento de identidad',
          style: TextStyle(color: Colors.white54, fontSize: 12)),
      isActive: _step >= 1,
      state: _step > 1 ? StepState.complete : StepState.indexed,
      content: Form(
        key: _step2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedIdType,
              dropdownColor: const Color(0xFF2C2C2C),
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco(
                  label: 'Tipo de identificación',
                  icon: Icons.credit_card_outlined),
              items: kIdTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedIdType = v),
              validator: (v) => v == null ? 'Selecciona un tipo de ID' : null,
            ),
            const SizedBox(height: 16),
            _idUploadTile(
              label: 'Foto frontal de la identificación *',
              file: _idFrontFile,
              bytes: _idFrontBytes,
              onTap: () => _pickImage(isFront: true),
            ),
            const SizedBox(height: 12),
            _idUploadTile(
              label: 'Foto reverso (opcional)',
              file: _idBackFile,
              bytes: _idBackBytes,
              onTap: () => _pickImage(isFront: false),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Asegúrate de que la imagen sea legible y bien iluminada.\n'
              '• No se aceptan fotos borrosas ni recortadas.\n'
              '• La información debe ser completamente visible.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _idUploadTile({
    required String label,
    required File? file,
    required Uint8List? bytes,
    required VoidCallback onTap,
  }) {
    final hasImage = file != null || bytes != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasImage
                ? const Color(AppColors.primaryOrange)
                : Colors.white24,
          ),
        ),
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: bytes != null
                        ? Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          )
                        : Image.file(file!, fit: BoxFit.cover),
                  ),
                  Positioned(
                    bottom: 6,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Cambiar',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11)),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_outlined,
                      color: Colors.white38, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }

  // ── Step 3: Términos y condiciones ───────────────────────────────────────

  Step _buildStep3() {
    return Step(
      title: const Text('Declaración y términos',
          style: TextStyle(color: Colors.white)),
      subtitle: const Text('Revisión final antes de enviar',
          style: TextStyle(color: Colors.white54, fontSize: 12)),
      isActive: _step >= 2,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text(
              'La información que proporcionas será revisada por el equipo de Gazu '
              'con el propósito de verificar tu identidad y la legitimidad de '
              'tu negocio. Este proceso puede tardar hasta 48 horas hábiles.\n\n'
              'Proporcionar datos falsos constituye un incumplimiento de los '
              'Términos y Condiciones y puede resultar en la suspensión permanente '
              'de la cuenta, además de acciones legales según la legislación mexicana.',
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          _checkTile(
            value: _declarationTrue,
            onChanged: (v) => setState(() => _declarationTrue = v ?? false),
            label:
                'Declaro bajo protesta de decir verdad que toda la información '
                'y documentos proporcionados son auténticos y corresponden a mi identidad.',
          ),
          const SizedBox(height: 8),
          _checkTile(
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
            label:
                'He leído y acepto los Términos y Condiciones de uso de la '
                'plataforma Gazu.',
          ),
          const SizedBox(height: 8),
          _checkTile(
            value: _acceptedPrivacy,
            onChanged: (v) => setState(() => _acceptedPrivacy = v ?? false),
            label:
                'He leído y acepto el Aviso de Privacidad de Gazu y consiento '
                'el tratamiento de mis datos personales.',
          ),
        ],
      ),
    );
  }

  Widget _checkTile({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(AppColors.primaryOrange),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.words,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: _inputDeco(label: label, icon: icon, hint: hint),
      validator: validator,
    );
  }

  InputDecoration _inputDeco({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white54),
      hintStyle: const TextStyle(color: Colors.white24),
      prefixIcon: Icon(icon, color: Colors.white38),
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
