import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../services/api_service.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _success = Color(0xFF24A148);
const _ink = Color(0xFF1A1A1A);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF7F7F7);
const _border = Color(0xFFEAEAEA);

class EditProfileScreen extends StatefulWidget {
  final Function(Map<String, String>)? onProfileUpdated;

  const EditProfileScreen({super.key, this.onProfileUpdated});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late SharedPreferences _prefs;

  late AnimationController _fadeController;
  late AnimationController _avatarController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _avatarScaleAnimation;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _emailController = TextEditingController();

  File? _selectedImageFile;
  String? _savedImagePath;
  bool _isImageLoading = false;
  bool _isLoading = true;
  bool _isSaving = false;

  // Track focused field
  String? _focusedField;

  String get _initials {
    final f = _firstNameController.text.trim();
    final l = _lastNameController.text.trim();
    if (f.isEmpty && l.isEmpty) return '?';
    return '${f.isNotEmpty ? f[0].toUpperCase() : ''}${l.isNotEmpty ? l[0].toUpperCase() : ''}';
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _avatarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _avatarScaleAnimation = CurvedAnimation(
      parent: _avatarController,
      curve: Curves.elasticOut,
    );
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    setState(() => _isLoading = true);
    _prefs = await SharedPreferences.getInstance();
    int? userId = _prefs.getInt('user_id');
    String? firstName, lastName, middleName, email;

    if (userId != null) {
      try {
        final response = await ApiService.getCurrentUser(userId);
        if (response['status'] == 'success' && response['data'] != null) {
          final userData = response['data'];
          firstName =
              userData['first_name'] ??
              userData['name'] ??
              _prefs.getString('firstName') ??
              'John';
          lastName =
              userData['last_name'] ?? _prefs.getString('lastName') ?? 'Doe';
          middleName =
              userData['middle_name'] ?? _prefs.getString('middleName') ?? '';
          email =
              userData['email'] ??
              _prefs.getString('email') ??
              'johndoe@example.com';
        }
      } catch (_) {
        firstName = _prefs.getString('firstName') ?? 'John';
        lastName = _prefs.getString('lastName') ?? 'Doe';
        middleName = _prefs.getString('middleName') ?? '';
        email = _prefs.getString('email') ?? 'johndoe@example.com';
      }
    } else {
      firstName = _prefs.getString('firstName') ?? 'John';
      lastName = _prefs.getString('lastName') ?? 'Doe';
      middleName = _prefs.getString('middleName') ?? '';
      email = _prefs.getString('email') ?? 'johndoe@example.com';
    }

    setState(() {
      _firstNameController.text = firstName!;
      _lastNameController.text = lastName!;
      _middleNameController.text = middleName!;
      _emailController.text = email!;
      _savedImagePath = _prefs.getString('profileImagePath');
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _avatarController.forward();
      Future.delayed(const Duration(milliseconds: 150), () {
        _fadeController.forward();
      });
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _avatarController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ── API ────────────────────────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final userId = _prefs.getInt('user_id');
    if (userId == null) {
      _showSnack('User ID not found.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final response = await ApiService.updateUser(userId.toString(), {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'middle_name': _middleNameController.text.trim(),
      });

      if (response['status'] == 'success') {
        await _prefs.setString('firstName', _firstNameController.text.trim());
        await _prefs.setString('lastName', _lastNameController.text.trim());
        await _prefs.setString('middleName', _middleNameController.text.trim());
        if (mounted) {
          Navigator.pop(context, {
            'firstName': _firstNameController.text.trim(),
            'lastName': _lastNameController.text.trim(),
            'middleName': _middleNameController.text.trim(),
            'profileImagePath': _savedImagePath ?? '',
          });
        }
      } else {
        _showSnack(
          response['message'] ?? 'Failed to update profile.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Image ──────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    try {
      setState(() => _isImageLoading = true);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.size > 5 * 1024 * 1024) {
          _showSnack('Image size must be less than 5MB', isError: true);
          return;
        }
        if (file.bytes != null) {
          final processed = await _compressImage(file.bytes!);
          if (processed != null) {
            final saved = await _saveImageInBackground(
              processed,
              'profile_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            if (saved != null && mounted) {
              setState(() {
                _selectedImageFile = saved;
                _savedImagePath = saved.path;
              });
              await _prefs.setString('profileImagePath', saved.path);
              _showSnack('Photo updated successfully');
            } else {
              _showSnack('Failed to save image', isError: true);
            }
          }
        }
      }
    } catch (e) {
      _showSnack('Error picking image: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isImageLoading = false);
    }
  }

  Future<void> _removeProfileImage() async {
    await _prefs.remove('profileImagePath');
    if (mounted) {
      setState(() {
        _selectedImageFile = null;
        _savedImagePath = null;
      });
      _showSnack('Profile photo removed');
    }
  }

  void _showImageOptions() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Profile Photo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _bottomSheetOption(
                  ctx,
                  icon: Icons.photo_library_rounded,
                  label: 'Choose from Gallery',
                  onTap: _pickImage,
                ),
                if (_selectedImageFile != null || _savedImagePath != null)
                  _bottomSheetOption(
                    ctx,
                    icon: Icons.delete_rounded,
                    label: 'Remove Photo',
                    onTap: _removeProfileImage,
                    isDestructive: true,
                  ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        backgroundColor: _surfaceSubtle,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: _inkSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _bottomSheetOption(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : _ink;
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    isDestructive
                        ? Colors.red.withOpacity(0.08)
                        : _surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  ImageProvider? _getProfileImage() {
    try {
      if (_selectedImageFile != null) return FileImage(_selectedImageFile!);
      if (_savedImagePath != null) {
        final f = File(_savedImagePath!);
        if (f.existsSync()) return FileImage(f);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _compressImage(Uint8List bytes) async {
    try {
      return await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: 400,
        minWidth: 400,
        quality: 85,
        format: CompressFormat.jpeg,
      );
    } catch (_) {
      return bytes;
    }
  }

  Future<File?> _saveImageInBackground(Uint8List bytes, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/$fileName');
      await f.writeAsBytes(bytes);
      return f;
    } catch (_) {
      return null;
    }
  }

  // ── UI Widgets ─────────────────────────────────────────────────────────────

  /// Diagonal split header — top half is red, avatar straddles the boundary
  Widget _buildHeroSection() {
    return ScaleTransition(
      scale: _avatarScaleAnimation,
      child: Column(
        children: [
          // Avatar with ring
          GestureDetector(
            onTap: _showImageOptions,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow ring
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _primary.withOpacity(0.18),
                        _primary.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
                // White border ring
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _surface,
                    boxShadow: [
                      BoxShadow(
                        color: _primaryDark.withOpacity(0.22),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3),
                  child: ClipOval(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEB1E23), Color(0xFF760F12)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        image:
                            _getProfileImage() != null
                                ? DecorationImage(
                                  image: _getProfileImage()!,
                                  fit: BoxFit.cover,
                                )
                                : null,
                      ),
                      child:
                          _getProfileImage() == null
                              ? Center(
                                child:
                                    _isImageLoading
                                        ? const SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                        : Text(
                                          _initials,
                                          style: const TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: -1,
                                          ),
                                        ),
                              )
                              : null,
                    ),
                  ),
                ),
                // Camera badge
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: _surface, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_firstNameController.text} ${_lastNameController.text}'.trim(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _emailController.text,
            style: const TextStyle(
              fontSize: 13,
              color: _inkTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _inkSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool isOptional = false,
  }) {
    final bool isActive = _focusedField == label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _inkSecondary,
                letterSpacing: 0.3,
              ),
            ),
            if (isOptional) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _surfaceSubtle,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'optional',
                  style: TextStyle(
                    fontSize: 10,
                    color: _inkTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            if (readOnly) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'read-only',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Focus(
          onFocusChange: (hasFocus) {
            setState(() => _focusedField = hasFocus ? label : null);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: readOnly ? const Color(0xFFF5F5F5) : _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive ? _primary : _border,
                width: isActive ? 1.5 : 1,
              ),
              boxShadow:
                  isActive
                      ? [
                        BoxShadow(
                          color: _primary.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                      : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
            ),
            child: TextFormField(
              controller: controller,
              readOnly: readOnly,
              keyboardType: keyboardType,
              style: TextStyle(
                color: readOnly ? _inkSecondary : _ink,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: Icon(
                    icon,
                    size: 18,
                    color: isActive ? _primary : _inkTertiary,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                border: InputBorder.none,
                hintText: readOnly ? '' : 'Enter $label',
                hintStyle: const TextStyle(
                  color: _inkTertiary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                errorStyle: const TextStyle(height: 0),
              ),
              validator: validator,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _ink,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: (_isImageLoading || _isSaving) ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primary.withOpacity(0.5),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child:
            _isSaving
                ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.check_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Save Changes',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _surfaceSubtle,
        body: Column(
          children: [
            // ── Compact AppBar ──────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEB1E23), Color(0xFF9B1215)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      // Back button
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Edit Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (!_isLoading)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: TextButton(
                            onPressed:
                                (_isImageLoading || _isSaving)
                                    ? null
                                    : _saveProfile,
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child:
                                _isSaving
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Text(
                                      'Save',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Body ────────────────────────────────────────────────────────
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(color: _primary),
                      )
                      : FadeTransition(
                        opacity: _fadeAnimation,
                        child: Form(
                          key: _formKey,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Profile Hero (white card, centered) ────
                                Container(
                                  width: double.infinity,
                                  color: _surface,
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    28,
                                    24,
                                    28,
                                  ),
                                  child: _buildHeroSection(),
                                ),

                                // ── Subtle divider ─────────────────────────
                                Container(height: 1, color: _border),

                                // ── Form Fields ────────────────────────────
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    24,
                                    20,
                                    32,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // ── Personal Info section ───────────
                                      _buildSectionCard(
                                        title: 'Personal Information',
                                        child: Column(
                                          children: [
                                            // First name + Last name row
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _buildInputField(
                                                    controller:
                                                        _firstNameController,
                                                    label: 'First Name',
                                                    icon: Icons.badge_outlined,
                                                    validator:
                                                        (v) =>
                                                            v?.isEmpty ?? true
                                                                ? 'Required'
                                                                : null,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: _buildInputField(
                                                    controller:
                                                        _lastNameController,
                                                    label: 'Last Name',
                                                    icon: Icons.badge_outlined,
                                                    validator:
                                                        (v) =>
                                                            v?.isEmpty ?? true
                                                                ? 'Required'
                                                                : null,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 14),
                                            _buildInputField(
                                              controller: _middleNameController,
                                              label: 'Middle Name',
                                              icon: Icons.badge_outlined,
                                              isOptional: true,
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 20),

                                      // ── Account Info section ────────────
                                      _buildSectionCard(
                                        title: 'Account Information',
                                        child: _buildInputField(
                                          controller: _emailController,
                                          label: 'Email Address',
                                          icon: Icons.alternate_email_rounded,
                                          readOnly: true,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                        ),
                                      ),

                                      const SizedBox(height: 32),

                                      // ── Save Button ─────────────────────
                                      _buildSaveButton(),

                                      const SizedBox(height: 12),

                                      // ── Discard hint ────────────────────
                                      Center(
                                        child: TextButton(
                                          onPressed:
                                              () => Navigator.pop(context),
                                          child: const Text(
                                            'Discard changes',
                                            style: TextStyle(
                                              color: _inkTertiary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
