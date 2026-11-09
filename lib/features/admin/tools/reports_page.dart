import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/core/utils/sheet_export.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';

/// Usage reports (admins, agents) — the web portal's Reports page: current
/// cycle usage per service line (GET /usage/summary) as a list or a graph,
/// filtered by how much of the limit is used, with each line's daily usage
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

// The web portal's colors for the overview graph.
const _limitColor = Color(0xFF3E7A93);
const _consumedColor = AppColors.brand;

/// Compact GB label. The axis's top value is left out unless it lands on an
/// interval, since it would sit on top of the label below it.
Widget _axisLabel(double v, TitleMeta meta) {
  if (v == meta.max && v % meta.appliedInterval != 0) {
    return const SizedBox.shrink();
  }
  return SideTitleWidget(
    axisSide: meta.axisSide,
    child: Text(
      NumberFormat.compact().format(v),
      style: const TextStyle(fontSize: 10, color: AppColors.inkFaint),
    ),
  );
}

double _num(dynamic v) => double.tryParse('${v ?? ''}') ?? 0;

String _text(dynamic v) {
  final t = v?.toString().trim() ?? '';
  return t == 'null' ? '' : t;
}

/// `0.93 GB`, `21 GB`, `1,000 GB`, like the web portal.
String reportGb(dynamic v) {
  final n = _num(v);
  return '${NumberFormat(n < 10 ? '#,##0.00' : '#,##0').format(n)} GB';
}

double reportExactPct(Map<String, dynamic> r) {
  final limit = _num(r['usageLimitGB']);
  return limit > 0 ? _num(r['consumedAmountGB']) / limit * 100 : 0;
}

/// Share of the limit used, rounded and capped for the bar and the export.
int reportUsagePct(Map<String, dynamic> r) =>
    reportExactPct(r).round().clamp(0, 100);

String reportRangeLabel(int t) {
  if (t == 0) return 'All';
  final i = _thresholds.indexOf(t);
  if (i + 1 >= _thresholds.length) return '$t%+';
  return '$t–${_thresholds[i + 1] - 1}.99%';
}

bool reportInRange(Map<String, dynamic> r, int t) {
  if (t == 0) return true;
  final p = reportExactPct(r);
  final i = _thresholds.indexOf(t);
  final next = i + 1 < _thresholds.length ? _thresholds[i + 1] : null;
  return p >= t && (next == null || p < next);
}

/// The same two sheets as the web portal's Export to Excel.
List<ExportSheet> usageReportSheets(
  List<Map<String, dynamic>> summary,
  List<Map<String, dynamic>> daily,
) => [
  ExportSheet(
    'Usage Summary',
    const [
      'Company',
      'End User',
      'Nickname',
      'Service Line',
      'Usage Limit GB',
      'Consumed GB',
      'Usage %',
    ],
    [
      for (final r in summary)
        [
          _text(r['companyName']),
          _text(r['endUser']),
          _text(r['nickname']),
          _text(r['serviceLineNumber']),
          _num(r['usageLimitGB']),
          _num(r['consumedAmountGB']),
          reportUsagePct(r),
        ],
    ],
  ),
  ExportSheet(
    'Daily Usage',
    const [
      'Company',
      'End User',
      'Service Line',
      'Date',
      'Priority GB',
      'Opt-In Priority GB',
      'Standard GB',
      'Non-Billable GB',
    ],
    [
      for (final d in daily)
        [
          _text(d['companyName']),
          _text(d['endUser']),
          _text(d['serviceLineNumber']),
          _text(d['Date']).split('T').first,
          _num(d['priorityGB']),
          _num(d['optInPriorityGB']),
          _num(d['standardGB']),
          _num(d['nonBillableGB']),
        ],
    ],
  ),
];

class _ReportsPageState extends State<ReportsPage> {
  static const _pageSize = 20;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _summary = [];
  List<Map<String, dynamic>> _daily = [];
  int _threshold = 0;
  bool _graph = false;
  int _shown = _pageSize;
  final _expanded = <String>{};
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
      _loading = _summary.isEmpty;
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

