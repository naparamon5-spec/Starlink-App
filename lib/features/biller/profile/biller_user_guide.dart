import 'package:flutter/material.dart';

class BillerUserGuidePage extends StatefulWidget {
  const BillerUserGuidePage({super.key});

  @override
  State<BillerUserGuidePage> createState() => _BillerUserGuidePageState();
}

class _BillerUserGuidePageState extends State<BillerUserGuidePage> {
  int? _expandedIndex;

  static const _sections = [
    _GuideSection(
      icon: Icons.dashboard_outlined,
      color: Color(0xFF4F46E5),
      title: 'Dashboard Overview',
      subtitle: 'Track revenue and billing activity',
      steps: [
        _GuideStep(
          title: 'Revenue Summary',
          body:
              'At the top of your dashboard you will see total revenue, collected payments, pending invoices, and overdue balances. This gives you a quick financial snapshot of your billing performance.',
        ),
        _GuideStep(
          title: 'Invoice Status Breakdown',
          body:
              'A visual breakdown shows Paid, Pending, and Overdue invoices. This helps you quickly identify which accounts need follow-up.',
        ),
        _GuideStep(
          title: 'Recent Transactions',
          body:
              'The activity feed displays recent payments, newly generated invoices, and updated billing records in real time.',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.receipt_long_outlined,
      color: Color(0xFFF59E0B),
      title: 'Invoices & Billing',
      subtitle: 'Create and manage invoices',
      steps: [
        _GuideStep(
          title: 'Creating an Invoice',
          body:
              'Tap the "Create Invoice" button from the Billing screen. Fill in client details, amount, due date, and description. Once submitted, the invoice is generated and sent to the client.',
        ),
        _GuideStep(
          title: 'Invoice Status',
          body:
              'Invoices can be marked as Paid, Pending, or Overdue. Status updates automatically when payments are recorded.',
        ),
        _GuideStep(
          title: 'Sending Reminders',
          body:
              'For unpaid invoices, you can send reminders to clients. This helps reduce overdue payments and improves collection rates.',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.subscriptions_outlined,
      color: Color(0xFF10B981),
      title: 'Subscriptions',
      subtitle: 'Manage client plans and renewals',
      steps: [
        _GuideStep(
          title: 'Viewing Subscriptions',
          body:
              'Access all client subscriptions including plan type, billing cycle, and renewal date. This helps you monitor recurring revenue.',
        ),
        _GuideStep(
          title: 'Renewals',
          body:
              'Subscriptions nearing expiry will be marked as Expiring. Follow up with clients to ensure continuous service.',
        ),
        _GuideStep(
          title: 'Plan Changes',
          body:
              'You can upgrade or downgrade client plans based on their needs. Changes will reflect in the next billing cycle.',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.people_alt_outlined,
      color: Color(0xFF6366F1),
      title: 'Clients',
      subtitle: 'Manage billing accounts',
      steps: [
        _GuideStep(
          title: 'Viewing Clients',
          body:
              'Browse all registered clients and their billing profiles. Each client shows active subscriptions and outstanding balances.',
        ),
        _GuideStep(
          title: 'Client Billing History',
          body:
              'Open a client profile to view past invoices, payments, and transaction history.',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.settings_outlined,
      color: Color(0xFF94A3B8),
      title: 'Profile & Settings',
      subtitle: 'Manage your biller account',
      steps: [
        _GuideStep(
          title: 'Editing Profile',
          body:
              'Update your business name, contact details, and billing information in the Edit Profile section.',
        ),
        _GuideStep(
          title: 'Payment Settings',
          body:
              'Configure supported payment methods such as bank transfer, e-wallets, or cards.',
        ),
        _GuideStep(
          title: 'Notifications',
          body:
              'Enable alerts for new payments, overdue invoices, and subscription renewals.',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        elevation: 0,
        title: const Text(
          'Biller Guide',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Header ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: Row(
              children: const [
                Icon(Icons.menu_book, color: Color(0xFF4F46E5)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Learn how to manage billing, invoices, and client payments efficiently.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Sections ───────────────────────────
          ..._sections.asMap().entries.map((entry) {
            final i = entry.key;
            final section = entry.value;
            final isOpen = _expandedIndex == i;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        isOpen
                            ? section.color.withOpacity(0.4)
                            : const Color(0xFF1F2937),
                  ),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap:
                          () => setState(
                            () => _expandedIndex = isOpen ? null : i,
                          ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(section.icon, color: section.color, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    section.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    section.subtitle,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isOpen
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isOpen)
                      Column(
                        children:
                            section.steps.map((step) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  10,
                                  14,
                                  10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      step.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      step.body,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Models ─────────────────────────────

class _GuideSection {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final List<_GuideStep> steps;

  const _GuideSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.steps,
  });
}

class _GuideStep {
  final String title, body;

  const _GuideStep({required this.title, required this.body});
}
