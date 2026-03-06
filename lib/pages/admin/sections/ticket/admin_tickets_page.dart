import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../services/api_service.dart';
import 'admin_ticket_details_page.dart';
import 'admin_create_ticket_page.dart';

class AdminTicketsPage extends StatefulWidget {
  const AdminTicketsPage({super.key});

  @override
  State<AdminTicketsPage> createState() => _AdminTicketsPageState();
}

class _AdminTicketsPageState extends State<AdminTicketsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animController;

  List<Map<String, dynamic>> _tickets = [];
  bool _loading = false;
  bool _searchLoading = false;
  String? _error;

  static const _primary = Color(0xFFEB1E23);
  static const _primaryDark = Color(0xFF760F12);
  static const _inProgress = Color(0xFF0F62FE);
  static const _success = Color(0xFF24A148);
  static const _warning = Color(0xFFFF832B);
  static const _danger = Color(0xFFEB1E23);
  static const _ink = Color(0xFF000000);
  static const _inkSecondary = Color(0xFF6F6F6F);
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadTickets();
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadTickets();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _statusFilter() {
    switch (_tabController.index) {
      case 0:
        return 'open';
      case 1:
        return 'in_progress';
      case 2:
        return 'closed';
      default:
        return 'open';
    }
  }

  Future<void> _loadTickets() async {
    setState(() {
      _loading = _tickets.isEmpty;
      _searchLoading = false;
      _error = null;
    });
    try {
      final response = await ApiService.getTickets(
        status: _statusFilter(),
        search: _searchController.text.isEmpty ? null : _searchController.text,
      );
      if (!mounted) return;
      final List items = response['data'] ?? [];
      setState(() {
        _tickets =
            items
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                .toList();
        _loading = false;
      });
      _animController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('open')) return _warning;
    if (s.contains('progress')) return _inProgress;
    if (s.contains('closed')) return _inkTertiary;
    return _inkTertiary;
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw);
      const m = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  void _openTicket(Map<String, dynamic> t) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AdminTicketDetailsPage(
              ticketId: t['id'].toString(),
              subject: t['subject'] ?? '',
            ),
      ),
    );
  }

  /// Navigates to the full-screen Create Ticket page.
  /// Refreshes the list when it returns `true`.
  Future<void> _openCreateTicket() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdminCreateTicketPage()),
    );
    if (created == true && mounted) _loadTickets();
  }

  int get _openCount =>
      _tickets
          .where((t) => (t['status'] ?? '').toLowerCase().contains('open'))
          .length;

  int get _inProgressCount =>
      _tickets
          .where((t) => (t['status'] ?? '').toLowerCase().contains('progress'))
          .length;

  int get _closedCount =>
      _tickets
          .where((t) => (t['status'] ?? '').toLowerCase().contains('closed'))
          .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateTicket,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Create Ticket',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      body:
          _loading
              ? _buildLoader()
              : _error != null
              ? _buildError()
              : RefreshIndicator(
                onRefresh: _loadTickets,
                color: _primary,
                strokeWidth: 2,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeroBanner()),
                    SliverToBoxAdapter(child: _buildStatChips()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _surfaceSubtle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _border),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) {
                              setState(() => _searchLoading = true);
                              _searchDebounce?.cancel();
                              _searchDebounce = Timer(
                                const Duration(milliseconds: 500),
                                () {
                                  if (mounted) _loadTickets();
                                },
                              );
                            },
                            decoration: InputDecoration(
                              hintText: 'Search tickets...',
                              border: InputBorder.none,
                              prefixIcon: const Icon(
                                Icons.search,
                                color: _inkTertiary,
                              ),
                              suffixIcon:
                                  _searchLoading
                                      ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            color: _primary,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                      : null,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: _primary,
                          unselectedLabelColor: _inkTertiary,
                          indicatorColor: _primary,
                          tabs: const [
                            Tab(text: 'Open'),
                            Tab(text: 'In Progress'),
                            Tab(text: 'Closed'),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: Row(
                          children: [
                            const Text(
                              'Ticket Records',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_tickets.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _primary,
                                ),
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _loadTickets,
                              child: const Icon(
                                Icons.refresh_rounded,
                                size: 18,
                                color: _inkTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_tickets.isEmpty)
                      SliverFillRemaining(child: _buildEmpty())
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return AnimatedBuilder(
                              animation: _animController,
                              builder: (context, child) {
                                final delay = index * 0.07;
                                final t = (_animController.value - delay).clamp(
                                  0.0,
                                  1.0,
                                );
                                return Opacity(
                                  opacity: t,
                                  child: Transform.translate(
                                    offset: Offset(0, 16 * (1 - t)),
                                    child: child,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildTicketCard(_tickets[index]),
                              ),
                            );
                          }, childCount: _tickets.length),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }

  Widget _buildHeroBanner() {
    final total = _tickets.length;
    final closed = _closedCount;
    final progress = total > 0 ? (closed / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEB1E23), Color(0xFF760F12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryDark.withOpacity(0.38),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.confirmation_num_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Tickets Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Total Tickets',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF42BE65),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _HeroChip(
                label: 'Resolved',
                value: '$closed',
                color: const Color(0xFF42BE65),
              ),
              const SizedBox(width: 10),
              _HeroChip(
                label: 'Pending',
                value: '${total - closed}',
                color: const Color(0xFFFFB3B8),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChips() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Row(
      children: [
        _StatPill(
          icon: Icons.inbox_outlined,
          label: 'Open',
          value: '$_openCount',
          color: _warning,
        ),
        const SizedBox(width: 10),
        _StatPill(
          icon: Icons.autorenew_rounded,
          label: 'In Progress',
          value: '$_inProgressCount',
          color: _inProgress,
        ),
        const SizedBox(width: 10),
        _StatPill(
          icon: Icons.check_circle_outline_rounded,
          label: 'Closed',
          value: '$_closedCount',
          color: _success,
        ),
      ],
    ),
  );

  Widget _buildTicketCard(Map<String, dynamic> t) {
    final subject = t['subject'] ?? 'No subject';
    final id = t['id'] ?? '-';
    final status = (t['status'] ?? '').toString();
    final requester = (t['created_by'] ?? '—').toString();
    final createdAt = _formatDate(t['created_at']?.toString());
    final color = _statusColor(status);
    final isClosed = status.toLowerCase().contains('closed');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openTicket(t),
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          subject.isNotEmpty ? subject[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 18,
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
                            children: [
                              Expanded(
                                child: Text(
                                  subject,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: _ink,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _TicketStatusTag(status: status, color: color),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Ticket #$id',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: _inkSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Requester: $requester',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _inkTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: _surfaceSubtle),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: _inkTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          createdAt,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _inkTertiary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 80,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _surfaceSubtle,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor:
                                isClosed
                                    ? 1.0
                                    : (status.toLowerCase().contains('progress')
                                        ? 0.5
                                        : 0.1),
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: _inkTertiary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoader() => const Center(
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
          'Loading tickets…',
          style: TextStyle(fontSize: 13, color: _inkSecondary),
        ),
      ],
    ),
  );

  Widget _buildError() => Center(
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
          TextButton.icon(
            onPressed: _loadTickets,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try again'),
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _surfaceSubtle,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.confirmation_num_outlined,
            color: _inkTertiary,
            size: 26,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'No tickets found',
          style: TextStyle(fontSize: 14, color: _inkSecondary),
        ),
      ],
    ),
  );
}

class _HeroChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _HeroChip({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color.withOpacity(0.8),
          fontWeight: FontWeight.w500,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF6F6F6F),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

class _TicketStatusTag extends StatelessWidget {
  final String status;
  final Color color;
  const _TicketStatusTag({required this.status, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      status.toUpperCase().replaceAll('_', ' '),
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 0.5,
      ),
    ),
  );
}
