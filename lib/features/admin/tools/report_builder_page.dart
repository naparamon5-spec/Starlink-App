import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/core/utils/billing_export.dart';
import 'package:starlink_app/core/utils/sheet_export.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';

/// Report builder (admins, agents) — the web portal's Report Builder:
/// pick a source (GET /reports/sources), columns, filters, grouping with
/// totals and sort, then run it (POST /reports/run) and export to Excel.
class ReportBuilderPage extends StatefulWidget {
  const ReportBuilderPage({super.key});

  @override
  State<ReportBuilderPage> createState() => _ReportBuilderPageState();
}

const _numeric = ['id', 'number', 'money', 'gb', 'percent'];
const _measurable = ['number', 'money', 'gb', 'percent'];
const _dates = ['date', 'datetime'];

List<String> _opsFor(String type) {
  if (_numeric.contains(type)) {
    return [
      'eq',
      'ne',
      'gt',
      'gte',
      'lt',
      'lte',
      'between',
      'empty',
      'not_empty',
    ];
  }
  if (_dates.contains(type)) {
    return [
      'on',
      'after',
      'before',
      'between',
      'last_days',
      'next_days',
      'empty',
      'not_empty',
    ];
  }
  if (type == 'enum') return ['in', 'not_in', 'empty', 'not_empty'];
  return [
    'contains',
    'equals',
    'not_equals',
    'starts_with',
    'empty',
    'not_empty',
  ];
}

const _opLabels = {
  'contains': 'contains',
  'equals': 'is',
  'not_equals': 'is not',
  'starts_with': 'starts with',
  'in': 'is any of',
  'not_in': 'is none of',
  'eq': '=',
  'ne': '≠',
  'gt': '>',
  'gte': '≥',
  'lt': '<',
  'lte': '≤',
  'between': 'between',
  'on': 'on',
  'after': 'on or after',
  'before': 'on or before',
  'last_days': 'in the last … days',
  'next_days': 'in the next … days',
  'empty': 'is empty',
  'not_empty': 'is not empty',
};

/// The web portal's address for a report setup, so it opens there as built.
String reportShareLink(Map<String, dynamic> request) {
  final code = base64Url.encode(utf8.encode(json.encode(request)));
  return 'https://starlink.ardentnetworks.com.ph/report-builder'
      '?r=${code.replaceAll('=', '')}';
}

String _humanize(String v) {
  final t = v.replaceAll('_', ' ').trim();
  return t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1)}';
}

/// A result cell as the web portal shows it. [options] are an enum field's.
String reportCellText(dynamic value, String type, {List<dynamic>? options}) {
  if (value == null || '$value'.isEmpty) return '—';
  final text = '$value';
  final n = num.tryParse(text);
  switch (type) {
    case 'money':
      return n == null ? text : billingMoney(n);
    case 'gb':
      return n == null ? text : '${NumberFormat('#,##0.00').format(n)} GB';
    case 'percent':
      return n == null ? text : '${NumberFormat('#,##0.0').format(n)}%';
    case 'number':
      return n == null
          ? text
          : NumberFormat(
            n == n.roundToDouble() ? '#,##0' : '#,##0.00',
          ).format(n);
    case 'date':
      return billingDate(value);
    case 'datetime':
      final d = DateTime.tryParse(text.replaceFirst(' ', 'T'));
      if (d == null || d.year < 1900) return '—';
      return DateFormat('MMM dd, y, h:mm a').format(d.toLocal());
    case 'enum':
      for (final o in options ?? const []) {
        if (o is Map && '${o['value']}' == text) return '${o['label']}';
      }
      return _humanize(text);
    default:
      return text;
  }
}

/// A result cell for Excel: real numbers, no placeholder dates, enum labels.
Object? reportExportValue(
  dynamic value,
  String type, {
  List<dynamic>? options,
}) {
  if (value == null || '$value'.isEmpty) return null;
  final text = '$value';
  if (_numeric.contains(type)) return num.tryParse(text) ?? text;
  if (_dates.contains(type)) return text.startsWith('0000') ? null : text;
  if (type == 'enum') {
    for (final o in options ?? const []) {
      if (o is Map && '${o['value']}' == text) return '${o['label']}';
    }
  }
  return text;
}

