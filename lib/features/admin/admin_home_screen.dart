import 'package:flutter/material.dart';
import 'package:starlink_app/features/admin/sections/admin_dashboard_view.dart';
import 'package:starlink_app/core/utils/list_export.dart';
import 'package:starlink_app/core/utils/subscription_export.dart';
import 'package:starlink_app/core/utils/ticket_export.dart';
import 'package:starlink_app/features/admin/tools/announcements_admin_page.dart';
import 'package:starlink_app/features/admin/tools/report_builder_page.dart';
import 'package:starlink_app/features/admin/tools/reports_page.dart';
import 'package:starlink_app/shared/widgets/whats_new_dialog.dart';
import 'package:starlink_app/shared/widgets/notifications.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:starlink_app/shared/widgets/modern_nav.dart';
import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:starlink_app/shared/widgets/logout_confirm_dialog.dart';
import 'package:starlink_app/shared/widgets/app_version_label.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/features/admin/sections/ticket/admin_tickets_page.dart';
import 'package:starlink_app/features/admin/sections/agent/admin_agents_page.dart';
import 'package:starlink_app/features/billing/billing_actions_button.dart';
import 'package:starlink_app/features/admin/sections/billing/admin_billing_page.dart';
import 'package:starlink_app/features/admin/sections/subscription/admin_subscriptions_page.dart';
import 'package:starlink_app/features/admin/sections/enduser/admin_end_users_page.dart';
import 'package:starlink_app/features/admin/profile/admin_edit_profile_page.dart';
import 'package:starlink_app/features/admin/profile/admin_manage_users_page.dart';
import 'package:starlink_app/features/security/security_page.dart';
import 'package:starlink_app/features/user_guide/user_guide_page.dart';
import 'package:starlink_app/features/auth/login_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFF133341);
const _primaryDark = Color(0xFF0C2029);
const _success = Color(0xFF10B981);
const _warning = Color(0xFFF59E0B);
const _danger = Color(0xFFE90408);
const _ink = Color(0xFF111111);
const _inkSecondary = Color(0xFF666666);
const _inkTertiary = Color(0xFF888888);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF8F8F8);
const _border = Color(0xFFD7D7D7);

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

