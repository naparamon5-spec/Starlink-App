import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';

class AdminEndUserDetailsPage extends StatefulWidget {
  final String endUserId;
  final String endUserCode;
  final String endUserName;

  const AdminEndUserDetailsPage({
    super.key,
    required this.endUserId,
    required this.endUserCode,
    required this.endUserName,
  });

  @override
  State<AdminEndUserDetailsPage> createState() =>
      _AdminEndUserDetailsPageState();
}

class _AdminEndUserDetailsPageState extends State<AdminEndUserDetailsPage> {
  bool _loading = true;
  String? _error;
  bool _isTogglingStatus = false;

  Map<String, dynamic>? _endUser;
  List<Map<String, dynamic>> _subscriptions = [];
  List<Map<String, dynamic>> _users = [];

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const _primary = Color(0xFFEB1E23); // Brand red
  static const _primaryDark = Color(0xFF760F12); // Dark red
  static const _success = Color(0xFF24A148);
  static const _danger = Color(0xFFEB1E23);
  static const _purple = Color(0xFF7C3AED);
  static const _ink = Color(0xFF000000);
  static const _inkSecondary = Color(0xFF6F6F6F);
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

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
      final euCode = widget.endUserId;
      final results = await Future.wait([
        ApiService.getEndUserById(euCode),
        ApiService.getSubscriptionsByEndUserId(euCode),
        ApiService.getUsersByCompanyCode(euCode),
      ]);

      if (!mounted) return;

      if (results[0]['status'] != 'success') {
        setState(() {
          _loading = false;
          _error = results[0]['message']?.toString() ?? 'Failed to load';
        });
        return;
      }

      final rawEu = results[0]['data'];
      final endUser =
          rawEu is Map ? Map<String, dynamic>.from(rawEu) : <String, dynamic>{};

      List<Map<String, dynamic>> subs = [];
      if (results[1]['status'] == 'success') {
        final rawSubs = results[1]['data'];
        List<dynamic> list = [];
        if (rawSubs is List) {
          list = rawSubs;
        } else if (rawSubs is Map) {
          final inner = rawSubs['data'];
          if (inner is List) list = inner;
        }
        subs =
            list
                .whereType<Map>()
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                .toList();
      }

      List<Map<String, dynamic>> users = [];
      if (results[2]['status'] == 'success') {
        final rawUsers = results[2]['data'];
        List<dynamic> list = [];
        if (rawUsers is List) {
          list = rawUsers;
        } else if (rawUsers is Map) {
          final inner = rawUsers['data'];
          if (inner is List) list = inner;
        }
        users =
            list
                .whereType<Map>()
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                .toList();
      }

