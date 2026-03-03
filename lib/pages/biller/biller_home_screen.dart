import 'package:flutter/material.dart';
import 'sections/billing/biller_billing_page.dart';
import 'dart:math' as math;

void main() {
  runApp(const BillerApp());
}

class BillerApp extends StatelessWidget {
  const BillerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biller Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D4AA),
          surface: Color(0xFF161B22),
        ),
      ),
      home: const BillerHomeScreen(),
    );
  }
}

// ─── Biller Home ──────────────────────────────────────────────────────────────

class BillerHomeScreen extends StatefulWidget {
  const BillerHomeScreen({super.key});

  @override
  State<BillerHomeScreen> createState() => _BillerHomeScreenState();
}

class _BillerHomeScreenState extends State<BillerHomeScreen> {
  int _selectedTab = 0;

  final List<_TabDef> _tabs = const [
    _TabDef(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    _TabDef(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      label: 'Billing',
    ),
    _TabDef(
      icon: Icons.support_agent_outlined,
      activeIcon: Icons.support_agent,
      label: 'Agents',
    ),
    _TabDef(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'End Users',
    ),
  ];

  Widget _buildBody() {
    switch (_selectedTab) {
      case 0:
        return const _BillerDashboardTab();
      case 1:
        return const BillingTab();
      case 2:
        return const _AgentsTab();
      case 3:
        return const _EndUsersTab();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Column(
        children: [const _BillerAppBar(), Expanded(child: _buildBody())],
      ),
      bottomNavigationBar: _BillerBottomNav(
        tabs: _tabs,
        selectedIndex: _selectedTab,
        onTap: (i) => setState(() => _selectedTab = i),
      ),
    );
  }
}

// ─── App Bar ─────────────────────────────────────────────────────────────────

class _BillerAppBar extends StatelessWidget {
  const _BillerAppBar();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 12, 20, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        border: Border(bottom: BorderSide(color: Color(0xFF21262D), width: 1)),
      ),
      child: Row(
        children: [
          // Biller badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4AA).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF00D4AA).withOpacity(0.35),
              ),
            ),
            child: const Text(
              'BILLER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF00D4AA),
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
                ),
                Text(
                  'Sarah Collins',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00D4AA), Color(0xFF0099FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: const Color(0xFF21262D), width: 2),
            ),
            child: const Center(
              child: Text(
                'SC',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard Tab ────────────────────────────────────────────────────────────

class _BillerDashboardTab extends StatelessWidget {
  const _BillerDashboardTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        _RevenueHeroCard(),
        const SizedBox(height: 20),
        _QuickStatRow(),
        const SizedBox(height: 20),
        _SectionHeader(title: 'PENDING ACTIONS', action: 'See All'),
        const SizedBox(height: 12),
        _PendingActionCard(
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFFFA500),
          title: '3 Invoices Overdue',
          subtitle: 'Total outstanding: \$4,320.00',
          tag: 'URGENT',
          tagColor: const Color(0xFFFFA500),
        ),
        const SizedBox(height: 10),
        _PendingActionCard(
          icon: Icons.sync_outlined,
          iconColor: const Color(0xFF0099FF),
          title: '7 Subscriptions Renewing',
          subtitle: 'Next 7 days · Auto-billing enabled',
          tag: 'UPCOMING',
          tagColor: const Color(0xFF0099FF),
        ),
        const SizedBox(height: 10),
        _PendingActionCard(
          icon: Icons.check_circle_outline,
          iconColor: const Color(0xFF00D4AA),
          title: '12 Payments Received',
          subtitle: 'Today · \$8,750.00 total',
          tag: 'TODAY',
          tagColor: const Color(0xFF00D4AA),
        ),
        const SizedBox(height: 20),
        _SectionHeader(title: 'RECENT TRANSACTIONS', action: 'View All'),
        const SizedBox(height: 12),
        ..._recentTxns.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TransactionTile(data: t),
          ),
        ),
      ],
    );
  }
}

