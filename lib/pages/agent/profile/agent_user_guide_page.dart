import 'package:flutter/material.dart';

class AgentUserGuidePage extends StatefulWidget {
  const AgentUserGuidePage({super.key});

  @override
  State<AgentUserGuidePage> createState() => _AgentUserGuidePageState();
}

class _AgentUserGuidePageState extends State<AgentUserGuidePage> {
  int? _expandedIndex;

  static const _sections = [
    _GuideSection(
      icon: Icons.dashboard_outlined,
      color: Color(0xFF6366F1),
      title: 'Dashboard Overview',
      subtitle: 'Understand your performance metrics',
      steps: [
        _GuideStep(
          title: 'My Performance Card',
          body:
              'At the top of your dashboard you will find your personal performance summary — total assigned tickets, open count, resolved count, and a circular completion percentage. The "On Track" badge turns green when your resolution rate is above target.',
        ),
        _GuideStep(
          title: 'Ticket Overview Bar',
          body:
              'The segmented colour bar gives you a quick visual breakdown of your ticket statuses: amber = Open, indigo = In Progress, green = Resolved, grey = Pending. Hover or tap any segment to see the exact count.',
        ),
        _GuideStep(
          title: 'My Stats Row',
          body:
              'Three KPI cards show your weekly average response time, customer satisfaction score, and resolved ticket count. These reset every Monday at 00:00 UTC.',
        ),
        _GuideStep(
          title: 'Recent Activity Feed',
          body:
              'The feed lists the latest events related to your account — new assignments, resolved tickets, and replies from end users — in reverse chronological order.',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.confirmation_number_outlined,
      color: Color(0xFFF59E0B),
      title: 'Working with Tickets',
      subtitle: 'Create, manage and resolve tickets',
      steps: [
        _GuideStep(
          title: 'Creating a Ticket',
          body:
              'Only agents can create tickets on behalf of end users. Tap the ⚡ Quick Action FAB at the bottom centre of the screen, then select "Tickets". Press "Create Ticket" and fill in the subject, end user, priority, category and description. Tap Submit when ready.',
        ),
        _GuideStep(
          title: 'Priority Levels',
          body:
              'Use Low for non-urgent cosmetic issues, Medium for standard bugs or questions, High for functionality blockers, and Urgent for complete service outages. Urgent tickets are auto-escalated to your team lead.',
        ),
        _GuideStep(
          title: 'Filtering & Searching',
          body:
              'Use the filter chips (All · Open · In Progress · Resolved · Pending) at the top of the Tickets screen to narrow your list. Counts next to each chip update in real time.',
        ),
        _GuideStep(
          title: 'Resolving a Ticket',
          body:
              'Open any ticket card and tap "Mark as Resolved" once the issue has been addressed. The ticket moves to the Resolved filter and the end user receives an automatic closure email.',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.people_alt_outlined,
      color: Color(0xFF10B981),
      title: 'End Users',
      subtitle: 'View users and manage their tickets',
      steps: [
        _GuideStep(
          title: 'Viewing End Users',
          body:
              'Navigate to the End Users tab from the bottom nav bar. You can search by name or company using the search bar at the top. Each card shows the user plan tier, company, and number of open tickets.',
        ),
        _GuideStep(
          title: 'Creating a Ticket for a User',
          body:
              'From the End Users list, tap the "+ Ticket" button on any user card to immediately open the Create Ticket form pre-filled with that user details. You can also do this from the Manage Users page in Settings.',
        ),
        _GuideStep(
          title: 'Agent Permissions',
          body:
              'As an agent you have view-only access to the end user list — you cannot create, edit or delete user accounts. If a new end user needs to be added, contact your admin.',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.subscriptions_outlined,
      color: Color(0xFF6366F1),
      title: 'Subscriptions & Billing',
      subtitle: 'Monitor plans and invoices',
      steps: [
        _GuideStep(
          title: 'Viewing Subscriptions',
          body:
              'Tap the ⚡ FAB and select "Subs" to open the Subscriptions screen. You will see each client plan tier, seat count, monthly recurring revenue (MRR), renewal date, and status badge (Active / Expiring).',
        ),
        _GuideStep(
          title: 'Expiring Subscriptions',
          body:
              'Subscriptions renewing within 7 days show an "Expiring" red badge. Contact the client proactively to ensure renewal and prevent service interruption. Escalate to your biller if the client requests a plan change.',
        ),
        _GuideStep(
          title: 'Viewing Billing & Invoices',
          body:
              'Tap the ⚡ FAB and select "Billing" to review recent invoices. Each card shows the invoice ID, client, amount, date and status (Paid / Pending / Overdue). Agents have view-only access — billing actions must be performed by a Biller role.',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.settings_outlined,
      color: Color(0xFF94A3B8),
      title: 'Settings & Profile',
      subtitle: 'Manage your account preferences',
      steps: [
        _GuideStep(
          title: 'Editing Your Profile',
          body:
              'Go to Settings → Edit Profile to update your display name, email, phone number, bio and availability status. Changes are saved immediately. Your status dot in the app bar updates in real time.',
        ),
        _GuideStep(
          title: 'Changing Your Password',
          body:
              'Go to Settings → Change Password. You will need to enter your current password before setting a new one. Passwords must be at least 8 characters and include one number and one special character.',
        ),
        _GuideStep(
          title: 'Notification Preferences',
          body:
              'Settings → Notifications lets you toggle push and email alerts for new ticket assignments, end-user replies, ticket escalations and subscription expiry warnings.',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1923),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF162032),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E3050)),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        title: const Text(
          'Agent Guide',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Hero banner ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1060), Color(0xFF162032)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.menu_book_outlined,
                    color: Color(0xFF6366F1),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Agent Guide',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tips, best practices and how-to guides for Support Agents.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Expandable sections ───────────────────────────────────────────
          ..._sections.asMap().entries.map((entry) {
            final i = entry.key;
            final section = entry.value;
            final isOpen = _expandedIndex == i;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF162032),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        isOpen
                            ? section.color.withOpacity(0.4)
                            : const Color(0xFF1E3050),
                    width: isOpen ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Section header
                    GestureDetector(
                      onTap:
                          () => setState(
                            () => _expandedIndex = isOpen ? null : i,
                          ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: section.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                section.icon,
                                color: section.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    section.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    section.subtitle,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AnimatedRotation(
                              turns: isOpen ? 0.5 : 0,
                              duration: const Duration(milliseconds: 250),
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                color:
                                    isOpen
                                        ? section.color
                                        : const Color(0xFF64748B),
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expandable steps
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 280),
                      crossFadeState:
                          isOpen
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Column(
                        children: [
                          Container(height: 1, color: const Color(0xFF1E3050)),
                          ...section.steps.asMap().entries.map((e) {
                            final stepNum = e.key + 1;
                            final step = e.value;
                            return Container(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                14,
                              ),
                              decoration: BoxDecoration(
                                border:
                                    e.key < section.steps.length - 1
                                        ? const Border(
                                          bottom: BorderSide(
                                            color: Color(0xFF1E3050),
                                          ),
                                        )
                                        : null,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: section.color.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$stepNum',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: section.color,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          step.title,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          step.body,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF94A3B8),
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),

          const SizedBox(height: 8),

          // ── Footer tip ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF162032),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E3050)),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFFF59E0B),
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip: You can tap any section header to expand or collapse it. All guide content is available offline.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                      height: 1.4,
                    ),
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

// ─── Models ───────────────────────────────────────────────────────────────────

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