      setState(() {
        _endUser = endUser;
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

  void _toggleStatus(bool newActiveValue) {
    setState(() {
      _isTogglingStatus = false;
      _endUser = Map<String, dynamic>.from(_endUser ?? {})
        ..['inactive'] = newActiveValue ? 'N' : 'Y';
    });
  }

  String _str(dynamic v) =>
      (v == null || v.toString() == 'null' || v.toString().trim().isEmpty)
          ? '—'
          : v.toString().trim();

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
        title: const Text(
          'End User Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _ink,
            letterSpacing: -0.3,
          ),
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
                    _buildEndUserCard(),
                    const SizedBox(height: 12),
                    _buildSubscriptionsSection(),
                    const SizedBox(height: 12),
                    _buildUsersSection(),
                  ],
                ),
              ),
    );
  }

  Widget _buildEndUserCard() {
    final e = _endUser ?? {};
    final name = _str(e['eu_name'] ?? e['name']);
    final code = _str(e['eu_code'] ?? e['code'] ?? e['customer_code']);
    final inactiveRaw = _str(e['inactive'] ?? e['status']);
    final isActive =
        inactiveRaw == 'N' ||
        inactiveRaw == '0' ||
        inactiveRaw.toUpperCase() == 'ACTIVE';

    return _WhiteCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LabelValue(label: 'Name', value: name),
                  const SizedBox(height: 8),
                  _LabelValue(label: 'Code', value: code),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(width: 6),
                Transform.scale(
                  scale: 0.55,
                  child: Switch(
                    value: isActive,
                    onChanged: _isTogglingStatus ? null : _toggleStatus,
                    activeThumbColor: _primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Row(
            children: [
              const Text(
                'Subscription',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              _CountPill(count: _subscriptions.length, color: _purple),
            ],
          ),
        ),
        if (_subscriptions.isEmpty)
          _WhiteCard(
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No subscriptions found.',
                  style: TextStyle(fontSize: 13, color: _inkTertiary),
                ),
              ),
            ),
          )
        else
          ...List.generate(_subscriptions.length, (i) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: i < _subscriptions.length - 1 ? 10 : 0,
              ),
              child: _buildSubscriptionCard(_subscriptions[i]),
            );
          }),
      ],
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> s) {
    final nickname = _str(s['nickname'] ?? s['site_name']);
    final sln = _str(s['serviceLineNumber'] ?? s['service_line_number']);
    final totalGB = _str(s['totalPriorityGB']);
    final kit = _str(s['kit_number'] ?? s['kitNumber']);
    final activeRaw = _str(s['active'] ?? s['status']);
    final isActive = activeRaw.toUpperCase() == 'ACTIVE' || activeRaw == '1';
    final dataGB = double.tryParse(totalGB == '—' ? '0' : totalGB) ?? 0;

    return _WhiteCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    nickname,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _StatusBadge(
                  label: isActive ? 'ACTIVE' : 'INACTIVE',
                  color: isActive ? _success : _primaryDark,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              sln,
              style: const TextStyle(
                fontSize: 11,
                color: _inkTertiary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: _surfaceSubtle),
            const SizedBox(height: 12),
            _LabelValue(
              label: 'Data Usage',
              value: '$totalGB GB',
              valueColor: dataGB > 0 ? _primary : _inkSecondary,
            ),
            const SizedBox(height: 8),
            _LabelValue(label: 'Kit Number', value: kit),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Row(
            children: [
              const Text(
                'Users',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              _CountPill(count: _users.length, color: _success),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  // TODO: navigate to add user
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _ink,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Add User',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_users.isEmpty)
          _WhiteCard(
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No Users found.',
                  style: TextStyle(fontSize: 13, color: _inkTertiary),
                ),
              ),
            ),
          )
        else
          _WhiteCard(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _users.length,
              separatorBuilder:
                  (_, __) => Container(height: 1, color: _surfaceSubtle),
              itemBuilder: (_, i) => _buildUserRow(_users[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildUserRow(Map<String, dynamic> u) {
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

    final parts = name.trim().split(RegExp(r'\s+'));
    final initials =
        name == '—'
            ? 'U'
            : parts.length == 1
            ? parts.first[0].toUpperCase()
            : '${parts.first[0]}${parts.last[0]}'.toUpperCase();

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              shape: BoxShape.circle,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(
                      label: isActive ? 'Active' : 'Inactive',
                      color: isActive ? _success : _primaryDark,
                    ),
                  ],
                ),
                if (email != '—') ...[
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: const TextStyle(fontSize: 11, color: _inkSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (role != '—' || position != '—') ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (role != '—')
                        _TagChip(
                          label: role.toUpperCase(),
                          icon: Icons.shield_outlined,
                          color: _primary,
                        ),
                      if (position != '—')
                        _TagChip(
                          label: position,
                          icon: Icons.work_outline_rounded,
                          color: _inkSecondary,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
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
            'Loading end user details…',
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _WhiteCard extends StatelessWidget {
  final Widget child;
  const _WhiteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _LabelValue({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xFF000000),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
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

class _CountPill extends StatelessWidget {
  final int count;
  final Color color;
  const _CountPill({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _TagChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
