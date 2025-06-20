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

        setState(() {
          _userId = userData['id']?.toString() ?? 'N/A';
          _fullName = userData['name'] ?? 'N/A';
          _lastName = userData['last_name'] ?? 'N/A';
          _position = userData['position'] ?? 'end_user';
          _isLoading = false;
        });

        // Save to SharedPreferences for offline access
        await _prefs.setString('userId', _userId);
        await _prefs.setString('name', _fullName);
        await _prefs.setString('lastName', _lastName);
        await _prefs.setString('position', _position);
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
      if (data['name'] != null) {
        _fullName = data['name']!;
      }
      if (data['lastName'] != null) {
        _lastName = data['lastName']!;
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
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Logout'),
            ),
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
        _InfoItem(icon: Icons.person_outline, label: 'Name', value: _fullName),
        const Divider(height: 24),
        _InfoItem(icon: Icons.badge_outlined, label: 'ID', value: _userId),
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

                              // Refresh profile data if returned from edit screen
                              if (result != null &&
                                  result is Map<String, dynamic>) {
                                _updateProfileData(
                                  Map<String, String>.from(result),
                                );
                              }
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
