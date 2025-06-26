import 'package:flutter/material.dart';

class CustomerDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> subscription;

  const CustomerDetailsScreen({Key? key, required this.subscription})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isActive = subscription['active'] == true;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Header Section with Gradient and Horizontal Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF133343), Color(0xFF1E4B5F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
                image: const DecorationImage(
                  image: AssetImage('assets/images/logo_full.svg'),
                  fit: BoxFit.none,
                  alignment: Alignment.bottomRight,
                  opacity: 0.04,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Back Button (left) and Status Badge (right)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isActive
                                  ? const Color(0xFF2E7D32).withOpacity(0.12)
                                  : const Color(0xFFC62828).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow:
                              isActive
                                  ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF2E7D32,
                                      ).withOpacity(0.4),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                  : [],
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color:
                                    isActive
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFC62828),
                                shape: BoxShape.circle,
                                boxShadow:
                                    isActive
                                        ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF2E7D32,
                                            ).withOpacity(0.6),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                        : [],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color:
                                    isActive
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFC62828),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Subscription Name
                  Text(
                    subscription['nickname'] ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Service Line
                  Row(
                    children: [
                      const Icon(
                        Icons.router_outlined,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Service Line: ${subscription['serviceLineNumber'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 17,
                          color: Colors.white.withOpacity(0.92),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Details Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF133343),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildDetailCard(
                    icon: Icons.location_on_outlined,
                    title: 'Address',
                    content: subscription['address'] ?? 'N/A',
                  ),
                  const SizedBox(height: 16),
                  _buildDetailCard(
                    icon: Icons.calendar_today_outlined,
                    title: 'Start Date',
                    content: subscription['startDate'] ?? 'N/A',
                  ),
                  const SizedBox(height: 16),
                  _buildDetailCard(
                    icon: Icons.update_outlined,
                    title: 'End Date',
                    content: subscription['endDate'] ?? 'N/A',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement create ticket functionality
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Create Ticket'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF133343),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Implement view history functionality
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('View History'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF133343),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF133343)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF133343).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF133343), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF133343),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