enum QuickActionType { tickets, subscriptions, billing }

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;
  final _ticketExport = ListExportController();
  final _subscriptionExport = ListExportController();
  final _billingActions = BillingListController();
  QuickActionType? _quickAction;
  bool _quickMenuOpen = false;

  OverlayEntry? _overlayEntry;

  bool _loadingDashboard = true;
  String? _dashboardError;
  Map<String, dynamic>? _me;
  int _openCount = 0;
  int _inProgressCount = 0;
  int _resolvedCount = 0;
  int _closedCount = 0;
  List<dynamic> _recentActivity = const [];
  List<dynamic> _expiringSubscriptions = const [];
  List<Map<String, dynamic>> _announcements = const [];

  @override
  void initState() {
    super.initState();
    // "What's new": unseen announcements, once after sign-in.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => WhatsNew.maybeShow(context),
    );
    _loadDashboard();
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  // ── Overlay helpers ───────────────────────────────────────────────────────
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _openQuickMenu() {
    setState(() => _quickMenuOpen = true);
    _overlayEntry = OverlayEntry(
      builder:
          (_) => ModernQuickMenu<QuickActionType>(
            items: const [
              QuickMenuItem(
                value: QuickActionType.tickets,
                icon: Icons.confirmation_number_outlined,
                label: 'Tickets',
                subtitle: 'Create and track support tickets',
                color: _warning,
              ),
              QuickMenuItem(
                value: QuickActionType.subscriptions,
                icon: Icons.subscriptions_outlined,
                label: 'Subscriptions',
                subtitle: 'View your service lines',
                color: Color(0xFF133341),
              ),
              QuickMenuItem(
                value: QuickActionType.billing,
                icon: Icons.receipt_long_outlined,
                label: 'Billing',
                subtitle: 'Invoices and payments',
                color: _success,
              ),
            ],
            active: _quickAction,
            onDismiss: _closeQuickMenu,
            onSelect: _selectQuickAction,
          ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeQuickMenu() {
    _removeOverlay();
    if (mounted) setState(() => _quickMenuOpen = false);
  }

  void _toggleQuickMenu() {
    if (_quickMenuOpen) {
      _closeQuickMenu();
    } else {
      _openQuickMenu();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadDashboard() async {
    setState(() {
      _loadingDashboard = true;
      _dashboardError = null;
    });

    final meRes = await ApiService.getMe();
    if (!mounted) return;

    if (meRes['status'] != 'success') {
      if (meRes['message']?.toString().contains('login') == true ||
          meRes['statusCode'] == 401) {
        // Redirect to login if session is expired
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }
      setState(() {
        _loadingDashboard = false;
        _dashboardError =
            meRes['message']?.toString() ?? 'Failed to load profile';
        _me = null;
      });
      return;
    }

    final meData =
        (meRes['data'] is Map<String, dynamic>)
            ? meRes['data'] as Map<String, dynamic>
            : <String, dynamic>{};

    _loadAnnouncements();

    final results = await Future.wait([
      ApiService.getMyOpenTickets(),
      ApiService.getMyInProgressTickets(),
      ApiService.getMyResolvedTickets(),
      ApiService.getMyClosedTickets(),
      ApiService.getRecentTicketActivity(),
      ApiService.getExpiringSubscriptionsList(),
    ]);

    if (!mounted) return;

    int? tryParseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    int? countFromData(dynamic data) {
      if (data is num) return data.toInt();
      if (data is List) return data.length;
      if (data is Map) {
        for (final k in const [
          'count',
          'total',
          'totalCount',
          'total_count',
          'total_items',
        ]) {
          final parsed = tryParseInt(data[k]);
          if (parsed != null) return parsed;
        }
        for (final k in const [
          'data',
          'items',
          'tickets',
          'rows',
          'results',
          'list',
        ]) {
          final v = data[k];
          if (v is num) return v.toInt();
          if (v is List) return v.length;
        }
        for (final v in data.values) {
          final nested = countFromData(v);
          if (nested != null) return nested;
        }
      }
      return null;
    }

    int countFromResponse(dynamic res) {
      if (res is Map && res['status'] == 'success') {
        final fromData = countFromData(res['data']);
        if (fromData != null) return fromData;
        final fromRaw = countFromData(res['raw']);
        if (fromRaw != null) return fromRaw;
      }
      return 0;
    }

    List<dynamic> listFromResponse(
      dynamic res, {
      List<String> preferredKeys = const [],
    }) {
      if (res is Map && res['status'] == 'success') {
        final candidates = [res['data'], res['raw']];
        for (final c in candidates) {
          if (c is List) return c;
          if (c is Map) {
            for (final k in preferredKeys) {
              final v = c[k];
              if (v is List) return v;
            }
            for (final k in const [
              'data',
              'items',
              'rows',
              'results',
              'list',
            ]) {
              final v = c[k];
              if (v is List) return v;
            }
            for (final v in c.values) {
              if (v is List) return v;
            }
          }
        }
      }
      return const [];
    }

    setState(() {
      _me = meData;
      _openCount = countFromResponse(results[0]);
      _inProgressCount = countFromResponse(results[1]);
      _resolvedCount = countFromResponse(results[2]);
      _closedCount = countFromResponse(results[3]);
      _recentActivity = listFromResponse(
        results[4],
        preferredKeys: const ['activity', 'activities', 'recent', 'events'],
      );
      _expiringSubscriptions = listFromResponse(
        results[5],
        preferredKeys: const ['subscriptions', 'expiring', 'data', 'items'],
      );
      _loadingDashboard = false;
      final anyError = results.whereType<Map>().any(
        (r) => r['status'] != 'success',
      );
      if (anyError) {
        _dashboardError =
            'Some dashboard sections failed to load. Pull to refresh.';
      }
    });
  }

  Future<void> _loadAnnouncements() async {
    final res = await ApiService.getAnnouncementFeed();
    if (!mounted || res['status'] != 'success' || res['data'] is! List) return;
    setState(() {
      _announcements = [
        for (final m in (res['data'] as List).whereType<Map>())
          Map<String, dynamic>.from(m),
      ];
    });
  }

  void _selectQuickAction(QuickActionType type) {
    _closeQuickMenu();
    setState(() {
      _selectedIndex = 2;
      _quickAction = type;
    });
  }

  void _onNavTap(int index) {
    if (index == 2) {
      _toggleQuickMenu();
      return;
    }
    _closeQuickMenu();
    setState(() {
      _selectedIndex = index;
      _quickAction = null;
    });
  }

  List<Widget> _buildBodySlivers() {
    switch (_selectedIndex) {
      case 0:
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                AdminDashboardView(
                  loading: _loadingDashboard,
                  firstName:
                      '${_me?['first_name'] ?? _me?['firstName'] ?? _me?['name'] ?? ''}'
                          .trim()
                          .split(' ')
                          .first,
                  open: _openCount,
                  inProgress: _inProgressCount,
                  resolved: _resolvedCount,
                  closed: _closedCount,
                  announcements: _announcements,
                  recent: [
                    for (final r in _recentActivity.whereType<Map>())
                      Map<String, dynamic>.from(r),
                  ],
                  expiring: [
                    for (final r in _expiringSubscriptions.whereType<Map>())
                      Map<String, dynamic>.from(r),
                  ],
                  onViewTickets:
                      () => _selectQuickAction(QuickActionType.tickets),
                  error: _dashboardError,
                ),
              ]),
            ),
          ),
        ];
      case 1:
        return [
          const SliverFillRemaining(
            hasScrollBody: true,
            child: AdminAgentsPage(),
          ),
        ];
      case 2:
        if (_quickAction == QuickActionType.tickets) {
          return [
            SliverFillRemaining(
              hasScrollBody: true,
              child: AdminTicketsPage(exportController: _ticketExport),
            ),
          ];
        } else if (_quickAction == QuickActionType.subscriptions) {
          return [
            SliverFillRemaining(
              hasScrollBody: true,
              child: AdminSubscriptionsPage(
                exportController: _subscriptionExport,
              ),
            ),
          ];
        } else if (_quickAction == QuickActionType.billing) {
          return [
            SliverFillRemaining(
              hasScrollBody: true,
              child: AdminBillingPage(actionsController: _billingActions),
            ),
          ];
        } else {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.flash_on_outlined,
                        color: _primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Tap the Quick Action button\nto open Tickets, Subscriptions, or Billing.',
                      style: TextStyle(
                        color: _inkSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ];
        }
      case 3:
        return [
          const SliverFillRemaining(
            hasScrollBody: true,
            child: AdminEndUsersPage(),
          ),
        ];
      case 4:
        return [
          SliverFillRemaining(
            hasScrollBody: true,
            child: _SettingsSection(me: _me),
          ),
        ];
      default:
        return const [
          SliverFillRemaining(hasScrollBody: false, child: SizedBox.shrink()),
        ];
    }
  }

  /// Title of the navy app bar for the current tab.
  String? get _appBarTitle {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Customers';
      case 2:
        switch (_quickAction) {
          case QuickActionType.tickets:
            return 'Tickets';
          case QuickActionType.subscriptions:
            return 'Subscriptions';
          case QuickActionType.billing:
            return 'Billing';
          case null:
            return 'Quick Actions';
        }
      case 3:
        return 'End Users';
      case 4:
        return 'Settings';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _surfaceSubtle,
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: _onNavTap,
        quickMenuOpen: _quickMenuOpen,
        quickAction: _quickAction,
      ),
      appBar:
          _appBarTitle != null
              ? AppBar(
                backgroundColor: const Color(0xFF133341),
                surfaceTintColor: const Color(0xFF133341),
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                title: Text(
                  _appBarTitle!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: Container(height: 3, color: const Color(0xFF1E4D62)),
                ),
                actions: [
                  if (_selectedIndex == 2 &&
                      _quickAction == QuickActionType.tickets)
                    ExportTicketsButton(controller: _ticketExport),
                  if (_selectedIndex == 2 &&
                      _quickAction == QuickActionType.subscriptions)
                    ExportSubscriptionsButton(controller: _subscriptionExport),
                  if (_selectedIndex == 2 &&
                      _quickAction == QuickActionType.billing)
                    BillingActionsButton(controller: _billingActions),
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: NotificationBell(),
                  ),
                ],
                // actions: [
                //   IconButton(
                //     icon: const Icon(
                //       Icons.notifications_outlined,
                //       color: _ink,
                //       size: 22,
                //     ),
                //     onPressed:
                //         () => Navigator.push(
                //           context,
                //           MaterialPageRoute(
                //             builder: (_) => const AdminNotificationScreen(),
                //           ),
                //         ),
                //   ),
                // ],
              )
              : null,
      body: SafeArea(
        top: true,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          color: _primary,
          strokeWidth: 2,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (_selectedIndex == 0 && _dashboardError != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _danger.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _danger.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: _danger,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _dashboardError!,
                              style: const TextStyle(
                                color: _danger,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ..._buildBodySlivers(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: _inkTertiary,
      letterSpacing: 1.1,
    ),
  );
}

// ─── Settings Section ─────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final Map<String, dynamic>? me;
  const _SettingsSection({this.me});

  String? _extractString(List<String> keys) {
    if (me == null) return null;
    for (final k in keys) {
      final v = me![k];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return null;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'A';
  }

  @override
  Widget build(BuildContext context) {
    final name =
        _extractString(['name', 'full_name', 'fullName', 'username']) ??
        'Admin';
    final email = _extractString(['email', 'email_address']) ?? '—';
    final role =
        _extractString(['role', 'user_role', 'userRole', 'type']) ??
        'Administrator';
    final avatarUrl = _extractString([
      'avatar',
      'avatar_url',
      'photo',
      'profile_picture',
    ]);
    final initials = _initials(name);

    return Container(
      color: _surfaceSubtle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF133341), Color(0xFF0C2029)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _primaryDark.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2.5,
                    ),
                  ),
                  child:
                      avatarUrl != null && avatarUrl.startsWith('http')
                          ? ClipOval(
                            child: Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) =>
                                      _AvatarInitials(initials: initials),
                            ),
                          )
                          : _AvatarInitials(initials: initials),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            color: Colors.white.withOpacity(0.7),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              email,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          role,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'ACCOUNT'),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.person_outline,
            iconColor: _primaryDark,
            title: 'Edit Profile',
            subtitle: 'Update your admin account information and preferences.',
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminEditProfilePage(),
                  ),
                ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            icon: Icons.security_outlined,
            iconColor: _primary,
            title: 'Security',
            subtitle: 'Change password, two-factor and biometrics.',
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SecurityPage()),
                ),
          ),
          const SizedBox(height: 20),
          // Same tools as the web portal's sidebar (admins and agents).
          const _SectionHeader(title: 'TOOLS'),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.manage_accounts_outlined,
            iconColor: _primary,
            title: 'Users',
            subtitle: 'Create, update, and deactivate platform users.',
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminManageUsersPage(),
                  ),
                ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            icon: Icons.bar_chart_rounded,
            iconColor: _primary,
            title: 'Reports',
            subtitle: 'Current-cycle data usage per service line.',
            onTap:
                () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ReportsPage())),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            icon: Icons.table_chart_outlined,
            iconColor: _primary,
            title: 'Report Builder',
            subtitle: 'Build, run and export custom reports.',
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReportBuilderPage()),
                ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            icon: Icons.campaign_outlined,
            iconColor: _primary,
            title: 'Announcements',
            subtitle: 'Publish news and notices to users.',
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AnnouncementsAdminPage(),
                  ),
                ),
          ),
          const SizedBox(height: 20),
          const _SectionHeader(title: 'HELP'),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.menu_book_outlined,
            iconColor: _success,
            title: 'User Guide',
            subtitle: 'Videos and a step-by-step guide.',
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UserGuidePage()),
                ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (!await confirmLogout(context)) return;
                await ApiService.logout();
                if (context.mounted) {
                  final toast = AppToast.of(context);
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                  toast.showNeutral('Signed out');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryDark,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text(
                'Logout',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const AppVersionLabel(),
        ],
      ),
    );
  }
}