const _recentTxns = [
  _TxnData(
    name: 'Acme Corp',
    amount: '+\$1,200.00',
    date: 'Today, 09:41 AM',
    status: 'Paid',
    statusColor: Color(0xFF00D4AA),
    isCredit: true,
  ),
  _TxnData(
    name: 'BlueSky Ltd.',
    amount: '-\$340.00',
    date: 'Today, 08:15 AM',
    status: 'Refund',
    statusColor: Color(0xFFF43F5E),
    isCredit: false,
  ),
  _TxnData(
    name: 'NovaTech Inc.',
    amount: '+\$5,800.00',
    date: 'Yesterday, 5:30 PM',
    status: 'Paid',
    statusColor: Color(0xFF00D4AA),
    isCredit: true,
  ),
];

class _TxnData {
  final String name;
  final String amount;
  final String date;
  final String status;
  final Color statusColor;
  final bool isCredit;
  const _TxnData({
    required this.name,
    required this.amount,
    required this.date,
    required this.status,
    required this.statusColor,
    required this.isCredit,
  });
}

class _TransactionTile extends StatelessWidget {
  final _TxnData data;
  const _TransactionTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  data.isCredit
                      ? const Color(0xFF00D4AA).withOpacity(0.1)
                      : const Color(0xFFF43F5E).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              data.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color:
                  data.isCredit
                      ? const Color(0xFF00D4AA)
                      : const Color(0xFFF43F5E),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.date,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8B949E),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data.amount,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color:
                      data.isCredit
                          ? const Color(0xFF00D4AA)
                          : const Color(0xFFF43F5E),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: data.statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.status,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: data.statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueHeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF003D2E), Color(0xFF001A2C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF00D4AA).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D4AA).withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Color(0xFF00D4AA),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Total Revenue · This Month',
                style: TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4AA).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.trending_up, color: Color(0xFF00D4AA), size: 12),
                    SizedBox(width: 4),
                    Text(
                      '+18.4%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00D4AA),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '\$142,830.00',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'vs \$120,644.00 last month',
            style: TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
          ),
          const SizedBox(height: 18),
          // Mini sparkline bar chart
          _SparklineBar(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Jan',
                style: TextStyle(fontSize: 9, color: Color(0xFF8B949E)),
              ),
              Text(
                'Feb',
                style: TextStyle(fontSize: 9, color: Color(0xFF8B949E)),
              ),
              Text(
                'Mar',
                style: TextStyle(fontSize: 9, color: Color(0xFF8B949E)),
              ),
              Text(
                'Apr',
                style: TextStyle(fontSize: 9, color: Color(0xFF8B949E)),
              ),
              Text(
                'May',
                style: TextStyle(fontSize: 9, color: Color(0xFF8B949E)),
              ),
              Text(
                'Jun',
                style: TextStyle(fontSize: 9, color: Color(0xFF8B949E)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SparklineBar extends StatelessWidget {
  final List<double> _values = const [0.45, 0.62, 0.55, 0.78, 0.70, 1.0];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children:
            _values.asMap().entries.map((e) {
              final isLast = e.key == _values.length - 1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    height: 36 * e.value,
                    decoration: BoxDecoration(
                      color:
                          isLast
                              ? const Color(0xFF00D4AA)
                              : const Color(0xFF00D4AA).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _QuickStatRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatMini(
        label: 'Invoices',
        value: '38',
        color: const Color(0xFF0099FF),
        icon: Icons.description_outlined,
      ),
      _StatMini(
        label: 'Paid',
        value: '24',
        color: const Color(0xFF00D4AA),
        icon: Icons.check_circle_outline,
      ),
      _StatMini(
        label: 'Overdue',
        value: '3',
        color: const Color(0xFFFF6B35),
        icon: Icons.timer_off_outlined,
      ),
      _StatMini(
        label: 'Drafted',
        value: '11',
        color: const Color(0xFF8B949E),
        icon: Icons.drafts_outlined,
      ),
    ];
    return Row(
      children:
          stats.map((s) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  left: stats.indexOf(s) == 0 ? 0 : 6,
                  right: stats.indexOf(s) == stats.length - 1 ? 0 : 6,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF21262D)),
                ),
                child: Column(
                  children: [
                    Icon(s.icon, color: s.color, size: 18),
                    const SizedBox(height: 6),
                    Text(
                      s.value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: s.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.label,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF8B949E),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }
}

class _StatMini {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatMini({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8B949E),
            letterSpacing: 1.2,
          ),
        ),
        if (action != null)
          Text(
            action!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF00D4AA),
            ),
          ),
      ],
    );
  }
}

