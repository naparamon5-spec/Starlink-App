import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'edit_profile.dart';
import '../login_screen.dart';
import 'security_settings.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late SharedPreferences _prefs;
  String _jobTitle = 'No Job Title';
  String _companyName = 'Not Set';
  String _userId = '32';
  String _fullName = 'John Doe';
  String _email = 'johndoe@example.com';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _jobTitle = _prefs.getString('jobTitle') ?? 'No Job Title';
      _companyName = _prefs.getString('companyName') ?? 'Not Set';
      _userId = _prefs.getString('userId') ?? '32';

      String firstName = _prefs.getString('firstName') ?? 'John';
      String lastName = _prefs.getString('lastName') ?? 'Doe';
      String middleName = _prefs.getString('middleName') ?? '';
      _fullName =
          middleName.isEmpty
              ? '$firstName $lastName'
              : '$firstName $middleName $lastName';

      _email = _prefs.getString('email') ?? 'johndoe@example.com';
    });
  }

  void _updateProfileData(Map<String, String> data) {
    setState(() {
      _jobTitle = data['jobTitle'] ?? _jobTitle;
      _companyName = data['companyName'] ?? _companyName;
      if (data['firstName'] != null || data['lastName'] != null) {
        String firstName =
            data['firstName'] ?? _prefs.getString('firstName') ?? 'John';
        String lastName =
            data['lastName'] ?? _prefs.getString('lastName') ?? 'Doe';
        String middleName =
            data['middleName'] ?? _prefs.getString('middleName') ?? '';
        _fullName =
            middleName.isEmpty
                ? '$firstName $lastName'
                : '$firstName $middleName $lastName';
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
      body: Container(
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

                      // User ID
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
                          'ID: $_userId',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Contact Info
                      _InfoItem(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: _email,
                      ),

                      const Divider(height: 24),

                      _InfoItem(
                        icon: Icons.business_outlined,
                        label: 'Company',
                        value: _companyName,
                      ),

                      const Divider(height: 24),

                      _InfoItem(
                        icon: Icons.work_outline,
                        label: 'Job Title',
                        value: _jobTitle,
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
                          builder: (context) => const SecuritySettingsScreen(),
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
                    onPressed: () {},
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
