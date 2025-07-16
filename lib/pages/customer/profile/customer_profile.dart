import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/pages/customer/ticket/customer_ticket_screen.dart';
import '../../../services/api_service.dart';
import 'customer_edit_profile.dart';
import 'customer_security_settings.dart';
import 'customer_notification.dart';
import '../../login_screen.dart';
import 'dart:io';

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
    // Reload profile image when dependencies change
    _loadProfileImage();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Load profile image path from SharedPreferences
      final savedProfileImagePath = prefs.getString('profileImagePath');
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
          _userName = userData['name'] ?? 'N/A';
          _userLastName = userData['last_name'] ?? 'N/A';
          _userEmail = userData['email'] ?? 'N/A';
          _userPhone = userData['phone'] ?? 'N/A';
          _userAddress = userData['address'] ?? 'N/A';
          _jobTitle = userData['job_title'] ?? 'N/A';
          _companyName = userData['company_name'] ?? 'N/A';
          _userPosition = userData['position'] ?? 'customer';
          _isLoading = false;
        });

        // Save to SharedPreferences for offline access
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
      print('Error loading user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProfileImage() async {
    try {
      setState(() {
        _isImageLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final savedProfileImagePath = prefs.getString('profileImagePath');
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
        _userName = fullName;
      }
      if (lastName.isNotEmpty) {
        _userLastName = lastName;
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_id');
        await prefs.remove('token');
        // Add other session keys here if needed
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

  void _navigateToSecuritySettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SecuritySettingsScreen()),
    );
  }

  void _navigateToTickets() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomerTicketHistory(showAppBar: true),
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Column(
      children: [
        // Contact Info
        _InfoItem(
          icon: Icons.email_outlined,
          label: 'Email',
          value: _userEmail ?? 'Not set',
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
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text('Profile'),
                centerTitle: true,
                elevation: 2,
                backgroundColor: const Color(0xFF133343),
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(15),
                  ),
                ),
              )
              : null,
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
                                _userName ?? 'User',
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
                                  _userPosition?.toUpperCase() ?? 'CUSTOMER',
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

                      // Modern Action List
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _ProfileActionTile(
                              icon: Icons.edit,
                              label: 'Edit Profile',
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
                                // Refresh profile data if returned from edit screen
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
                              },
                            ),
                            _buildDivider(),
                            _ProfileActionTile(
                              icon: Icons.security,
                              label: 'Security Settings',
                              onTap: _navigateToSecuritySettings,
                            ),
                            _buildDivider(),
                            _ProfileActionTile(
                              icon: Icons.confirmation_number,
                              label: 'Tickets',
                              onTap: _navigateToTickets,
                            ),
                            _buildDivider(),
                            _ProfileActionTile(
                              icon: Icons.notifications_active,
                              label: 'Notification',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            const CustomerNotificationScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Logout button separated and styled
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: EdgeInsets.zero,
                        child: _ProfileActionTile(
                          icon: Icons.logout,
                          label: 'Logout',
                          iconColor: Colors.red[400],
                          textColor: Colors.red[400],
                          onTap: _handleLogout,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}

// Modern ListTile for Profile Actions
class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _ProfileActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (iconColor ?? Theme.of(context).primaryColor)
            .withOpacity(0.1),
        child: Icon(icon, color: iconColor ?? Theme.of(context).primaryColor),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
          // No fontFamily specified, matches _InfoItem and default app font
          color: Colors.black87,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey[400],
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      hoverColor: Colors.grey[100],
    );
  }
}

// Divider for between tiles
Widget _buildDivider() => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Divider(height: 1, color: Colors.grey[200]),
);

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