class _PendingActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String tag;
  final Color tagColor;

  const _PendingActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.tagColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8B949E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: tagColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tagColor.withOpacity(0.3)),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: tagColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF484F58),
                size: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Billing Tab ──────────────────────────────────────────────────────────────

// class _BillingTab extends StatefulWidget {
//   const _BillingTab();

//   @override
//   State<_BillingTab> createState() => _BillingTabState();
// }

// class _BillingTabState extends State<_BillingTab> {
//   int _filterIndex = 0;
//   final _filters = ['All', 'Paid', 'Pending', 'Overdue', 'Draft'];

//   final _invoices = const [
//     _InvoiceData(
//       id: 'INV-0041',
//       client: 'Acme Corp',
//       amount: '\$1,200.00',
//       date: 'Mar 01, 2026',
//       status: 'Paid',
//       statusColor: Color(0xFF00D4AA),
//     ),
//     _InvoiceData(
//       id: 'INV-0040',
//       client: 'BlueSky Ltd.',
//       amount: '\$340.00',
//       date: 'Feb 28, 2026',
//       status: 'Overdue',
//       statusColor: Color(0xFFFF6B35),
//     ),
//     _InvoiceData(
//       id: 'INV-0039',
//       client: 'NovaTech Inc.',
//       amount: '\$5,800.00',
//       date: 'Feb 26, 2026',
//       status: 'Paid',
//       statusColor: Color(0xFF00D4AA),
//     ),
//     _InvoiceData(
//       id: 'INV-0038',
//       client: 'PixelWave Co.',
//       amount: '\$920.00',
//       date: 'Feb 25, 2026',
//       status: 'Pending',
//       statusColor: Color(0xFFFFA500),
//     ),
//     _InvoiceData(
//       id: 'INV-0037',
//       client: 'DataStream AI',
//       amount: '\$2,450.00',
//       date: 'Feb 22, 2026',
//       status: 'Paid',
//       statusColor: Color(0xFF00D4AA),
//     ),
//     _InvoiceData(
//       id: 'INV-0036',
//       client: 'CloudSync GmbH',
//       amount: '\$670.00',
//       date: 'Feb 20, 2026',
//       status: 'Draft',
//       statusColor: Color(0xFF8B949E),
//     ),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         // Filter chips
//         Container(
//           padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
//           color: const Color(0xFF0D1117),
//           child: SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: Row(
//               children:
//                   _filters.asMap().entries.map((e) {
//                     final selected = e.key == _filterIndex;
//                     return GestureDetector(
//                       onTap: () => setState(() => _filterIndex = e.key),
//                       child: Container(
//                         margin: const EdgeInsets.only(right: 8),
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 14,
//                           vertical: 7,
//                         ),
//                         decoration: BoxDecoration(
//                           color:
//                               selected
//                                   ? const Color(0xFF00D4AA)
//                                   : const Color(0xFF161B22),
//                           borderRadius: BorderRadius.circular(20),
//                           border: Border.all(
//                             color:
//                                 selected
//                                     ? const Color(0xFF00D4AA)
//                                     : const Color(0xFF21262D),
//                           ),
//                         ),
//                         child: Text(
//                           e.value,
//                           style: TextStyle(
//                             fontSize: 12,
//                             fontWeight: FontWeight.w600,
//                             color:
//                                 selected
//                                     ? Colors.black
//                                     : const Color(0xFF8B949E),
//                           ),
//                         ),
//                       ),
//                     );
//                   }).toList(),
//             ),
//           ),
//         ),
//         // Summary row
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//           child: Row(
//             children: [
//               Text(
//                 '${_invoices.length} invoices',
//                 style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
//               ),
//               const Spacer(),
//               GestureDetector(
//                 onTap: () {},
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 12,
//                     vertical: 6,
//                   ),
//                   decoration: BoxDecoration(
//                     color: const Color(0xFF00D4AA).withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(10),
//                     border: Border.all(
//                       color: const Color(0xFF00D4AA).withOpacity(0.3),
//                     ),
//                   ),
//                   child: Row(
//                     children: const [
//                       Icon(Icons.add, color: Color(0xFF00D4AA), size: 14),
//                       SizedBox(width: 4),
//                       Text(
//                         'New Invoice',
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontWeight: FontWeight.w600,
//                           color: Color(0xFF00D4AA),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 8),
//         Expanded(
//           child: ListView.separated(
//             padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
//             itemCount: _invoices.length,
//             separatorBuilder: (_, __) => const SizedBox(height: 10),
//             itemBuilder: (_, i) => _InvoiceCard(data: _invoices[i]),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _InvoiceData {
//   final String id, client, amount, date, status;
//   final Color statusColor;
//   const _InvoiceData({
//     required this.id,
//     required this.client,
//     required this.amount,
//     required this.date,
//     required this.status,
//     required this.statusColor,
//   });
// }