dynamic _defaultValue(String op) {
  if (op == 'in' || op == 'not_in') return <String>[];
  if (op == 'between') return ['', ''];
  if (op == 'last_days' || op == 'next_days') return 30;
  if (op == 'empty' || op == 'not_empty') return null;
  return '';
}

/// Ready-made reports (same as the web portal's templates).
const _templates = <Map<String, dynamic>>[
  {
    'name': 'Open tickets by company',
    'description': 'Open and in-progress tickets, counted per company.',
    'request': {
      'source': 'tickets',
      'columns': [],
      'filters': [
        {
          'field': 'status',
          'op': 'in',
          'value': ['open', 'in_progress'],
        },
      ],
      'groupBy': [
        {'field': 'company'},
      ],
      'measures': [],
      'sort': {'key': 'count', 'dir': 'desc'},
    },
  },
  {
    'name': 'Tickets per month by type',
    'description':
        'How many tickets of each type were opened each month this year.',
    'request': {
      'source': 'tickets',
      'columns': [],
      'filters': [
        {'field': 'created_at', 'op': 'last_days', 'value': 365},
      ],
      'groupBy': [
        {'field': 'created_at', 'bucket': 'month'},
        {'field': 'ticket_type'},
      ],
      'measures': [],
      'sort': {'key': 'g0', 'dir': 'desc'},
    },
  },
  {
    'name': 'Tickets open longer than 7 days',
    'description': 'Unresolved tickets, oldest first.',
    'request': {
      'source': 'tickets',
      'columns': [
        'id',
        'subject',
        'company',
        'status',
        'assigned_agent',
        'created_at',
        'days_open',
      ],
      'filters': [
        {
          'field': 'status',
          'op': 'in',
          'value': ['open', 'in_progress'],
        },
        {'field': 'days_open', 'op': 'gte', 'value': 7},
      ],
      'groupBy': [],
      'measures': [],
      'sort': {'key': 'days_open', 'dir': 'desc'},
    },
  },
  {
    'name': 'Service lines ending in 30 days',
    'description': 'Lines whose end date is within the next 30 days.',
    'request': {
      'source': 'service_lines',
      'columns': [
        'service_line',
        'nickname',
        'company',
        'end_user',
        'status',
        'end_date',
        'days_left',
      ],
      'filters': [
        {'field': 'end_date', 'op': 'next_days', 'value': 30},
      ],
      'groupBy': [],
      'measures': [],
      'sort': {'key': 'end_date', 'dir': 'asc'},
    },
  },
  {
    'name': 'Unpaid billing by customer',
    'description': 'Billed, paid and outstanding amounts per customer.',
    'request': {
      'source': 'billing',
      'columns': [],
      'filters': [
        {'field': 'balance', 'op': 'gt', 'value': 0},
      ],
      'groupBy': [
        {'field': 'customer'},
      ],
      'measures': [
        {'field': 'amount', 'fn': 'sum'},
        {'field': 'paid', 'fn': 'sum'},
        {'field': 'balance', 'fn': 'sum'},
      ],
      'sort': {'key': 'm2', 'dir': 'desc'},
    },
  },
  {
    'name': 'Lines over 80% of their limit',
    'description':
        'Billing cycles from the last 45 days where priority data passed 80% of the plan.',
    'request': {
      'source': 'usage_cycles',
      'columns': [
        'cycle_start',
        'company',
        'nickname',
        'service_line',
        'limit_gb',
        'priority_gb',
        'percent_used',
      ],
      'filters': [
        {'field': 'cycle_start', 'op': 'last_days', 'value': 45},
        {'field': 'percent_used', 'op': 'gte', 'value': 80},
      ],
      'groupBy': [],
      'measures': [],
      'sort': {'key': 'percent_used', 'dir': 'desc'},
    },
  },
  {
    'name': 'Data used per company (30 days)',
    'description': 'Total data per company over the last 30 days.',
    'request': {
      'source': 'daily_usage',
      'columns': [],
      'filters': [
        {'field': 'date', 'op': 'last_days', 'value': 30},
      ],
      'groupBy': [
        {'field': 'company'},
      ],
      'measures': [
        {'field': 'total_gb', 'fn': 'sum'},
        {'field': 'priority_gb', 'fn': 'sum'},
      ],
      'sort': {'key': 'm0', 'dir': 'desc'},
    },
  },
  {
    'name': 'Active accounts by company and role',
    'description': 'Portal accounts that can sign in, per company and role.',
    'request': {
      'source': 'accounts',
      'columns': [],
      'filters': [
        {
          'field': 'status',
          'op': 'in',
          'value': ['active'],
        },
      ],
      'groupBy': [
        {'field': 'company'},
        {'field': 'role'},
      ],
      'measures': [],
      'sort': {'key': 'g0', 'dir': 'asc'},
    },
  },
];

