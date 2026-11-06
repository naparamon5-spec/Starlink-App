import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/core/utils/sheet_export.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';

/// Usage reports (admins, agents) — the web portal's Reports page:
/// current-cycle usage per service line (GET /usage/summary), filtered by how
/// much of the limit is used, with each line's daily usage
/// (GET /usage/daily) and an Excel export.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

// Each range covers its value up to just below the next one; the last is
// the limit reached or passed. 0 is every line.
const _thresholds = [0, 10, 25, 50, 75, 90, 100];

const _series = [
  ('Priority', 'priorityGB', AppColors.brand),
  ('Opt-in priority', 'optInPriorityGB', AppColors.salmon),
  ('Standard', 'standardGB', Color(0xFF3E7A93)),
  ('Non-billable', 'nonBillableGB', AppColors.lineStrong),
];

double _num(dynamic v) => double.tryParse('${v ?? ''}') ?? 0;

String _gb(double v) =>
    '${v.toStringAsFixed(v >= 100 ? 0 : (v >= 10 ? 1 : 2))} GB';

class _ReportsPageState extends State<ReportsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _summary = [];
  List<Map<String, dynamic>> _daily = [];
  int _threshold = 0;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> res) {
    final d = res['data'];
    return d is List
        ? d.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : [];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait([
      ApiService.getUsageSummary(),
      ApiService.getUsageDaily(),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (results[0]['status'] != 'success') {
        _error = results[0]['message']?.toString() ?? 'Could not load usage';
      } else {
        _summary = _list(results[0]);
        _daily = _list(results[1]);
      }
    });
  }

  double _exactPct(Map<String, dynamic> r) {
    final limit = _num(r['usageLimitGB']);
    return limit > 0 ? _num(r['consumedAmountGB']) / limit * 100 : 0;
  }

  bool _inRange(Map<String, dynamic> r) {
    if (_threshold == 0) return true;
    final p = _exactPct(r);
    final i = _thresholds.indexOf(_threshold);
    final next = i + 1 < _thresholds.length ? _thresholds[i + 1] : null;
    return p >= _threshold && (next == null || p < next);
  }

  String _rangeLabel(int t) {
    if (t == 0) return 'All';
    final i = _thresholds.indexOf(t);
    if (i + 1 >= _thresholds.length) return '$t%+';
    return '$t–${_thresholds[i + 1]}%';
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _summary.where((r) {
      if (!_inRange(r)) return false;
      if (q.isEmpty) return true;
      return [
        r['companyName'],
        r['endUser'],
        r['nickname'],
        r['serviceLineNumber'],
      ].any((v) => '${v ?? ''}'.toLowerCase().contains(q));
    }).toList();
  }

  void _export() {
    final rows = _filtered;
    if (rows.isEmpty) return;
    final lines = rows.map((r) => r['serviceLineNumber']).toSet();
    final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    exportSheets(context, 'usage-report-$stamp.xlsx', [
      ExportSheet(
        'Summary',
        [
          'Company',
          'End user',
          'Nickname',
          'Service line',
          'Usage limit (GB)',
          'Consumed (GB)',
          'Used %',
        ],
        [
          for (final r in rows)
            [
              r['companyName'],
              r['endUser'],
              r['nickname'],
              r['serviceLineNumber'],
              _num(r['usageLimitGB']),
              _num(r['consumedAmountGB']),
              double.parse(_exactPct(r).toStringAsFixed(2)),
            ],
        ],
      ),
      ExportSheet(
        'Daily',
        [
          'Company',
          'End user',
          'Service line',
          'Date',
          'Priority (GB)',
          'Opt-in priority (GB)',
          'Standard (GB)',
          'Non-billable (GB)',
        ],
        [
          for (final d in _daily.where(
            (d) => lines.contains(d['serviceLineNumber']),
          ))
            [
              d['companyName'],
              d['endUser'],
              d['serviceLineNumber'],
              '${d['Date'] ?? ''}'.split('T').first,
              _num(d['priorityGB']),
              _num(d['optInPriorityGB']),
              _num(d['standardGB']),
              _num(d['nonBillableGB']),
            ],
        ],
      ),
    ]);
  }

  void _openDaily(Map<String, dynamic> r) {
    final sln = r['serviceLineNumber'];
    final rows =
        _daily.where((d) => d['serviceLineNumber'] == sln).toList()
          ..sort((a, b) => '${a['Date']}'.compareTo('${b['Date']}'));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DailySheet(row: r, daily: rows),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Export to Excel',
            onPressed: _loading || rows.isEmpty ? null : _export,
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search company, end user, line…',
                        prefixIcon: Icon(Icons.search),
                        filled: true,
                        fillColor: AppColors.paper,
                      ),
                    ),
                    const SizedBox(height: 12),
                    PillChips<int>(
                      options: [
                        for (final t in _thresholds)
                          PillOption(
                            t,
                            _rangeLabel(t),
                            count:
                                t == 0
                                    ? _summary.length
                                    : _summary.where((r) {
                                      final p = _exactPct(r);
                                      final i = _thresholds.indexOf(t);
                                      final next =
                                          i + 1 < _thresholds.length
                                              ? _thresholds[i + 1]
                                              : null;
                                      return p >= t &&
                                          (next == null || p < next);
                                    }).length,
                          ),
                      ],
                      selected: _threshold,
                      onSelected: (t) => setState(() => _threshold = t),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${rows.length} service line${rows.length == 1 ? '' : 's'} · current billing cycle',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No service lines match',
                            style: TextStyle(color: AppColors.inkFaint),
                          ),
                        ),
                      )
                    else
                      for (final r in rows)
                        _UsageTile(
                          row: r,
                          pct: _exactPct(r),
                          onTap: () => _openDaily(r),
                        ),
                  ],
                ),
              ),
    );
  }
}

