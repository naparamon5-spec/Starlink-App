import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../services/api_service.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _success = Color(0xFF24A148);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);

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
  late AnimationController _animController;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _emailController = TextEditingController();

  // Read-only fields from API
  String? _position;
  bool? _isActive; // true = active, false = inactive, null = unknown

  File? _selectedImageFile;
  String? _savedImagePath;
  bool _isImageLoading = false;
  bool _isLoading = true;

  String get _initials {
    final f = _firstNameController.text.trim();
    final l = _lastNameController.text.trim();
    if (f.isEmpty && l.isEmpty) return '?';
    return '${f.isNotEmpty ? f[0].toUpperCase() : ''}'
        '${l.isNotEmpty ? l[0].toUpperCase() : ''}';
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadSavedData();
  }

  @override
  void dispose() {
    _animController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadSavedData() async {
    setState(() => _isLoading = true);
    _prefs = await SharedPreferences.getInstance();

    String? firstName, lastName, middleName, email;

    try {
      // getCurrentUser routes to /v1/auth/me via ApiService.
      // _authorizedGet unwraps the outer envelope so response['data']
      // is the object: { id, name, email, role, position, inactive, ... }
      final response = await ApiService.getMe();

      if (response['status'] == 'success' && response['data'] != null) {
        final d = response['data'] as Map<String, dynamic>;

        firstName = _first(d, ['first_name']) ?? _prefs.getString('firstName');
        lastName = _first(d, ['last_name']) ?? _prefs.getString('lastName');
        middleName =
            _first(d, ['middle_name']) ?? _prefs.getString('middleName') ?? '';
        email = _first(d, ['email']) ?? _prefs.getString('email') ?? '';

        // ── Position ────────────────────────────────────────────────────────
        // API returns: "position": "Programmer"
        _position = _first(d, [
          'position',
          'job_title',
          'jobTitle',
          'title',
          'designation',
        ]);

        // ── Active status ────────────────────────────────────────────────────
        // API returns: "inactive": "N"  →  active = true
        //              "inactive": "Y"  →  active = false
        _isActive = _resolveActive(d);
      }
    } catch (_) {}

    // Fallback to cached prefs if API failed
    firstName ??= _prefs.getString('firstName') ?? '';
    lastName ??= _prefs.getString('lastName') ?? '';
    middleName ??= _prefs.getString('middleName') ?? '';
    email ??= _prefs.getString('email') ?? '';

    setState(() {
      _firstNameController.text = firstName!;
      _lastNameController.text = lastName!;
      _middleNameController.text = middleName!;
      _emailController.text = email!;
      _savedImagePath = _prefs.getString('profileImagePath');
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _animController.forward(),
    );
  }

  /// Returns the first non-empty string value found under any of [keys].
  String? _first(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k]?.toString().trim();
      if (v != null && v.isNotEmpty && v != 'null' && v != 'undefined') {
        return v;
      }
    }
    return null;
  }

  /// Resolves active status.
  ///
  /// Handles:
  ///   inactive: "N"  → active  (true)
  ///   inactive: "Y"  → inactive (false)
  ///   active:   true/false/1/0/"active"/"inactive" etc.
  bool? _resolveActive(Map<String, dynamic> data) {
    // ── "inactive" field (API returns "N" = active, "Y" = inactive) ─────────
    final inactiveRaw = data['inactive'];
    if (inactiveRaw != null) {
      final s = inactiveRaw.toString().toUpperCase().trim();
      if (s == 'N' || s == 'FALSE' || s == '0') {
        return true; // not inactive → active
      }
      if (s == 'Y' || s == 'TRUE' || s == '1') return false; // inactive
    }

    // ── "active" / "is_active" / "status" fallback ───────────────────────────
    for (final k in ['active', 'is_active', 'isActive', 'status', 'state']) {
      final raw = data[k];
      if (raw == null) continue;
      if (raw is bool) return raw;
      if (raw is int) return raw == 1;
      final s = raw.toString().toLowerCase().trim();
      if (s == 'true' || s == '1' || s == 'active' || s == 'enabled') {
        return true;
      }
      if (s == 'false' || s == '0' || s == 'inactive' || s == 'disabled') {
        return false;
      }
    }

    return null; // unknown
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    int? userId = _prefs.getInt('user_id');
    if (userId == null) {
      _showSnack('User ID not found.', isError: true);
      return;
    }
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
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : _success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Image helpers ──────────────────────────────────────────────────────────

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
              _showSnack('Image selected successfully');
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
      _showSnack('Profile image removed');
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _sheetTile(
                  ctx,
                  Icons.photo_library_outlined,
                  'Choose from Gallery',
                  _pickImage,
                ),
                if (_selectedImageFile != null || _savedImagePath != null)
                  _sheetTile(
                    ctx,
                    Icons.delete_outline,
                    'Remove Photo',
                    _removeProfileImage,
                    isDestructive: true,
                  ),
              ],
            ),
          ),
    );
  }

  Widget _sheetTile(
    BuildContext ctx,
    IconData icon,
    String label,
    VoidCallback action, {
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : _primary;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      onTap: () {
        Navigator.pop(ctx);
        action();
      },
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

  // ── Widget builders ────────────────────────────────────────────────────────

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _inkTertiary,
        letterSpacing: 1.1,
      ),
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          blurRadius: 8,
          color: Colors.black.withOpacity(.04),
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );

  Widget _field(
    TextEditingController c,
    String hint,
    IconData icon, {
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => Container(
    decoration: BoxDecoration(
      color: readOnly ? const Color(0xFFF0F0F0) : _surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: TextFormField(
      controller: c,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: TextStyle(color: readOnly ? _inkSecondary : _ink, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(
          icon,
          size: 18,
          color: readOnly ? _inkTertiary : _primary,
        ),
        hintText: hint,
        hintStyle: const TextStyle(color: _inkTertiary, fontSize: 14),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      validator: validator,
    ),
  );

  /// Styled read-only info row for position and status.
  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    Widget? trailing,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F0F0),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: _inkTertiary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: _inkTertiary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: valueColor ?? _inkSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );

  Widget _avatar() => Center(
    child: Stack(
      children: [
        GestureDetector(
          onTap: _showImageOptions,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEB1E23), Color(0xFF760F12)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _primaryDark.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
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
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : Text(
                                _initials,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                    )
                    : null,
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: _border, width: 2),
            ),
            child: IconButton(
              icon: const Icon(Icons.camera_alt, size: 16, color: _primary),
              onPressed: _isImageLoading ? null : _showImageOptions,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: const EdgeInsets.all(6),
            ),
          ),
        ),
      ],
    ),
  );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── Status display values ──────────────────────────────────────────────
    final positionDisplay =
        (_position != null && _position!.isNotEmpty) ? _position! : '—';

    final String statusLabel;
    final Color statusColor;
    final Color statusBadgeBg;

    if (_isActive == null) {
      statusLabel = '—';
      statusColor = _inkTertiary;
      statusBadgeBg = _surfaceSubtle;
    } else if (_isActive!) {
      statusLabel = 'Active';
      statusColor = _success;
      statusBadgeBg = _success.withOpacity(0.10);
    } else {
      statusLabel = 'Inactive';
      statusColor = _primary;
      statusBadgeBg = _primary.withOpacity(0.10);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _surfaceSubtle,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              // ── Gradient header ──────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFEB1E23), Color(0xFF760F12)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'Edit Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (!_isLoading)
                          TextButton(
                            onPressed: _isImageLoading ? null : _saveProfile,
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Scrollable body ──────────────────────────────────────
              Expanded(
                child:
                    _isLoading
                        ? const Center(
                          child: CircularProgressIndicator(color: _primary),
                        )
                        : AnimatedBuilder(
                          animation: _animController,
                          builder:
                              (context, child) => Opacity(
                                opacity: _animController.value,
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    20 * (1 - _animController.value),
                                  ),
                                  child: child,
                                ),
                              ),
                          child: Form(
                            key: _formKey,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                24,
                                20,
                                32,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Avatar
                                  _avatar(),
                                  const SizedBox(height: 8),
                                  const Center(
                                    child: Text(
                                      'Tap to change photo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _inkTertiary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 28),

                                  // ── Personal Information ──────────────
                                  _sectionTitle('PERSONAL INFORMATION'),
                                  _card(
                                    child: Column(
                                      children: [
                                        _field(
                                          _firstNameController,
                                          'First Name',
                                          Icons.person_outline,
                                          validator:
                                              (v) =>
                                                  v?.isEmpty ?? true
                                                      ? 'Required'
                                                      : null,
                                        ),
                                        const SizedBox(height: 12),
                                        _field(
                                          _lastNameController,
                                          'Last Name',
                                          Icons.person_outline,
                                          validator:
                                              (v) =>
                                                  v?.isEmpty ?? true
                                                      ? 'Required'
                                                      : null,
                                        ),
                                        const SizedBox(height: 12),
                                        _field(
                                          _middleNameController,
                                          'Middle Name (Optional)',
                                          Icons.person_outline,
                                        ),
                                        const SizedBox(height: 12),
                                        _field(
                                          _emailController,
                                          'Email Address',
                                          Icons.email_outlined,
                                          readOnly: true,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // ── Account Details (read-only) ───────
                                  _sectionTitle('ACCOUNT DETAILS'),
                                  _card(
                                    child: Column(
                                      children: [
                                        // Position
                                        _infoRow(
                                          icon: Icons.work_outline_rounded,
                                          label: 'Position',
                                          value: positionDisplay,
                                        ),
                                        const SizedBox(height: 12),
                                        // Account Status
                                        _infoRow(
                                          icon: Icons.verified_user_outlined,
                                          label: 'Account Status',
                                          value: statusLabel,
                                          valueColor:
                                              _isActive == null
                                                  ? _inkTertiary
                                                  : statusColor,
                                          trailing:
                                              _isActive != null
                                                  ? Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: statusBadgeBg,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      statusLabel.toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: statusColor,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  )
                                                  : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 28),

                                  // ── Save button ───────────────────────
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed:
                                          _isImageLoading ? null : _saveProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      child:
                                          _isImageLoading
                                              ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation(
                                                        Colors.white,
                                                      ),
                                                ),
                                              )
                                              : const Text(
                                                'Save Changes',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
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
      ),
    );
  }
}