class _ReportBuilderPageState extends State<ReportBuilderPage> {
  bool _loadingSources = true;
  String? _sourcesError;
  List<Map<String, dynamic>> _sources = [];

  // Request being built
  String _source = '';
  List<String> _columns = [];
  List<Map<String, dynamic>> _filters = [];
  List<Map<String, dynamic>> _groupBy = [];
  List<Map<String, dynamic>> _measures = [];
  Map<String, dynamic>? _sort;
  int _limit = 1000;

  bool _running = false;
  String? _runError;
  Map<String, dynamic>? _result;
  int _page = 0;
  final _resultKey = GlobalKey();

  static const _perPage = 25;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  Future<void> _loadSources() async {
    setState(() {
      _loadingSources = true;
      _sourcesError = null;
    });
    final res = await ApiService.getReportSources();
    if (!mounted) return;
    final data = res['data'];
    setState(() {
      _loadingSources = false;
      if (res['status'] == 'success' && data is List) {
        _sources =
            data
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList();
      } else {
        _sourcesError =
            res['message']?.toString() ?? 'Could not load report sources';
      }
    });
    if (_sources.isNotEmpty && _source.isEmpty) {
      _pickSource('${_sources.first['key']}');
    }
  }

  Map<String, dynamic>? get _src => _sources
      .cast<Map<String, dynamic>?>()
      .firstWhere((s) => s!['key'] == _source, orElse: () => null);