class _UsageTile extends StatelessWidget {
  const _UsageTile({required this.row, required this.pct, required this.onTap});
  final Map<String, dynamic> row;
  final double pct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = '${row['nickname'] ?? ''}'.trim();
    final sln = '${row['serviceLineNumber'] ?? ''}';
    final account = [
      row['companyName'],
      row['endUser'],
    ].where((v) => '${v ?? ''}'.trim().isNotEmpty).join(' · ');
    final color =
        pct >= 100
            ? AppColors.brand
            : pct >= 75
            ? AppColors.warning
            : AppColors.success;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name.isEmpty ? sln : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      '${pct.round()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [sln, account].where((e) => e.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0, 1).toDouble(),
                    minHeight: 6,
                    backgroundColor: AppColors.paperMuted,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_gb(_num(row['consumedAmountGB']))} of ${_gb(_num(row['usageLimitGB']))}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailySheet extends StatelessWidget {
  const _DailySheet({required this.row, required this.daily});
  final Map<String, dynamic> row;
  final List<Map<String, dynamic>> daily;

  @override
  Widget build(BuildContext context) {
    final name = '${row['nickname'] ?? ''}'.trim();
    final dates = [
      for (final d in daily) DateTime.tryParse('${d['Date']}'.split('T').first),
    ];
    double maxY = 0;
    for (final d in daily) {
      for (final s in _series) {
        maxY = _num(d[s.$2]) > maxY ? _num(d[s.$2]) : maxY;
      }
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isEmpty ? '${row['serviceLineNumber']}' : name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const Text(
              'Daily usage · current cycle',
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 16),
            if (daily.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No daily usage yet this cycle',
                    style: TextStyle(color: AppColors.inkFaint),
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY <= 0 ? 1 : maxY * 1.15,
                    gridData: const FlGridData(drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          interval: (daily.length / 5).ceilToDouble().clamp(
                            1,
                            100,
                          ),
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            final d =
                                i >= 0 && i < dates.length ? dates[i] : null;
                            return Text(
                              d == null ? '' : DateFormat('MMM d').format(d),
                              style: const TextStyle(fontSize: 9),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      for (final s in _series)
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < daily.length; i++)
                              FlSpot(i.toDouble(), _num(daily[i][s.$2])),
                          ],
                          color: s.$3,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  for (final s in _series)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.$3,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${s.$1}: ${_gb(daily.fold(0.0, (t, d) => t + _num(d[s.$2])))}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