// ─── Avatar Initials ──────────────────────────────────────────────────────────

class _AvatarInitials extends StatelessWidget {
  final String initials;
  const _AvatarInitials({required this.initials});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      initials,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    ),
  );
}

// ─── Settings Card ────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;

  /// Null shows the card dimmed and not tappable.
  final VoidCallback? onTap;

  const _SettingsCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _inkTertiary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Nav Bar ───────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool quickMenuOpen;
  final QuickActionType? quickAction;

  const _BottomNavBar({
    required this.selectedIndex,
    required this.onTap,
    required this.quickMenuOpen,
    required this.quickAction,
  });

  IconData _quickActionIcon() {
    switch (quickAction) {
      case QuickActionType.tickets:
        return Icons.confirmation_number_outlined;
      case QuickActionType.subscriptions:
        return Icons.subscriptions_outlined;
      case QuickActionType.billing:
        return Icons.receipt_long_outlined;
      default:
        return Icons.flash_on_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModernNavBar(
      children: [
        ModernNavItem(
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
          label: 'Dashboard',
          selected: selectedIndex == 0,
          onTap: () => onTap(0),
        ),
        ModernNavItem(
          icon: Icons.group_outlined,
          activeIcon: Icons.group_rounded,
          label: 'Customers',
          selected: selectedIndex == 1,
          onTap: () => onTap(1),
        ),
        ModernCenterButton(
          open: quickMenuOpen,
          onTap: () => onTap(2),
          child:
              quickAction != null
                  ? Icon(_quickActionIcon(), color: Colors.white, size: 24)
                  : SvgPicture.asset(
                    'assets/images/logo.svg',
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
        ),
        ModernNavItem(
          icon: Icons.people_alt_outlined,
          activeIcon: Icons.people_alt_rounded,
          label: 'End Users',
          selected: selectedIndex == 3,
          onTap: () => onTap(3),
        ),
        ModernNavItem(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings_rounded,
          label: 'Settings',
          selected: selectedIndex == 4,
          onTap: () => onTap(4),
        ),
      ],
    );
  }
}
