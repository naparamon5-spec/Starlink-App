import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_service.dart';
import 'edit_profile.dart';
import '../../login_screen.dart';
import 'security_settings.dart';
import 'notifications.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late SharedPreferences _prefs;
  String _jobTitle = 'Loading...';
  String _userId = 'Loading...';
  String _fullName = 'Loading...';
  String _email = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final userId = _prefs.getInt('user_id');

      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Get data from API
      final response = await ApiService.getCurrentUser(userId);

      if (response['success'] == true && response['data'] != null) {
        final userData = response['data'];

        setState(() {
          _userId = userData['id']?.toString() ?? 'N/A';
          _fullName = userData['name'] ?? 'N/A';
          _jobTitle = userData['role'] ?? 'end_user';
          _isLoading = false;
        });

        // Save to SharedPreferences for offline access
        await _prefs.setString('userId', _userId);
        await _prefs.setString('name', _fullName);
        await _prefs.setString('jobTitle', _jobTitle);
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch user data');
      }
    } catch (e) {
      print('Error loading profile data: $e');
      // Fallback to SharedPreferences if there's an error
      setState(() {
        _userId = _prefs.getString('userId') ?? 'N/A';
        _fullName = _prefs.getString('name') ?? 'N/A';
        _jobTitle = _prefs.getString('jobTitle') ?? 'N/A';
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

  void _updateProfileData(Map<String, String> data) {
    setState(() {
      _jobTitle = data['jobTitle'] ?? _jobTitle;
      if (data['name'] != null) {
        _fullName = data['name']!;
      }
      _email = data['email'] ?? _email;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        elevation: 2,
        backgroundColor: const Color(0xFF133343),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
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
                                  backgroundImage: const AssetImage(
                                    'assets/images/profile_placeholder.png',
                                  ),
                                  backgroundColor: Colors.grey[200],
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
                                  _jobTitle.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Contact Info
                              _InfoItem(
                                icon: Icons.person_outline,
                                label: 'Name',
                                value: _fullName,
                              ),

                              const Divider(height: 24),

                              _InfoItem(
                                icon: Icons.badge_outlined,
                                label: 'ID',
                                value: _userId,
                              ),

                              const Divider(height: 24),

                              _InfoItem(
                                icon: Icons.work_outline,
                                label: 'Role',
                                value: _jobTitle.toUpperCase(),
                              ),
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
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => EditProfileScreen(
                                        onProfileUpdated: _updateProfileData,
                                      ),
                                ),
                              );
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
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                            },
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
