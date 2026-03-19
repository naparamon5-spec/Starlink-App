import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';

class AdminAgentDetailsPage extends StatefulWidget {
  final String agentId;
  final String agentCode;
  final String agentName;

  const AdminAgentDetailsPage({
    super.key,
    required this.agentId,
    required this.agentCode,
    required this.agentName,
  });

  @override
  State<AdminAgentDetailsPage> createState() => _AdminAgentDetailsPageState();
}

class _AdminAgentDetailsPageState extends State<AdminAgentDetailsPage> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _company;
  List<Map<String, dynamic>> _subscriptions = [];
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait(<Future<Map<String, dynamic>>>[
        ApiService.getCustomerById(widget.agentId),
        ApiService.getSubscriptionsByCustomerId(widget.agentCode),
        ApiService.getUsersByCompanyCode(widget.agentCode),
      ]);

      if (!mounted) return;

      final r0 = results[0];
      final r1 = results[1];
      final r2 = results[2];

      if (r0['status'] != 'success') {
        setState(() {
          _loading = false;
          _error = r0['message']?.toString() ?? 'Failed to load agent details';
        });
        return;
      }

      final cd = r0['data'];
      final company =
          cd is Map ? Map<String, dynamic>.from(cd) : <String, dynamic>{};

      List<Map<String, dynamic>> subs = [];
      if (r1['status'] == 'success') {
        final d = r1['data'];
        final list =
            d is List
                ? d
                : (d is Map && (d)['data'] is List
                    ? (d)['data'] as List
                    : <dynamic>[]);
        subs =
            list
                .whereType<Map>()
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                .toList();
      }

      List<Map<String, dynamic>> users = [];
      if (r2['status'] == 'success') {
        final d = r2['data'];
        final list =
            d is List
                ? d
                : (d is Map && (d)['data'] is List
                    ? (d)['data'] as List
                    : <dynamic>[]);
        users =
            list
                .whereType<Map>()
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                .toList();
      }

      setState(() {
        _company = company;
        _subscriptions = subs;
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  String _str(dynamic v) =>
      (v == null || v.toString() == 'null' || v.toString().trim().isEmpty)
          ? '—'
          : v.toString().trim();

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  // ── Design tokens ─────────────────────────────────────────────────────────
  static const _primary = Color(0xFFEB1E23); // Brand red
  static const _primaryDark = Color(0xFF760F12); // Dark red
  static const _success = Color(0xFF24A148);
  static const _danger = Color(0xFFEB1E23);
  static const _ink = Color(0xFF000000);
  static const _inkSecondary = Color(0xFF6F6F6F);
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceSubtle,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.agentName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _ink,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              widget.agentCode,
              style: const TextStyle(fontSize: 11, color: _inkTertiary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: _loading ? _inkTertiary : _primary,
              size: 20,
            ),
            onPressed: _loading ? null : _loadAll,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body:
          _loading
              ? _buildLoader()
              : _error != null
              ? _buildError()
              : RefreshIndicator(
                onRefresh: _loadAll,
                color: _primary,
                strokeWidth: 2,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  children: [
                    _buildCompanyCard(),
                    const SizedBox(height: 12),
                    _buildSubscriptionsCard(),
                    const SizedBox(height: 12),
                    _buildUsersCard(),
                  ],
                ),
              ),
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
          ),
          SizedBox(height: 14),
          Text(
            'Loading agent details…',
            style: TextStyle(fontSize: 13, color: _inkSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _danger.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: _danger,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _inkSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Company Card ───────────────────────────────────────────────────────────

  Widget _buildCompanyCard() {
    final c = _company ?? {};
    return _SectionCard(
      icon: Icons.business_rounded,
      iconColor: _primary,
      title: 'Company',
      trailing: const _StatusBadge(label: 'Active', color: _success),
      child: Column(
        children: [
          _KVRow(label: 'Code', value: _str(c['code'])),
          const SizedBox(height: 10),
          _KVRow(label: 'Name', value: _str(c['name'])),
        ],
      ),
    );
  }

  // ── Subscriptions Card ─────────────────────────────────────────────────────

  Widget _buildSubscriptionsCard() {
    return _SectionCard(
      icon: Icons.router_rounded,
      iconColor: const Color(0xFF6929C4),
      title: 'Subscriptions',
      trailing: _CountBadge(
        count: _subscriptions.length,
        color: const Color(0xFF6929C4),
      ),
      child:
          _subscriptions.isEmpty
              ? const _EmptyRow(message: 'No subscriptions found')
              : Column(
                children:
                    _subscriptions.asMap().entries.map((entry) {
                      final i = entry.key;
                      final s = entry.value;
                      final nickname = _str(s['nickname']);
                      final sln = _str(
                        s['serviceLineNumber'] ?? s['service_line_number'],
                      );
                      final kit = _str(s['kit_number'] ?? s['kitNumber']);
                      final euName = _str(s['eu_name']);
                      final totalGB = _str(s['totalPriorityGB']);
                      final dataplan = _str(s['dataplan']);
                      final activeRaw = _str(s['active'] ?? s['status']);
                      final isActive =
                          activeRaw.toUpperCase() == 'ACTIVE' ||
                          activeRaw == '1';
                      final dataValue = totalGB != '—' ? totalGB : dataplan;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (i > 0) const _HDivider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nickname,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: _ink,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            sln,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: _inkTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _StatusBadge(
                                      label: isActive ? 'ACTIVE' : 'INACTIVE',
                                      color: isActive ? _success : _primaryDark,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _KVRow(label: 'Kit Number', value: kit),
                                const SizedBox(height: 6),
                                _KVRow(label: 'End User', value: euName),
                                const SizedBox(height: 6),
                                _KVRow(
                                  label: 'Data Usage',
                                  value: '$dataValue GB',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
    );
  }

  // ── Users Card ─────────────────────────────────────────────────────────────

  Widget _buildUsersCard() {
    return _SectionCard(
      icon: Icons.people_outline_rounded,
      iconColor: _success,
      title: 'Users',
      trailing: _CountBadge(count: _users.length, color: _success),
      child:
          _users.isEmpty
              ? const _EmptyRow(message: 'No users found')
              : Column(
                children:
                    _users.asMap().entries.map((entry) {
                      final i = entry.key;
                      final u = entry.value;
                      final firstName = _str(u['first_name']);
                      final lastName = _str(u['last_name']);
                      final rawName = u['name'];
                      final name = _str(
                        rawName ??
                            (firstName != '—' || lastName != '—'
                                ? '$firstName $lastName'.trim()
                                : null),
                      );
                      final email = _str(u['email']);
                      final role = _str(u['role']);
                      final position = _str(u['position']);
                      final inactiveRaw = _str(u['inactive']);
                      final isActive =
                          inactiveRaw == 'N' ||
                          inactiveRaw == '0' ||
                          inactiveRaw.toUpperCase() == 'ACTIVE';
                      final initials = _initials(name == '—' ? 'U' : name);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (i > 0) const _HDivider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: _primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: _primary,
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
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: _ink,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _StatusBadge(
                                            label:
                                                isActive
                                                    ? 'Active'
                                                    : 'Inactive',
                                            color:
                                                isActive
                                                    ? _success
                                                    : _primaryDark,
                                          ),
                                        ],
                                      ),
                                      if (email != '—') ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          email,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: _inkSecondary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (role != '—')
                                            _Chip(
                                              label: role.toUpperCase(),
                                              icon: Icons.shield_outlined,
                                            ),
                                          if (position != '—')
                                            _Chip(
                                              label: position,
                                              icon: Icons.work_outline_rounded,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
    this.trailing,
  });

  static const _ink = Color(0xFF000000);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE0E0E0);
  static const _surfaceSubtle = Color(0xFFF4F4F4);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: iconColor, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Container(height: 1, color: _surfaceSubtle),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _HDivider extends StatelessWidget {
  const _HDivider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: const Color(0xFFF4F4F4));
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _KVRow extends StatelessWidget {
  final String label;
  final String value;
  const _KVRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFA8A8A8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF000000),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Chip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFFA8A8A8)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6F6F6F),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final String message;
  const _EmptyRow({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(fontSize: 13, color: Color(0xFFA8A8A8)),
        ),
      ),
    );
  }
}