// class _InvoiceCard extends StatelessWidget {
//   final _InvoiceData data;
//   const _InvoiceCard({required this.data});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: const Color(0xFF161B22),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFF21262D)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 42,
//             height: 42,
//             decoration: BoxDecoration(
//               color: const Color(0xFF00D4AA).withOpacity(0.08),
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: const Icon(
//               Icons.description_outlined,
//               color: Color(0xFF00D4AA),
//               size: 20,
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   data.client,
//                   style: const TextStyle(
//                     fontSize: 13,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//                 const SizedBox(height: 3),
//                 Row(
//                   children: [
//                     Text(
//                       data.id,
//                       style: const TextStyle(
//                         fontSize: 11,
//                         color: Color(0xFF8B949E),
//                       ),
//                     ),
//                     const Text(
//                       ' · ',
//                       style: TextStyle(color: Color(0xFF484F58)),
//                     ),
//                     Text(
//                       data.date,
//                       style: const TextStyle(
//                         fontSize: 11,
//                         color: Color(0xFF8B949E),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               Text(
//                 data.amount,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//                 decoration: BoxDecoration(
//                   color: data.statusColor.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//                 child: Text(
//                   data.status,
//                   style: TextStyle(
//                     fontSize: 9,
//                     fontWeight: FontWeight.w700,
//                     color: data.statusColor,
//                     letterSpacing: 0.4,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// ─── Agents Tab ───────────────────────────────────────────────────────────────

class _AgentsTab extends StatelessWidget {
  const _AgentsTab();

  static const _agents = [
    _AgentData(
      name: 'James Rivera',
      role: 'Billing Specialist',
      initials: 'JR',
      gradientA: Color(0xFF0099FF),
      gradientB: Color(0xFF00D4AA),
      tickets: 14,
      resolved: 11,
      status: 'Online',
      statusColor: Color(0xFF00D4AA),
    ),
    _AgentData(
      name: 'Maya Torres',
      role: 'Account Manager',
      initials: 'MT',
      gradientA: Color(0xFF9B5DE5),
      gradientB: Color(0xFFF15BB5),
      tickets: 8,
      resolved: 7,
      status: 'Online',
      statusColor: Color(0xFF00D4AA),
    ),
    _AgentData(
      name: 'Ethan Brooks',
      role: 'Finance Analyst',
      initials: 'EB',
      gradientA: Color(0xFFFFA500),
      gradientB: Color(0xFFFF6B35),
      tickets: 20,
      resolved: 18,
      status: 'Busy',
      statusColor: Color(0xFFFFA500),
    ),
    _AgentData(
      name: 'Priya Nair',
      role: 'Collections Agent',
      initials: 'PN',
      gradientA: Color(0xFF43B89C),
      gradientB: Color(0xFF0099FF),
      tickets: 6,
      resolved: 6,
      status: 'Away',
      statusColor: Color(0xFF8B949E),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF21262D)),
          ),
          child: Row(
            children: const [
              Icon(Icons.search, color: Color(0xFF8B949E), size: 18),
              SizedBox(width: 10),
              Text(
                'Search agents...',
                style: TextStyle(color: Color(0xFF484F58), fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Stats row
        _AgentStatsBar(totalAgents: _agents.length),
        const SizedBox(height: 16),
        ..._agents.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AgentCard(data: a),
          ),
        ),
      ],
    );
  }
}

