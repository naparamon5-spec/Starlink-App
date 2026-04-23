import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_service.dart';
import 'edit_profile.dart';
import '../../login_screen.dart';
import 'security_settings.dart';
import 'notifications.dart';
import 'dart:io';

// ── Design Tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _ink = Color(0xFF1A1A1A);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF7F7F7);
const _border = Color(0xFFEAEAEA);
const _danger = Color(0xFFEB1E23);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late SharedPreferences _prefs;
  String _position = 'Loading...';
  String _userId = 'Loading...';
  String _fullName = 'Loading...';
  String _lastName = 'Loading...';
  String? _profileImagePath;
  String _userEmail = 'Loading...';
  bool _isLoading = true;
  bool _isImageLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String get _initials {
    final parts = _fullName.trim().split(' ');
    if (parts.isEmpty || _fullName == 'Loading...') return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadProfileData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProfileImage();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<int?> _resolveUserId() async {
    int? userId = _prefs.getInt('user_id');
    if (userId != null) return userId;
    for (final key in ['user_id', 'userId', 'id']) {
      final strVal = _prefs.getString(key);
      if (strVal != null) {
        final parsed = int.tryParse(strVal);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  Future<void> _loadProfileData() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final userId = await _resolveUserId();
      if (userId == null) throw Exception('User ID not found');

      final savedImagePath = _prefs.getString('profileImagePath');
      if (savedImagePath != null) {
        setState(() => _profileImagePath = savedImagePath);
      }

      final response = await ApiService.getCurrentUser(userId);
      if (response['status'] == 'success' && response['data'] != null) {
        final userData = response['data'];
        final firstName = userData['first_name'] ?? '';
        final lastName = userData['last_name'] ?? '';
        final middleName = userData['middle_name'] ?? '';
        final fullName =
            (firstName +
                    (middleName.isNotEmpty ? ' $middleName' : '') +
                    (lastName.isNotEmpty ? ' $lastName' : ''))
                .trim();

        setState(() {
          _userId = userData['id']?.toString() ?? 'N/A';
          _fullName =
              fullName.isNotEmpty ? fullName : (userData['name'] ?? 'N/A');
          _lastName =
              lastName.isNotEmpty ? lastName : (userData['last_name'] ?? 'N/A');
          _position = userData['position'] ?? 'end_user';
          _userEmail = userData['email'] ?? _prefs.getString('email') ?? 'N/A';
          _isLoading = false;
        });

        final parsedId = int.tryParse(_userId);
        if (parsedId != null) await _prefs.setInt('user_id', parsedId);
        await _prefs.setString('name', _fullName);
        await _prefs.setString('lastName', _lastName);
        await _prefs.setString('position', _position);
        await _prefs.setString('email', _userEmail);

        _fadeController.forward(from: 0);
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch user data');
      }
    } catch (e) {
      setState(() {
        _userId =
            _prefs.getString('userId') ?? _prefs.getString('user_id') ?? 'N/A';
        _fullName = _prefs.getString('name') ?? 'N/A';
        _lastName = _prefs.getString('lastName') ?? 'N/A';
        _position = _prefs.getString('position') ?? 'N/A';
        _userEmail = _prefs.getString('email') ?? 'N/A';
        _isLoading = false;
      });
      _fadeController.forward(from: 0);
      if (mounted) {
        _showSnack('Error loading profile: $e', isError: true);
      }
    }
  }

  Future<void> _loadProfileImage() async {
    try {
      setState(() => _isImageLoading = true);
      final saved = _prefs.getString('profileImagePath');
      if (saved != null && saved != _profileImagePath) {
        setState(() => _profileImagePath = saved);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isImageLoading = false);
    }
  }

  void _updateProfileData(Map<String, String> data) {
    setState(() {
      final firstName = data['firstName'] ?? '';
      final middleName = data['middleName'] ?? '';
      final lastName = data['lastName'] ?? '';
      final fullName =
          (firstName +
                  (middleName.isNotEmpty ? ' $middleName' : '') +
                  (lastName.isNotEmpty ? ' $lastName' : ''))
              .trim();
      if (fullName.isNotEmpty) _fullName = fullName;
      if (lastName.isNotEmpty) _lastName = lastName;
      if (data['profileImagePath'] != null) {
        _profileImagePath = data['profileImagePath']!;
      }
    });
  }

  Future<void> _handleLogout() async {
    HapticFeedback.mediumImpact();
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: _primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Log Out?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Are you sure you want to log out of your account?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: _inkSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            backgroundColor: _surfaceSubtle,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: _inkSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: _surface,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: const Text(
                            'Log Out',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );

    if (shouldLogout == true) {
      try {
        await ApiService.logout();
        await _prefs.remove('user_id');
        await _prefs.remove('userId');
        await _prefs.remove('token');
        await _prefs.remove('name');
        await _prefs.remove('lastName');
        await _prefs.remove('position');
        await _prefs.remove('email');
        await _prefs.remove('userProfile');
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      } catch (e) {
        if (mounted) _showSnack('Error logging out: $e', isError: true);
      }
    }
  }

  ImageProvider? _getProfileImage() {
    try {
      if (_profileImagePath != null) {
        final file = File(_profileImagePath!);
        if (file.existsSync()) return FileImage(file);
      }
    } catch (_) {}
    return null;
  }

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
        backgroundColor:
            isError ? Colors.red.shade700 : const Color(0xFF24A148),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildHeroSection() {
    final profileImage = _getProfileImage();
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEB1E23), Color(0xFF9B1215)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            children: [
              // Avatar
              Stack(
                alignment: Alignment.center,
                children: [
                  // Glow ring
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  // White border + photo
                  Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEB1E23), Color(0xFF760F12)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          image:
                              profileImage != null
                                  ? DecorationImage(
                                    image: profileImage,
                                    fit: BoxFit.cover,
                                  )
                                  : null,
                        ),
                        child:
                            profileImage == null
                                ? Center(
                                  child:
                                      _isImageLoading
                                          ? const SizedBox(
                                            width: 26,
                                            height: 26,
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
                                              fontSize: 32,
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
                ],
              ),

              const SizedBox(height: 16),

              // Name
              Text(
                _fullName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),

              // Email
              Text(
                _userEmail,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.75),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),

              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  _position.toUpperCase().replaceAll('_', ' '),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection({
    required String title,
    required List<_MenuItemData> items,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _inkTertiary,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: List.generate(items.length * 2 - 1, (index) {
                if (index.isOdd) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 68),
                    child: Container(height: 1, color: _border),
                  );
                }
                return items[index ~/ 2].build(context);
              }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _surfaceSubtle,
        body:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: _primary),
                )
                : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Hero ──────────────────────────────────────────
                        _buildHeroSection(),

                        // ── Curved white bridge ───────────────────────────
                        Container(
                          height: 20,
                          decoration: const BoxDecoration(
                            color: _surfaceSubtle,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          transform: Matrix4.translationValues(0, -20, 0),
                        ),

                        // ── Account section ───────────────────────────────
                        Transform.translate(
                          offset: const Offset(0, -20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMenuSection(
                                title: 'ACCOUNT',
                                items: [
                                  _MenuItemData(
                                    icon: Icons.person_outline_rounded,
                                    label: 'Edit Profile',
                                    subtitle: 'Update your name and photo',
                                    iconBg: _primary.withOpacity(0.1),
                                    iconColor: _primary,
                                    onTap: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => EditProfileScreen(
                                                onProfileUpdated:
                                                    _updateProfileData,
                                              ),
                                        ),
                                      );
                                      if (result != null &&
                                          result is Map<String, dynamic>) {
                                        _updateProfileData(
                                          Map<String, String>.from(result),
                                        );
                                        _showSnack(
                                          'Profile updated successfully',
                                        );
                                      }
                                      setState(() => _isLoading = true);
                                      await _loadProfileData();
                                    },
                                  ),
                                  _MenuItemData(
                                    icon: Icons.lock_outline_rounded,
                                    label: 'Security Settings',
                                    subtitle: 'Change your password',
                                    iconBg: const Color(0xFFE8F0FE),
                                    iconColor: const Color(0xFF1A56DB),
                                    onTap:
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) =>
                                                    const SecuritySettingsScreen(),
                                          ),
                                        ),
                                  ),
                                  _MenuItemData(
                                    icon: Icons.notifications_outlined,
                                    label: 'Notifications',
                                    subtitle: 'View your notifications',
                                    iconBg: const Color(0xFFE6F4EA),
                                    iconColor: const Color(0xFF1A7F37),
                                    onTap:
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) =>
                                                    const NotificationsPage(),
                                          ),
                                        ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // ── Danger zone ───────────────────────────
                              _buildMenuSection(
                                title: 'SESSION',
                                items: [
                                  _MenuItemData(
                                    icon: Icons.logout_rounded,
                                    label: 'Log Out',
                                    subtitle: 'Sign out of your account',
                                    iconBg: _primary.withOpacity(0.1),
                                    iconColor: _primary,
                                    labelColor: _primary,
                                    onTap: _handleLogout,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 32),
                            ],
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

// ── Menu item data model ───────────────────────────────────────────────────────

class _MenuItemData {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconBg;
  final Color iconColor;
  final Color? labelColor;
  final VoidCallback onTap;

  const _MenuItemData({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
    this.labelColor,
  });

  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            // Label + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: labelColor ?? _ink,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _inkTertiary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: labelColor ?? _inkTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
