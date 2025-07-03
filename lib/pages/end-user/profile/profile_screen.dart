import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_service.dart';
import 'edit_profile.dart';
import '../../login_screen.dart';
import 'security_settings.dart';
import 'notifications.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late SharedPreferences _prefs;
  String _position = 'Loading...';
  String _userId = 'Loading...';
  String _fullName = 'Loading...';
  String _lastName = 'Loading...';
  String? _profileImagePath;
  String _userEmail = 'Loading...';
  bool _isLoading = true;
  bool _isImageLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload profile image when dependencies change
    _loadProfileImage();
  }

  Future<void> _loadProfileData() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final userId = _prefs.getInt('user_id');

      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Load profile image path from SharedPreferences
      final savedProfileImagePath = _prefs.getString('profileImagePath');
      if (savedProfileImagePath != null) {
        setState(() {
          _profileImagePath = savedProfileImagePath;
        });
      }

      // Get data from API
      final response = await ApiService.getCurrentUser(userId);

      if (response['status'] == 'success' && response['data'] != null) {
        final userData = response['data'];
        final firstName = userData['first_name'] ?? '';
        final lastName = userData['last_name'] ?? '';
        final middleName = userData['middle_name'] ?? '';
        final fullName =
            (firstName +
                    (middleName.isNotEmpty ? ' ' + middleName : '') +
                    (lastName.isNotEmpty ? ' ' + lastName : ''))
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

        // Save to SharedPreferences for offline access
        await _prefs.setString('userId', _userId);
        await _prefs.setString('name', _fullName);
        await _prefs.setString('lastName', _lastName);
        await _prefs.setString('position', _position);
        await _prefs.setString('email', _userEmail);
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch user data');
      }
    } catch (e) {
      print('Error loading profile data: $e');
      // Fallback to SharedPreferences if there's an error
      setState(() {
        _userId = _prefs.getString('userId') ?? 'N/A';
        _fullName = _prefs.getString('name') ?? 'N/A';
        _lastName = _prefs.getString('lastName') ?? 'N/A';
        _position = _prefs.getString('position') ?? 'N/A';
        _userEmail = _prefs.getString('email') ?? 'N/A';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadProfileImage() async {
    try {
      setState(() {
        _isImageLoading = true;
      });

      final savedProfileImagePath = _prefs.getString('profileImagePath');
      if (savedProfileImagePath != null &&
          savedProfileImagePath != _profileImagePath) {
        setState(() {
          _profileImagePath = savedProfileImagePath;
        });
      }
    } catch (e) {
      print('Error loading profile image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isImageLoading = false;
        });
      }
    }
  }

  void _updateProfileData(Map<String, String> data) {
    setState(() {
      // Compose full name from first, middle, last name if available
      final firstName = data['firstName'] ?? '';
      final middleName = data['middleName'] ?? '';
      final lastName = data['lastName'] ?? '';
      final fullName =
          (firstName +
                  (middleName.isNotEmpty ? ' ' + middleName : '') +
                  (lastName.isNotEmpty ? ' ' + lastName : ''))
              .trim();
      if (fullName.isNotEmpty) {
        _fullName = fullName;
      }
      if (lastName.isNotEmpty) {
        _lastName = lastName;
      }
      if (data['profileImagePath'] != null) {
        _profileImagePath = data['profileImagePath']!;
      }
    });
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog
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
              Icon(Icons.logout_rounded, color: Colors.red[400], size: 48),
              const SizedBox(height: 16),
              const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout? You will need to log in again to access your account.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black87, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );

    // If user confirms logout, proceed with logout
    if (shouldLogout == true) {
      try {
        await _prefs.clear();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildProfileInfo() {
    return Column(
      children: [
        // Contact Info
        _InfoItem(
          icon: Icons.email_outlined,
          label: 'Email',
          value: _userEmail,
        ),
      ],
    );
  }

  /// Get the profile image provider
  ImageProvider? _getProfileImage() {
    try {
      if (_profileImagePath != null) {
        final savedFile = File(_profileImagePath!);
        if (savedFile.existsSync()) {
          return FileImage(savedFile);
        }
      }
      return null;
    } catch (e) {
      print('Error loading profile image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF133343),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                decoration: BoxDecoration(color: Colors.grey[50]),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Profile Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              // Profile Image
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).primaryColor,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundImage: _getProfileImage(),
                                  backgroundColor: Colors.grey[200],
                                  child:
                                      _isImageLoading
                                          ? const CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF133343),
                                                ),
                                          )
                                          : _getProfileImage() == null
                                          ? const Icon(
                                            Icons.person,
                                            size: 40,
                                            color: Color(0xFF133343),
                                          )
                                          : null,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Profile Name
                              Text(
                                _fullName,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),

                              const SizedBox(height: 4),

                              // User Role and ID
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _position.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              _buildProfileInfo(),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons - Vertically arranged
                      Column(
                        children: [
                          _ActionButton(
                            icon: Icons.edit,
                            label: 'Edit Profile',
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => EditProfileScreen(
                                        onProfileUpdated: _updateProfileData,
                                      ),
                                ),
                              );
                              // Update UI with returned data if available
                              if (result != null &&
                                  result is Map<String, dynamic>) {
                                _updateProfileData(
                                  Map<String, String>.from(result),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Profile updated successfully!',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFF133343),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                              }
                              setState(() {
                                _isLoading = true;
                              });
                              await _loadProfileData();
                            },
                            backgroundColor: Colors.grey[300] ?? Colors.grey,
                            iconColor: Colors.black87,
                            textColor: Colors.black87,
                          ),

                          const SizedBox(height: 12),

                          _ActionButton(
                            icon: Icons.security,
                            label: 'Security Settings',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const SecuritySettingsScreen(),
                                ),
                              );
                            },
                            backgroundColor: Colors.grey[300] ?? Colors.grey,
                            iconColor: Colors.black87,
                            textColor: Colors.black87,
                          ),

                          const SizedBox(height: 12),

                          _ActionButton(
                            icon: Icons.notifications_active,
                            label: 'Notification',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const NotificationsPage(),
                                ),
                              );
                            },
                            backgroundColor: Colors.grey[300] ?? Colors.grey,
                            iconColor: Colors.black87,
                            textColor: Colors.black87,
                          ),

                          const SizedBox(height: 12),

                          _ActionButton(
                            icon: Icons.logout,
                            label: 'Logout',
                            onPressed: _handleLogout,
                            backgroundColor: Colors.grey[300] ?? Colors.grey,
                            iconColor: Colors.black87,
                            textColor: Colors.black87,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}

// Component for profile information items
class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.grey[700], size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }
}

// Component for action buttons
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