  List<Map<String, dynamic>> get _fields =>
      ((_src?['fields'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

  Map<String, dynamic>? _field(String key) => _fields
      .cast<Map<String, dynamic>?>()
      .firstWhere((f) => f!['key'] == key, orElse: () => null);

  bool get _grouped => _groupBy.isNotEmpty;

  dynamic _copy(dynamic v) => json.decode(json.encode(v));

  void _pickSource(String key) {
    final s = _sources.firstWhere((x) => x['key'] == key);
    setState(() {
      _source = key;
      _columns = List<String>.from(s['defaultColumns'] ?? const []);
      _filters = List<Map<String, dynamic>>.from(
        (_copy(s['defaultFilters'] ?? const []) as List).map(
          (e) => Map<String, dynamic>.from(e),
        ),
      );
      _groupBy = [];
      _measures = [];
      _sort =
          s['defaultSort'] is Map
              ? Map<String, dynamic>.from(s['defaultSort'])
              : null;
      _result = null;
      _runError = null;
    });
  }

  void _applyTemplate(Map<String, dynamic> t) {
    final r = Map<String, dynamic>.from(t['request'] as Map);
    if (!_sources.any((s) => s['key'] == r['source'])) {
      AppToast.error(context, "This report isn't available to you");
      return;
    }
    setState(() {
      _source = r['source'];
      bool has(dynamic k) => _fields.any((f) => f['key'] == k);
      _columns =
          List<String>.from(r['columns'] ?? const []).where(has).toList();
      _filters = [
        for (final f in (_copy(r['filters'] ?? const []) as List))
          if (has(f['field'])) Map<String, dynamic>.from(f),
      ];
      _groupBy = [
        for (final g in (_copy(r['groupBy'] ?? const []) as List))
          if (has(g['field'])) Map<String, dynamic>.from(g),
      ];
      _measures = [
        for (final m in (_copy(r['measures'] ?? const []) as List))
          if (has(m['field'])) Map<String, dynamic>.from(m),
      ];
      _sort = r['sort'] is Map ? Map<String, dynamic>.from(r['sort']) : null;
      if (_groupBy.isEmpty && _columns.isEmpty) {
        _columns = List<String>.from(_src?['defaultColumns'] ?? const []);
      }
      _result = null;
    });
    _run();
  }

  // ── Filters ────────────────────────────────────────────────────────────────

  void _addFilter() {
    final first = _fields.isEmpty ? null : _fields.first;
    if (first == null) return;
    final op = _opsFor('${first['type']}').first;
    setState(
      () => _filters.add({
        'field': first['key'],
        'op': op,
        'value': _defaultValue(op),
      }),
    );
  }

  // ── Grouping ───────────────────────────────────────────────────────────────

  Map<String, dynamic> _groupFor(String key) {
    final f = _field(key);
    return f != null && _dates.contains(f['type'])
        ? {'field': key, 'bucket': 'month'}
        : {'field': key};
  }

  void _addGroup() {
    if (_groupBy.length >= 2) return;
    final used = _groupBy.map((g) => g['field']).toSet();
    final next = _fields.cast<Map<String, dynamic>?>().firstWhere(
      (f) =>
          !used.contains(f!['key']) &&
          f['type'] != 'id' &&
          f['type'] != 'number',
      orElse: () => null,
    );
    if (next == null) return;
    setState(() {
      final wasGrouped = _grouped;
      _groupBy.add(_groupFor(next['key']));
      if (!wasGrouped) _sort = {'key': 'count', 'dir': 'desc'};
    });
  }

  void _removeGroup(int i) {
    setState(() {
      _groupBy.removeAt(i);
      if (_groupBy.isEmpty) {
        _measures = [];
        _sort =
            _src?['defaultSort'] is Map
                ? Map<String, dynamic>.from(_src!['defaultSort'])
                : null;
      }
    });
  }

  // ── Run ────────────────────────────────────────────────────────────────────

  Future<void> _run() async {
    if (!_canRun || _running) return;
    setState(() {
      _running = true;
      _runError = null;
    });
    final res = await ApiService.runReport({
      'source': _source,
      'columns': _grouped ? <String>[] : _columns,
      'filters': _filters,
      'groupBy': _groupBy,
      'measures': _grouped ? _measures : <Map<String, dynamic>>[],
      'sort': _sort,
      'limit': _limit,
    });
    if (!mounted) return;
    final data = res['data'];
    setState(() {
      _running = false;
      if (res['status'] == 'success' && data is Map) {
        _result = Map<String, dynamic>.from(data);
        _page = 0;
      } else {
        _result = null;
        _runError = res['message']?.toString() ?? "The report couldn't be run";
      }
    });
    // The form is long: bring the outcome into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final at = _resultKey.currentContext;
      if (at != null && at.mounted) {
        Scrollable.ensureVisible(
          at,
          duration: const Duration(milliseconds: 250),
        );
      }
    });
  }

  List<Map<String, dynamic>> get _resultColumns =>
      ((_result?['columns'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

  List<Map<String, dynamic>> get _resultRows =>
      ((_result?['rows'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

  List<dynamic>? _optionsOf(Map<String, dynamic> col) =>
      _field('${col['field'] ?? col['key']}')?['options'] as List?;

  void _export() {
    final cols = _resultColumns;
    final rows = _resultRows;
    if (cols.isEmpty || rows.isEmpty) return;
    if (_result?['truncated'] == true) {
      final total = int.tryParse('${_result?['total']}') ?? rows.length;
      AppToast.info(context, 'Only the first ${NumberFormat('#,##0').format(rows.length)} of '
            '${NumberFormat('#,##0').format(total)} rows are in this file.');
    }
    final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final label = (_src?['label'] ?? 'Report').toString();
    exportSheets(context, 'report-$_source-$stamp.xlsx', [
      ExportSheet(
        label.length > 31 ? label.substring(0, 31) : label,
        [for (final c in cols) '${c['label']}'],
        [
          for (final r in rows)
            [
              for (final c in cols)
                reportExportValue(
                  r[c['key']],
                  '${c['type']}',
                  options: _optionsOf(c),
                ),
            ],
        ],
      ),
    ]);
  }

  bool get _canRun => _source.isNotEmpty && (_grouped || _columns.isNotEmpty);

  Map<String, dynamic> get _request => {
    'source': _source,
    'columns': _columns,
    'filters': _filters,
    'groupBy': _groupBy,
    'measures': _measures,
    'sort': _sort,
    'limit': _limit,
  };

  Future<void> _copyLink() async {
    final toast = AppToast.of(context);
    await Clipboard.setData(ClipboardData(text: reportShareLink(_request)));
    toast.showSuccess('Link copied. Anyone with staff access can open this report.');
  }

  void _openTemplates() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (ctx) => ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      'Templates',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      children: [
                        for (final t in _templates)
                          ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            title: Text(
                              '${t['name']}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                            subtitle: Text(
                              '${t['description']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.inkMuted,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              _applyTemplate(t);
                            },
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

  /// Keys and labels of the result's columns, the same ones the API returns.
  List<SelectOption<String>> get _outputColumns {
    String label(dynamic key) => '${_field('$key')?['label'] ?? key}';
    if (!_grouped) {
      return [for (final k in _columns) SelectOption(k, label(k))];
    }
    const fn = {'sum': 'Sum', 'avg': 'Average', 'min': 'Min', 'max': 'Max'};
    return [
      for (var i = 0; i < _groupBy.length; i++)
        SelectOption(
          'g$i',
          label(_groupBy[i]['field']) +
              (_groupBy[i]['bucket'] != null
                  ? ' (${_groupBy[i]['bucket']})'
                  : ''),
        ),
      const SelectOption('count', 'Count'),
      for (var i = 0; i < _measures.length; i++)
        SelectOption(
          'm$i',
          '${fn[_measures[i]['fn']]} of '
              '${label(_measures[i]['field']).toLowerCase()}',
        ),
    ];
  }

  /// A sort on a column no longer shown falls back to the first column.
  void _keepSortValid() {
    final cols = _outputColumns;
    if (_sort != null && !cols.any((c) => c.value == _sort!['key'])) {
      _sort =
          cols.isEmpty
              ? null
              : {'key': cols.first.value, 'dir': _sort!['dir'] ?? 'asc'};
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _keepSortValid();
    return Scaffold(
      backgroundColor: AppColors.paperSubtle,
      appBar: AppBar(title: const Text('Report Builder')),
      body:
          _loadingSources
              ? const Center(child: CircularProgressIndicator())
              : _sourcesError != null
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _sourcesError!,
                      style: const TextStyle(color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _loadSources,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  _buildActions(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                      children: [
                        _buildSetup(),
                        const SizedBox(height: 16),
                        KeyedSubtree(key: _resultKey, child: _buildResult()),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  /// Stays on screen while the form and results scroll.
  Widget _buildActions() {
    const pad = EdgeInsets.symmetric(horizontal: 6);
    const text = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600);
    Widget fit(Widget child) => FittedBox(fit: BoxFit.scaleDown, child: child);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: OutlinedButton(
              onPressed: _openTemplates,
              style: OutlinedButton.styleFrom(padding: pad),
              child: fit(
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dashboard_outlined, size: 16),
                    SizedBox(width: 5),
                    Text('Templates', style: text),
                    SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 4,
            child: TextButton(
              onPressed: _canRun ? _copyLink : null,
              style: TextButton.styleFrom(
                padding: pad,
                foregroundColor: AppColors.ink,
              ),
              child: fit(
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link_rounded, size: 16),
                    SizedBox(width: 5),
                    Text('Copy link', style: text),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: TextButton(
              onPressed: _resultRows.isEmpty ? null : _export,
              style: TextButton.styleFrom(
                padding: pad,
                foregroundColor: AppColors.ink,
              ),
              child: fit(
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.file_download_outlined, size: 16),
                    SizedBox(width: 5),
                    Text('Export', style: text),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetup() {
    final description = _src?['description']?.toString() ?? '';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSelect<String>(
            label: 'Report on',
            sheetTitle: 'Report on',
            value: _source.isEmpty ? null : _source,
            hint: 'Pick a source',
            options: [
              for (final s in _sources)
                SelectOption('${s['key']}', '${s['label']}'),
            ],
            onChanged: _pickSource,
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(description, style: _noteStyle),
          ],
          if (_source.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildGrouping(),
            const SizedBox(height: 18),
            if (_grouped) _buildTotals() else _buildColumns(),
            const SizedBox(height: 18),
            _buildFilters(),
            const SizedBox(height: 18),
            _buildSortLimit(),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canRun && !_running ? _run : null,
                icon:
                    _running
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.play_arrow_rounded),
                label: Text(_running ? 'Running…' : 'Run report'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _noteStyle = TextStyle(fontSize: 12, color: AppColors.inkFaint);

  /// Section title with its actions on the right, like the web form.
  Widget _heading(String title, List<Widget> actions) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.inkMuted,
            ),
          ),
        ),
        ...actions,
      ],
    ),
  );

  Widget _link(String label, VoidCallback onTap, {bool add = false}) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.sm),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (add) ...[
            const Icon(Icons.add_rounded, size: 15, color: AppColors.brand),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.brand,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _removeButton(String tooltip, VoidCallback onTap) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    onPressed: onTap,
    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.inkFaint),
  );

  Widget _buildColumns() {
    final defaults = List<String>.from(_src?['defaultColumns'] ?? const []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Columns', [
          _link(
            'All',
            () => setState(
              () => _columns = [for (final f in _fields) '${f['key']}'],
            ),
          ),
          const SizedBox(width: 6),
          _link('Default', () => setState(() => _columns = [...defaults])),
        ]),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.line),
          ),
          child: LayoutBuilder(
            builder:
                (context, box) => Wrap(
                  children: [
                    for (final f in _fields)
                      SizedBox(
                        width: box.maxWidth / 2,
                        child: InkWell(
                          onTap:
                              () => setState(() {
                                if (!_columns.remove(f['key'])) {
                                  _columns.add('${f['key']}');
                                }
                              }),
                          child: Row(
                            children: [
                              IgnorePointer(
                                child: Checkbox(
                                  value: _columns.contains(f['key']),
                                  onChanged: (_) {},
                                  visualDensity: const VisualDensity(
                                    horizontal: -4,
                                    vertical: -4,
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  activeColor: AppColors.brand,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  '${f['label']}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Filters', [_link('Add', _addFilter, add: true)]),
        if (_filters.isEmpty)
          const Text('No filters: every row is included.', style: _noteStyle)
        else
          for (var i = 0; i < _filters.length; i++) ...[
            _FilterEditor(
              key: ValueKey('f$i-${_filters[i]['field']}-${_filters[i]['op']}'),
              filter: _filters[i],
              fields: _fields,
              onChanged: (f) => setState(() => _filters[i] = f),
              onRemove: () => setState(() => _filters.removeAt(i)),
            ),
            if (i < _filters.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _buildGrouping() {
    final groupable = _fields.where((f) => f['type'] != 'id').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Group by', [
          if (_groupBy.length < 2) _link('Add', _addGroup, add: true),
        ]),
        if (_groupBy.isEmpty)
          Text(
            'No grouping: one row per '
            '${'${_src?['label'] ?? 'record'}'.toLowerCase().replaceFirst(RegExp(r's$'), '')}.',
            style: _noteStyle,
          ),
        for (var i = 0; i < _groupBy.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: AppSelect<String>(
                    dense: true,
                    value: _groupBy[i]['field'],
                    options: [
                      for (final f in groupable)
                        SelectOption('${f['key']}', '${f['label']}'),
                    ],
                    onChanged:
                        (v) => setState(() => _groupBy[i] = _groupFor(v)),
                  ),
                ),
                if (_dates.contains(_field(_groupBy[i]['field'])?['type'])) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: AppSelect<String>(
                      dense: true,
                      value: _groupBy[i]['bucket'] ?? 'month',
                      options: const [
                        SelectOption('day', 'Day'),
                        SelectOption('week', 'Week'),
                        SelectOption('month', 'Month'),
                        SelectOption('year', 'Year'),
                      ],
                      onChanged:
                          (v) => setState(() => _groupBy[i]['bucket'] = v),
                    ),
                  ),
                ],
                _removeButton('Remove grouping', () => _removeGroup(i)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTotals() {
    final measurable =
        _fields.where((f) => _measurable.contains(f['type'])).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Totals', [
          if (measurable.isNotEmpty)
            _link(
              'Add',
              () => setState(
                () => _measures.add({
                  'field': measurable.first['key'],
                  'fn': 'sum',
                }),
              ),
              add: true,
            ),
        ]),
        Text(
          measurable.isEmpty
              ? 'Each group shows its row count.'
              : 'Each group shows its row count, plus any totals added here.',
          style: _noteStyle,
        ),
        for (var i = 0; i < _measures.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: AppSelect<String>(
                    dense: true,
                    value: _measures[i]['fn'],
                    options: const [
                      SelectOption('sum', 'Sum'),
                      SelectOption('avg', 'Average'),
                      SelectOption('min', 'Min'),
                      SelectOption('max', 'Max'),
                    ],
                    onChanged: (v) => setState(() => _measures[i]['fn'] = v),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: AppSelect<String>(
                    dense: true,
                    value: _measures[i]['field'],
                    options: [
                      for (final f in measurable)
                        SelectOption('${f['key']}', '${f['label']}'),
                    ],
                    onChanged: (v) => setState(() => _measures[i]['field'] = v),
                  ),
                ),
                _removeButton(
                  'Remove total',
                  () => setState(() => _measures.removeAt(i)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSortLimit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSelect<String>(
          label: 'Sort by',
          dense: true,
          value: _sort?['key']?.toString(),
          hint: 'No sorting',
          options: _outputColumns,
          onChanged:
              (v) => setState(
                () => _sort = {'key': v, 'dir': _sort?['dir'] ?? 'asc'},
              ),
        ),
        const SizedBox(height: 8),
        AppSelect<String>(
          dense: true,
          enabled: _sort != null,
          value: _sort?['dir']?.toString() ?? 'asc',
          options: const [
            SelectOption('asc', 'Ascending'),
            SelectOption('desc', 'Descending'),
          ],
          onChanged: (v) => setState(() => _sort = {..._sort!, 'dir': v}),
        ),
        const SizedBox(height: 12),
        AppSelect<int>(
          label: 'Show up to',
          dense: true,
          value: _limit,
          options: const [
            SelectOption(100, '100 rows'),
            SelectOption(500, '500 rows'),
            SelectOption(1000, '1,000 rows'),
            SelectOption(5000, '5,000 rows'),
            SelectOption(10000, '10,000 rows'),
          ],
          onChanged: (v) => setState(() => _limit = v),
        ),
      ],
    );
  }

  Widget _buildResult() {
    if (_runError != null) {
      return AppCard(
        child: Center(
          child: Column(
            children: [
              const Text(
                "The report couldn't be run",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _runError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.dangerInk,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_result == null) {
      return const AppCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Text(
                'Set up a report and press Run',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Pick what to report on, choose columns or group rows to count '
                'and total them, add filters, then export the result to Excel. '
                'Or start from one of the templates.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
      );
    }
    final cols = _resultColumns;
    final rows = _resultRows;
    final total = int.tryParse('${_result!['total']}') ?? rows.length;
    final count = NumberFormat('#,##0').format(total);
    final noun =
        _grouped
            ? (total == 1 ? 'group' : 'groups')
            : (total == 1 ? 'row' : 'rows');
    final pages = rows.isEmpty ? 1 : ((rows.length - 1) ~/ _perPage) + 1;
    final page = _page.clamp(0, pages - 1);
    final visible = rows.skip(page * _perPage).take(_perPage).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: '$count $noun',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
            children: [
              if (_result!['truncated'] == true)
                TextSpan(
                  text:
                      ' · showing the first '
                      '${NumberFormat('#,##0').format(rows.length)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.warningInk,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${_src?['label'] ?? ''} · ${_result!['ms'] ?? 0} ms',
          style: _noteStyle,
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const AppCard(
            child: Center(
              child: Text(
                'No rows match these filters.',
                style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
              ),
            ),
          )
        else
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.line),
            ),
            child: FadingHScroll(
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 38,
                dataRowMaxHeight: 56,
                horizontalMargin: 14,
                columnSpacing: 22,
                headingRowColor: const WidgetStatePropertyAll(AppColors.navy),
                headingTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
                columns: [
                  for (final c in cols)
                    DataColumn(
                      label: Text('${c['label']}'.toUpperCase()),
                      numeric: _measurable.contains(c['type']),
                    ),
                ],
                rows: [
                  for (final r in visible)
                    DataRow(
                      cells: [
                        for (final c in cols)
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 170),
                              child: Text(
                                reportCellText(
                                  r[c['key']],
                                  '${c['type']}',
                                  options: _optionsOf(c),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        if (pages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  onPressed:
                      page > 0 ? () => setState(() => _page = page - 1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    'Page ${page + 1} of $pages',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next page',
                  onPressed:
                      page < pages - 1
                          ? () => setState(() => _page = page + 1)
                          : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One filter row: field, operator and a value input that fits the type.
class _FilterEditor extends StatefulWidget {
  const _FilterEditor({
    super.key,
    required this.filter,
    required this.fields,
    required this.onChanged,
    required this.onRemove,
  });
  final Map<String, dynamic> filter;
  final List<Map<String, dynamic>> fields;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onRemove;

  @override
  State<_FilterEditor> createState() => _FilterEditorState();
}

class _FilterEditorState extends State<_FilterEditor> {
  late final TextEditingController _a;
  late final TextEditingController _b;

  @override
  void initState() {
    super.initState();
    final v = widget.filter['value'];
    _a = TextEditingController(
      text:
          v is List ? (v.isNotEmpty ? '${v[0]}' : '') : (v == null ? '' : '$v'),
    );
    _b = TextEditingController(
      text: v is List && v.length > 1 ? '${v[1]}' : '',
    );
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _field =>
      widget.fields.cast<Map<String, dynamic>?>().firstWhere(
        (f) => f!['key'] == widget.filter['field'],
        orElse: () => null,
      );

  String get _type => '${_field?['type'] ?? 'text'}';
  bool get _isNum => _numeric.contains(_type);
  bool get _isDate => _dates.contains(_type);

  dynamic _parse(String s) =>
      _isNum ||
              widget.filter['op'] == 'last_days' ||
              widget.filter['op'] == 'next_days'
          ? (num.tryParse(s.trim()) ?? s.trim())
          : s;

  void _emit(dynamic value) =>
      widget.onChanged({...widget.filter, 'value': value});

  Future<void> _pickDate(TextEditingController c, void Function() after) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(c.text) ?? now,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null) return;
    c.text = DateFormat('yyyy-MM-dd').format(d);
    after();
  }

  Widget _input(
    TextEditingController c,
    void Function() onChange, {
    String? hint,
  }) {
    if (_isDate &&
        widget.filter['op'] != 'last_days' &&
        widget.filter['op'] != 'next_days') {
      return TextField(
        controller: c,
        readOnly: true,
        onTap: () => _pickDate(c, onChange),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint ?? 'YYYY-MM-DD',
          suffixIcon: const Icon(Icons.event, size: 18),
        ),
      );
    }
    return TextField(
      controller: c,
      keyboardType:
          _isNum ||
                  widget.filter['op'] == 'last_days' ||
                  widget.filter['op'] == 'next_days'
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
      onChanged: (_) => onChange(),
      decoration: InputDecoration(isDense: true, hintText: hint ?? 'Value'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final op = '${widget.filter['op']}';
    final ops = _opsFor(_type);
    final options =
        ((_field?['options'] as List?) ?? const []).whereType<Map>().toList();
    final selected =
        widget.filter['value'] is List
            ? List<String>.from(
              (widget.filter['value'] as List).map((e) => '$e'),
            )
            : <String>[];

    Widget? valueInput;
    if (op == 'empty' || op == 'not_empty') {
      valueInput = null;
    } else if (op == 'in' || op == 'not_in') {
      valueInput = Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final o in options)
            TogglePill(
              label: '${o['label']}',
              selected: selected.contains('${o['value']}'),
              onChanged: (v) {
                final next = [...selected];
                v ? next.add('${o['value']}') : next.remove('${o['value']}');
                _emit(next);
              },
            ),
        ],
      );
    } else if (op == 'between') {
      void emitBoth() => _emit([_parse(_a.text), _parse(_b.text)]);
      valueInput = Row(
        children: [
          Expanded(child: _input(_a, emitBoth, hint: 'From')),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('and'),
          ),
          Expanded(child: _input(_b, emitBoth, hint: 'To')),
        ],
      );
    } else {
      valueInput = _input(
        _a,
        () => _emit(_parse(_a.text)),
        hint: op.endsWith('_days') ? 'Days' : null,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AppSelect<String>(
                  dense: true,
                  value: '${widget.filter['field']}',
                  options: [
                    for (final f in widget.fields)
                      SelectOption('${f['key']}', '${f['label']}'),
                  ],
                  onChanged: (k) {
                    final f = widget.fields.firstWhere((x) => x['key'] == k);
                    final first = _opsFor('${f['type']}').first;
                    widget.onChanged({
                      'field': k,
                      'op': first,
                      'value': _defaultValue(first),
                    });
                  },
                ),
              ),
              IconButton(
                tooltip: 'Remove filter',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.inkFaint,
                ),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: AppSelect<String>(
              dense: true,
              value: ops.contains(op) ? op : ops.first,
              options: [
                for (final o in ops) SelectOption(o, _opLabels[o] ?? o),
              ],
              onChanged:
                  (o) => widget.onChanged({
                    ...widget.filter,
                    'op': o,
                    'value': _defaultValue(o),
                  }),
            ),
          ),
          if (valueInput != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 6),
              child: SizedBox(width: double.infinity, child: valueInput),
            ),
        ],
      ),
    );
  }
}