  List<Map<String, dynamic>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _summary.where((r) {
      if (!reportInRange(r, _threshold)) return false;
      if (q.isEmpty) return true;
      return [
        r['companyName'],
        r['endUser'],
        r['nickname'],
        r['serviceLineNumber'],
      ].any((v) => _text(v).toLowerCase().contains(q));
    }).toList();
  }

  void _export() {
    final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    exportSheets(
      context,
      'usage-report-$stamp.xlsx',
      usageReportSheets(_filtered, _daily),
    );
  }

  List<Map<String, dynamic>> _dailyFor(String sln) =>
      _daily.where((d) => _text(d['serviceLineNumber']) == sln).toList();

  void _openChart(Map<String, dynamic> r) {
    final rows = _dailyFor(_text(r['serviceLineNumber']))
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
      backgroundColor: AppColors.paperSubtle,
      appBar: AppBar(
        title: const Text('Usage Reports'),
        actions: [
          IconButton(
            tooltip: 'Export to Excel',
            onPressed: _loading || rows.isEmpty ? null : _export,
            icon: const Icon(Icons.download_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                onRefresh: _load,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.axis == Axis.vertical &&
                        !_graph &&
                        n.metrics.extentAfter < 300 &&
                        _shown < rows.length) {
                      setState(() => _shown += _pageSize);
                    }
                    return false;
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() => _shown = _pageSize),
                        decoration: const InputDecoration(
                          hintText:
                              'Search company, end user, nickname, service line…',
                          prefixIcon: Icon(Icons.search_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _RangePills(
                              selected: _threshold,
                              onSelected:
                                  (t) => setState(() {
                                    _threshold = t;
                                    _shown = _pageSize;
                                  }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ViewSwitch(
                            graph: _graph,
                            onChanged: (g) => setState(() => _graph = g),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_graph)
                        _OverviewGraph(rows: rows)
                      else if (rows.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _summary.isNotEmpty
                                ? 'No usage data matches these filters.'
                                : 'No service lines are in a billing cycle today.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        )
                      else
                        for (final r in rows.take(_shown))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _UsageCard(
                              row: r,
                              daily: _dailyFor(_text(r['serviceLineNumber'])),
                              expanded: _expanded.contains(
                                _text(r['serviceLineNumber']),
                              ),
                              onToggle:
                                  () => setState(() {
                                    final key = _text(r['serviceLineNumber']);
                                    if (!_expanded.remove(key)) {
                                      _expanded.add(key);
                                    }
                                  }),
                              onChart: () => _openChart(r),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
    );
  }
}

class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.graph, required this.onChanged});
  final bool graph;
  final ValueChanged<bool> onChanged;

  Widget _button(String label, IconData icon, bool value) {
    final on = graph == value;
    return Tooltip(
      message: label,
      child: Material(
        color: on ? AppColors.navy : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(
              icon,
              size: 18,
              color: on ? Colors.white : AppColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.line, width: 1.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button('List', Icons.format_list_bulleted_rounded, false),
        _button('Graph', Icons.bar_chart_rounded, true),
      ],
    ),
  );
}

class _RangePills extends StatelessWidget {
  const _RangePills({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => FadingHScroll(
    child: Row(
      children: [
        const Text(
          'USAGE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: AppColors.inkFaint,
          ),
        ),
        const SizedBox(width: 8),
        for (final t in _thresholds)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: selected == t ? AppColors.brand : AppColors.paper,
              shape: StadiumBorder(
                side: BorderSide(
                  color: selected == t ? AppColors.brand : AppColors.line,
                  width: 1.5,
                ),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onSelected(t),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    reportRangeLabel(t),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected == t ? Colors.white : AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Usage limit vs consumed for every matching line; scrolls sideways.
class _OverviewGraph extends StatelessWidget {
  const _OverviewGraph({required this.rows});
  final List<Map<String, dynamic>> rows;

  String _label(Map<String, dynamic> r) {
    final name = _text(r['nickname']);
    return name.isNotEmpty ? name : _text(r['serviceLineNumber']);
  }

  @override
  Widget build(BuildContext context) {
    var maxY = 0.0;
    for (final r in rows) {
      maxY = [
        maxY,
        _num(r['usageLimitGB']),
        _num(r['consumedAmountGB']),
      ].reduce((a, b) => a > b ? a : b);
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Usage limit vs consumed (current cycle)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _LegendItem('Usage limit (GB)', _limitColor),
              _LegendItem('Consumed (GB)', _consumedColor),
            ],
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No service lines match these filters.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                final width = (rows.length * 46.0 + 56).clamp(
                  box.maxWidth,
                  double.infinity,
                );
                return FadingHScroll(
                  child: SizedBox(
                    width: width,
                    height: 340,
                    child: BarChart(
                      BarChartData(
                        minY: 0,
                        maxY: maxY <= 0 ? 1 : maxY * 1.1,
                        alignment: BarChartAlignment.spaceAround,
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(drawVerticalLine: false),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBgColor: AppColors.navy,
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItem: (group, _, rod, rodIndex) {
                              final r = rows[group.x];
                              final limit = rodIndex == 0;
                              return BarTooltipItem(
                                '${_label(r)}\n',
                                const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        '${limit ? 'Usage limit' : 'Consumed'}: '
                                        '${reportGb(rod.toY)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 44,
                              getTitlesWidget: _axisLabel,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 84,
                              getTitlesWidget: (v, meta) {
                                final i = v.toInt();
                                if (i < 0 || i >= rows.length) {
                                  return const SizedBox.shrink();
                                }
                                final label = _label(rows[i]);
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  angle: -0.8,
                                  space: 18,
                                  child: SizedBox(
                                    width: 88,
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        color: AppColors.inkMuted,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < rows.length; i++)
                            BarChartGroupData(
                              x: i,
                              barsSpace: 2,
                              barRods: [
                                _rod(
                                  _num(rows[i]['usageLimitGB']),
                                  _limitColor,
                                ),
                                _rod(
                                  _num(rows[i]['consumedAmountGB']),
                                  _consumedColor,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  BarChartRodData _rod(double y, Color color) => BarChartRodData(
    toY: y,
    color: color,
    width: 12,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
      ),
    ],
  );
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({
    required this.row,
    required this.daily,
    required this.expanded,
    required this.onToggle,
    required this.onChart,
  });
  final Map<String, dynamic> row;
  final List<Map<String, dynamic>> daily;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onChart;

  @override
  Widget build(BuildContext context) {
    final pct = reportUsagePct(row);
    final color =
        pct >= 90
            ? AppColors.brand
            : pct >= 75
            ? AppColors.warning
            : AppColors.success;
    final company = _text(row['companyName']);
    final endUser = _text(row['endUser']);
    final nickname = _text(row['nickname']);
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          company.isEmpty ? '—' : company,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          endUser.isEmpty ? '—' : endUser,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.inkFaint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                nickname.isEmpty ? '—' : nickname,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                _text(row['serviceLineNumber']),
                style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 6,
                        backgroundColor: AppColors.paperMuted,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${reportGb(row['consumedAmountGB'])} / '
                    '${reportGb(row['usageLimitGB'])}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 6),
                _DailyBreakdown(daily: daily, onChart: onChart),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A line's days in this cycle, newest first.
class _DailyBreakdown extends StatelessWidget {
  const _DailyBreakdown({required this.daily, required this.onChart});
  final List<Map<String, dynamic>> daily;
  final VoidCallback onChart;

  static const _columns = [
    ('Priority', 'priorityGB'),
    ('Opt-in', 'optInPriorityGB'),
    ('Standard', 'standardGB'),
    ('Non-bill.', 'nonBillableGB'),
  ];

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No daily breakdown for this service line.',
          style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
        ),
      );
    }
    final rows = [...daily]
      ..sort((a, b) => '${b['Date']}'.compareTo('${a['Date']}'));
    const head = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: AppColors.inkMuted,
    );
    const cell = TextStyle(fontSize: 11.5, color: AppColors.inkSoft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Daily usage (GB)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onChart,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.ink,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              icon: const Icon(Icons.bar_chart_rounded, size: 16),
              label: const Text('View chart', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {0: FlexColumnWidth(1.45)},
          children: [
            TableRow(
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('Date', style: head),
                ),
                for (final c in _columns)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(c.$1, style: head),
                    ),
                  ),
              ],
            ),
            for (final d in rows)
              TableRow(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.paperMuted)),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Text(_day(d['Date']), style: cell),
                  ),
                  for (final c in _columns)
                    Text(
                      NumberFormat('#,##0.00').format(_num(d[c.$2])),
                      textAlign: TextAlign.right,
                      style: cell,
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  String _day(dynamic raw) {
    final d = DateTime.tryParse(_text(raw).split('T').first);
    return d == null ? '—' : DateFormat('MMM dd').format(d);
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
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: _axisLabel,
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
                          '${s.$1}: ${reportGb(daily.fold(0.0, (t, d) => t + _num(d[s.$2])))}',
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
