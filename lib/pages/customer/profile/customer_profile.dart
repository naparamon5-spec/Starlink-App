import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_service.dart';
import 'customer_edit_profile.dart';
import 'customer_security_settings.dart';
import 'customer_notification.dart';
import '../../login_screen.dart';
import 'dart:io';

// ── Design tokens (matching home screen) ────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _success = Color(0xFF24A148);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);

class CustomerProfileScreen extends StatefulWidget {
  final bool showAppBar;

  const CustomerProfileScreen({super.key, this.showAppBar = true});

  @override
  _CustomerProfileScreenState createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  bool _isLoading = true;
  String? _userName;
  String? _userLastName;
  String? _userEmail;
  String? _userPhone;
  String? _userAddress;
  String? _userId;
  String? _jobTitle;
  String? _companyName;
  String? _userPosition;
  String? _profileImagePath;
  bool _isImageLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProfileImage();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId == null) throw Exception('User ID not found');

      final savedProfileImagePath = prefs.getString('profileImagePath');
      if (savedProfileImagePath != null) {
        setState(() => _profileImagePath = savedProfileImagePath);
      }

      final response = await ApiService.getCurrentUser(userId);

      if (response['status'] == 'success' && response['data'] != null) {
        final userData = response['data'];

        setState(() {
          _userId = userData['id']?.toString() ?? 'N/A';
          _userName = userData['name'] ?? 'N/A';
          _userLastName = userData['last_name'] ?? 'N/A';
          _userEmail = userData['email'] ?? 'N/A';
          _userPhone = userData['phone'] ?? 'N/A';
          _userAddress = userData['address'] ?? 'N/A';
          _jobTitle = userData['job_title'] ?? 'N/A';
          _companyName = userData['company_name'] ?? 'N/A';
          _userPosition = userData['role'] ?? 'N/A';
          _isLoading = false;
        });

        await prefs.setString('userId', _userId!);
        await prefs.setString('name', _userName!);
        await prefs.setString('lastName', _userLastName!);
        await prefs.setString('email', _userEmail!);
        await prefs.setString('phone', _userPhone!);
        await prefs.setString('address', _userAddress!);
        await prefs.setString('jobTitle', _jobTitle!);
        await prefs.setString('companyName', _companyName!);
        await prefs.setString('userType', _userPosition!);
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch user data');
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            backgroundColor: _primary,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProfileImage() async {
    try {
      setState(() => _isImageLoading = true);
      final prefs = await SharedPreferences.getInstance();
      final savedProfileImagePath = prefs.getString('profileImagePath');
      if (savedProfileImagePath != null &&
          savedProfileImagePath != _profileImagePath) {
        setState(() => _profileImagePath = savedProfileImagePath);
      }
    } catch (e) {
      debugPrint('Error loading profile image: $e');
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
      if (fullName.isNotEmpty) _userName = fullName;
      if (lastName.isNotEmpty) _userLastName = lastName;
      if (data['profileImagePath'] != null) {
        _profileImagePath = data['profileImagePath']!;
      }
    });
  }

  Future<void> _handleLogout() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          title: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: _primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Log out',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: _ink,
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to log out? You will need to sign in again to access your account.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _inkSecondary, height: 1.5),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: _inkSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Log out',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_id');
        await prefs.remove('token');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: ${e.toString()}'),
            backgroundColor: _primary,
          ),
        );
      }
    }
  }

  ImageProvider? _getProfileImage() {
    try {
      if (_profileImagePath != null) {
        final savedFile = File(_profileImagePath!);
        if (savedFile.existsSync()) return FileImage(savedFile);
      }
      return null;
    } catch (e) {
      debugPrint('Error loading profile image: $e');
      return null;
    }
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.trim()[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceSubtle,
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text(
                  'Profile',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                centerTitle: true,
                elevation: 0,
                backgroundColor: _surface,
                foregroundColor: _ink,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: _border),
                ),
              )
              : null,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // ── Profile hero card ────────────────────────────
                        _buildProfileHero(),
                        const SizedBox(height: 20),

                        // ── Section label ────────────────────────────────
                        const _SectionLabel(title: 'ACCOUNT'),
                        const SizedBox(height: 10),

                        // ── Actions card ─────────────────────────────────
                        _buildActionsCard(),
                        const SizedBox(height: 20),

                        // ── Logout card ──────────────────────────────────
                        _buildLogoutCard(),
                      ]),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildProfileHero() {
    final profileImage = _getProfileImage();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEB1E23), Color(0xFF760F12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryDark.withOpacity(0.38),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 38,
              backgroundImage: profileImage,
              backgroundColor: Colors.white.withOpacity(0.15),
              child:
                  _isImageLoading
                      ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                      : profileImage == null
                      ? Text(
                        _initials(_userName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                      : null,
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName ?? 'User',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (_userPosition ?? 'Customer').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      color: Colors.white70,
                      size: 13,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _userEmail ?? 'N/A',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.edit_outlined,
            label: 'Edit Profile',
            isFirst: true,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => EditProfileScreen(
                        onProfileUpdated: _updateProfileData,
                      ),
                ),
              );
              if (result != null && result is Map<String, dynamic>) {
                _updateProfileData(Map<String, String>.from(result));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.white),
                        SizedBox(width: 12),
                        Text('Profile updated successfully!'),
                      ],
                    ),
                    backgroundColor: _success,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
            },
          ),
          _Divider(),
          _ActionTile(
            icon: Icons.security_outlined,
            label: 'Security Settings',
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SecuritySettingsScreen(),
                  ),
                ),
          ),
          _Divider(),
          // _ActionTile(
          //   icon: Icons.confirmation_number_outlined,
          //   label: 'My Tickets',
          //   onTap:
          //       () => Navigator.push(
          //         context,
          //         MaterialPageRoute(
          //           builder:
          //               (context) =>
          //                   const CustomerTicketHistory(showAppBar: true),
          //         ),
          //       ),
          // ),
          _Divider(),
          _ActionTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            isLast: true,
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustomerNotificationScreen(),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _ActionTile(
        icon: Icons.logout_rounded,
        label: 'Log out',
        iconColor: _primary,
        labelColor: _primary,
        isFirst: true,
        isLast: true,
        onTap: _handleLogout,
      ),
    );
  }
}

// ── Reusable sub-widgets ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _inkTertiary,
        letterSpacing: 1.1,
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;
  final bool isFirst;
  final bool isLast;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? _inkSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(14) : Radius.zero,
          bottom: isLast ? const Radius.circular(14) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: effectiveIconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: labelColor ?? _ink,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _inkTertiary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(height: 1, color: _border),
  );
}
