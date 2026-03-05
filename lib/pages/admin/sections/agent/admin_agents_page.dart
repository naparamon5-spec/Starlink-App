import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';
import 'admin_agent_details_page.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFF0F62FE);
const _success = Color(0xFF24A148);
const _danger = Color(0xFFDA1E28);
const _ink = Color(0xFF161616);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);

class AdminAgentsPage extends StatefulWidget {
  const AdminAgentsPage({super.key});

  @override
  State<AdminAgentsPage> createState() => _AdminAgentsPageState();
}

class _AdminAgentsPageState extends State<AdminAgentsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> _agents = [];
  bool _loading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService.getCustomersPaginated(
        page: page,
        limit: 10,
        search: _searchQuery,
      );

      if (!mounted) return;

      final data = res['data'];

      if (data != null) {
        final items = data['data'] as List? ?? [];
        final pagination = data['pagination'];

        setState(() {
          _agents =
              items
                  .whereType<Map>()
                  .map<Map<String, dynamic>>(
                    (c) => _mapCustomerToAgent(Map<String, dynamic>.from(c)),
                  )
                  .toList();
          _currentPage = pagination?['currentPage'] ?? 1;
          _totalPages = pagination?['totalPages'] ?? 1;
          _totalItems = pagination?['totalItems'] ?? 0;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = res['message']?.toString() ?? 'Failed to load agents';
          _agents = [];
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _agents = [];
      });
    }
  }

  Map<String, dynamic> _mapCustomerToAgent(Map<String, dynamic> c) {
    final name = (c['name'] ?? 'Customer').toString();
    final code = (c['code'] ?? '').toString();
    final id = (c['id'] ?? c['customer_id'] ?? '').toString();
    final inactiveRaw = (c['inactive'] ?? '').toString().toUpperCase();
    final status =
        inactiveRaw == 'Y'
            ? 'INACTIVE'
            : inactiveRaw == 'N'
            ? 'ACTIVE'
            : 'UNKNOWN';

    return {
      'id': id,
      'name': name,
      'code': code,
      'status': status,
      'avatar': _initialsFromName(name),
    };
  }

  String _initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'CU';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Color _statusColor(String status) {
    if (status == 'ACTIVE') return _success;
    if (status == 'INACTIVE') return _danger;
    return _inkTertiary;
  }

  void _openAgentDetails(Map<String, dynamic> agent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AdminAgentDetailsPage(
              agentId: agent['id'].toString(),
              agentCode: agent['code'].toString(),
              agentName: agent['name'].toString(),
            ),
      ),
    );
  }

  void _showAddAgentDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Add New Agent',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _ink,
                fontSize: 16,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogField(label: 'Full Name', hint: 'Enter full name'),
                const SizedBox(height: 12),
                _DialogField(label: 'Email', hint: 'Enter email address'),
                const SizedBox(height: 12),
                _DialogField(label: 'Role', hint: 'Enter role'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _inkSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Add Agent',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surfaceSubtle,
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Container(
            color: _surface,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Agents',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _showAddAgentDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Add Agent',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search field
                Container(
                  decoration: BoxDecoration(
                    color: _surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      _searchQuery = val;
                      _loadAgents(page: 1);
                    },
                    style: const TextStyle(fontSize: 13, color: _ink),
                    decoration: const InputDecoration(
                      hintText: 'Search agents...',
                      hintStyle: TextStyle(color: _inkTertiary, fontSize: 13),
                      prefixIcon: Icon(
                        Icons.search,
                        color: _inkTertiary,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Count ─────────────────────────────────────────────────────────
          if (!_loading && _error == null)
            Container(
              color: _surface,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_agents.length} of $_totalItems agents',
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Container(height: 1, color: _border),

          // ── List ─────────────────────────────────────────────────────────
          Expanded(
            child:
                _loading
                    ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              color: _primary,
                              strokeWidth: 2.5,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Loading agents…',
                            style: TextStyle(
                              fontSize: 13,
                              color: _inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                    : _error != null
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: _danger.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.error_outline_rounded,
                                color: _danger,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _inkSecondary,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextButton.icon(
                              onPressed: _loadAgents,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Try again'),
                              style: TextButton.styleFrom(
                                foregroundColor: _primary,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    : _agents.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: _surfaceSubtle,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.group_outlined,
                              color: _inkTertiary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No agents found',
                            style: TextStyle(
                              fontSize: 14,
                              color: _inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _agents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final agent = _agents[index];
                        final statusColor = _statusColor(agent['status']);
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openAgentDetails(agent),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
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
                                  Stack(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: _primary.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            agent['avatar'],
                                            style: const TextStyle(
                                              color: _primary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: _surface,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          agent['name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: _ink,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Code: ${agent['code']}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: _inkSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: statusColor.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Text(
                                      agent['status'],
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: _inkTertiary,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),

          // ── Pagination ────────────────────────────────────────────────────
          if (_totalPages > 1)
            Container(
              color: _surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _PaginationButton(
                    label: 'Previous',
                    enabled: _currentPage > 1,
                    onTap: () => _loadAgents(page: _currentPage - 1),
                  ),
                  Text(
                    'Page $_currentPage of $_totalPages',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _inkSecondary,
                    ),
                  ),
                  _PaginationButton(
                    label: 'Next',
                    enabled: _currentPage < _totalPages,
                    onTap: () => _loadAgents(page: _currentPage + 1),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  final String label;
  final String hint;
  const _DialogField({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _inkSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: _surfaceSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: TextField(
            style: const TextStyle(fontSize: 13, color: _ink),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: _inkTertiary, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _PaginationButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? _primary.withOpacity(0.08) : _surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? _primary.withOpacity(0.25) : _border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: enabled ? _primary : _inkTertiary,
          ),
        ),
      ),
    );
  }
}