class _AgentData {
  final String name, role, initials, status;
  final Color gradientA, gradientB, statusColor;
  final int tickets, resolved;
  const _AgentData({
    required this.name,
    required this.role,
    required this.initials,
    required this.gradientA,
    required this.gradientB,
    required this.tickets,
    required this.resolved,
    required this.status,
    required this.statusColor,
  });
}

class _AgentStatsBar extends StatelessWidget {
  final int totalAgents;
  const _AgentStatsBar({required this.totalAgents});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _AgentStat(
            value: '$totalAgents',
            label: 'Total',
            color: const Color(0xFF00D4AA),
          ),
          _Divider(),
          _AgentStat(
            value: '2',
            label: 'Online',
            color: const Color(0xFF00D4AA),
          ),
          _Divider(),
          _AgentStat(value: '1', label: 'Busy', color: const Color(0xFFFFA500)),
          _Divider(),
          _AgentStat(value: '1', label: 'Away', color: const Color(0xFF8B949E)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: const Color(0xFF21262D));
}

class _AgentStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _AgentStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF8B949E)),
        ),
      ],
    );
  }
}

class _AgentCard extends StatelessWidget {
  final _AgentData data;
  const _AgentCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final pct = data.tickets > 0 ? data.resolved / data.tickets : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [data.gradientA, data.gradientB],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    data.initials,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 1,
                bottom: 1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: data.statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF161B22),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      data.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: data.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        data.status,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: data.statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  data.role,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8B949E),
                  ),
                ),
                const SizedBox(height: 8),
                // Resolution progress
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          children: [
                            Container(
                              height: 4,
                              color: const Color(0xFF00D4AA).withOpacity(0.15),
                            ),
                            FractionallySizedBox(
                              widthFactor: pct,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [data.gradientA, data.gradientB],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${data.resolved}/${data.tickets} resolved',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF8B949E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Color(0xFF484F58), size: 20),
        ],
      ),
    );
  }
}

// ─── End Users Tab ────────────────────────────────────────────────────────────

class _EndUsersTab extends StatefulWidget {
  const _EndUsersTab();

  @override
  State<_EndUsersTab> createState() => _EndUsersTabState();
}

class _EndUsersTabState extends State<_EndUsersTab> {
  int _sortIndex = 0;
  final _sorts = ['All', 'Active', 'Inactive', 'High Value'];

