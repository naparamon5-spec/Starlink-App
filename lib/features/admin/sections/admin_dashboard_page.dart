import 'package:flutter/material.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminScaffoldSection(
      title: 'Dashboard',
      description:
          'High-level overview of system metrics, recent activity, and quick actions.',
      icon: Icons.dashboard_outlined,
    );
  }
}

class AdminSubscriptionsPage extends StatelessWidget {
  const AdminSubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminScaffoldSection(
      title: 'Subscriptions',
      description:
          'Browse, search, and manage customer subscriptions and service lines.',
      icon: Icons.subscriptions_outlined,
    );
  }
}

class AdminTicketsPage extends StatelessWidget {
  const AdminTicketsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminScaffoldSection(
      title: 'Tickets',
      description:
          'Monitor and manage support tickets across all customers and agents.',
      icon: Icons.confirmation_number_outlined,
    );
  }
}

class AdminBillingPage extends StatelessWidget {
  const AdminBillingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminScaffoldSection(
      title: 'Billing',
      description:
          'Review invoices, payments, and billing cycles for subscriptions.',
      icon: Icons.receipt_long_outlined,
    );
  }
}

class AdminAgentsPage extends StatelessWidget {
  const AdminAgentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminScaffoldSection(
      title: 'Agents',
      description:
          'Manage support agents, roles, and assignments for customer tickets.',
      icon: Icons.group_outlined,
    );
  }
}

class AdminEndUsersPage extends StatelessWidget {
  const AdminEndUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminScaffoldSection(
      title: 'End Users',
      description:
          'View and manage end-user accounts, profiles, and associated subscriptions.',
      icon: Icons.people_alt_outlined,
    );
  }
}

class AdminManageUsersPage extends StatelessWidget {
  const AdminManageUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminScaffoldSection(
      title: 'Manage Users',
      description:
          'Create, update, and deactivate platform users, assign roles and permissions.',
      icon: Icons.manage_accounts_outlined,
    );
  }
}

class AdminEditProfilePage extends StatelessWidget {
  const AdminEditProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminScaffoldSection(
      title: 'Edit Profile',
      description:
          'Update your admin account information, password, and notification settings.',
      icon: Icons.person_outline,
    );
  }
}

class AdminUserGuidePage extends StatelessWidget {
  const AdminUserGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminScaffoldSection(
      title: 'User Guide',
      description:
          'Read documentation and guides on how to use the Starlink admin portal.',
      icon: Icons.menu_book_outlined,
    );
  }
}

class _AdminScaffoldSection extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _AdminScaffoldSection({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFF133343).withOpacity(0.08),
                child: Icon(
                  icon,
                  size: 36,
                  color: const Color(0xFF133343),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF133343),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                'This is a placeholder screen for the admin "$title" section.\n'
                'You can wire it to the actual API and tables later.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


