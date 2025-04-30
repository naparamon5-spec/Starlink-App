import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        elevation: 2,
        backgroundColor: Color(0xFF133343),
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
                              // ignore: deprecated_member_use
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
                        'John Doe',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Profile Role/Title
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                            // ignore: deprecated_member_use
                          ).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Admin User',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Contact Info
                      const _InfoItem(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: 'johndoe@example.com',
                      ),

                      const Divider(height: 24),

                      const _InfoItem(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: '+1234567890',
                      ),

                      const Divider(height: 24),

                      const _InfoItem(
                        icon: Icons.location_on_outlined,
                        label: 'Location',
                        value: 'New York, USA',
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
                    onPressed: () {},
                    backgroundColor: Colors.grey[300] ?? Colors.grey,
                    iconColor: Colors.black87,
                    textColor: Colors.black87,
                  ),

                  const SizedBox(height: 12),

                  _ActionButton(
                    icon: Icons.security,
                    label: 'Privacy Settings',
                    onPressed: () {},
                    backgroundColor: Colors.grey[300] ?? Colors.grey,
                    iconColor: Colors.black87,
                    textColor: Colors.black87,
                  ),

                  const SizedBox(height: 12),

                  _ActionButton(
                    icon: Icons.notifications,
                    label: 'Notification Settings',
                    onPressed: () {},
                    backgroundColor: Colors.grey[300] ?? Colors.grey,
                    iconColor: Colors.black87,
                    textColor: Colors.black87,
                  ),

                  const SizedBox(height: 12),

                  _ActionButton(
                    icon: Icons.logout,
                    label: 'Logout',
                    onPressed: () {},
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