  static const _users = [
    _EndUserData(
      name: 'Lena Hartmann',
      company: 'Acme Corp',
      plan: 'Enterprise',
      totalSpent: '\$24,600',
      status: 'Active',
      lastActivity: '2 hours ago',
      initials: 'LH',
    ),
    _EndUserData(
      name: 'Carlos Mendes',
      company: 'BlueSky Ltd.',
      plan: 'Pro',
      totalSpent: '\$3,420',
      status: 'Active',
      lastActivity: 'Yesterday',
      initials: 'CM',
    ),
    _EndUserData(
      name: 'Aisha Patel',
      company: 'NovaTech Inc.',
      plan: 'Enterprise',
      totalSpent: '\$18,200',
      status: 'Active',
      lastActivity: '3 days ago',
      initials: 'AP',
    ),
    _EndUserData(
      name: 'Tom Nguyen',
      company: 'PixelWave Co.',
      plan: 'Starter',
      totalSpent: '\$640',
      status: 'Inactive',
      lastActivity: '2 weeks ago',
      initials: 'TN',
    ),
    _EndUserData(
      name: 'Sofia Rossi',
      company: 'DataStream AI',
      plan: 'Pro',
      totalSpent: '\$5,100',
      status: 'Active',
      lastActivity: '1 day ago',
      initials: 'SR',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sort filter
        Container(
          color: const Color(0xFF0D1117),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        _sorts.asMap().entries.map((e) {
                          final sel = e.key == _sortIndex;
                          return GestureDetector(
                            onTap: () => setState(() => _sortIndex = e.key),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    sel
                                        ? const Color(0xFF00D4AA)
                                        : const Color(0xFF161B22),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      sel
                                          ? const Color(0xFF00D4AA)
                                          : const Color(0xFF21262D),
                                ),
                              ),
                              child: Text(
                                e.value,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      sel
                                          ? Colors.black
                                          : const Color(0xFF8B949E),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF21262D)),
                ),
                child: const Icon(
                  Icons.tune,
                  color: Color(0xFF8B949E),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
        // Total summary
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: _UserSummaryCard(total: _users.length),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: _users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _EndUserCard(data: _users[i]),
          ),
        ),
      ],
    );
  }
}

class _UserSummaryCard extends StatelessWidget {
  final int total;
  const _UserSummaryCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people_outline,
                color: Color(0xFF00D4AA),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '$total End Users',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const Text(
            'Total LTV: \$51,960',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF00D4AA),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndUserData {
  final String name, company, plan, totalSpent, status, lastActivity, initials;
  const _EndUserData({
    required this.name,
    required this.company,
    required this.plan,
    required this.totalSpent,
    required this.status,
    required this.lastActivity,
    required this.initials,
  });
}

class _EndUserCard extends StatelessWidget {
  final _EndUserData data;
  const _EndUserCard({required this.data});

  Color get _planColor {
    switch (data.plan) {
      case 'Enterprise':
        return const Color(0xFF9B5DE5);
      case 'Pro':
        return const Color(0xFF0099FF);
      default:
        return const Color(0xFF8B949E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = data.status == 'Active';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Initials avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _planColor.withOpacity(0.12),
                  border: Border.all(color: _planColor.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    data.initials,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _planColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.company,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8B949E),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _planColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      data.plan,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _planColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (isActive
                              ? const Color(0xFF00D4AA)
                              : const Color(0xFF8B949E))
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      data.status,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color:
                            isActive
                                ? const Color(0xFF00D4AA)
                                : const Color(0xFF8B949E),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: const Color(0xFF21262D)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _UserMetric(
                icon: Icons.attach_money,
                label: 'Total Spent',
                value: data.totalSpent,
                valueColor: const Color(0xFF00D4AA),
              ),
              _UserMetric(
                icon: Icons.access_time,
                label: 'Last Active',
                value: data.lastActivity,
                valueColor: Colors.white,
              ),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4AA).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF00D4AA).withOpacity(0.25),
                    ),
                  ),
                  child: const Text(
                    'View',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00D4AA),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserMetric extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color valueColor;
  const _UserMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: const Color(0xFF8B949E)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: Color(0xFF8B949E)),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Bottom Nav ───────────────────────────────────────────────────────────────

class _TabDef {
  final IconData icon, activeIcon;
  final String label;
  const _TabDef({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _BillerBottomNav extends StatelessWidget {
  final List<_TabDef> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BillerBottomNav({
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        border: Border(top: BorderSide(color: Color(0xFF21262D), width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottom + 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children:
            tabs.asMap().entries.map((e) {
              final sel = e.key == selectedIndex;
              return GestureDetector(
                onTap: () => onTap(e.key),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        sel
                            ? const Color(0xFF00D4AA).withOpacity(0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        sel ? e.value.activeIcon : e.value.icon,
                        size: 22,
                        color:
                            sel
                                ? const Color(0xFF00D4AA)
                                : const Color(0xFF8B949E),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        e.value.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color:
                              sel
                                  ? const Color(0xFF00D4AA)
                                  : const Color(0xFF8B949E),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}
