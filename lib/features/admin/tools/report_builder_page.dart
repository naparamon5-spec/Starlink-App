import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This report isn't available to you")),
      );
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
    if (_source.isEmpty) return;
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
      } else {
        _result = null;
        _runError = res['message']?.toString() ?? "The report couldn't be run";
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

  void _export() {
    final cols = _resultColumns;
    if (cols.isEmpty) return;
    final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    exportSheets(context, 'report-${_source}-$stamp.xlsx', [
      ExportSheet(
        (_src?['label'] ?? 'Report').toString(),
        [for (final c in cols) '${c['label']}'],
        [
          for (final r in _resultRows)
            [
              for (final c in cols)
                _numeric.contains(c['type'])
                    ? (num.tryParse('${r[c['key']] ?? ''}') ?? r[c['key']])
                    : r[c['key']],
            ],
        ],
      ),
    ]);
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Builder'),
        actions: [
          IconButton(
            tooltip: 'Export to Excel',
            onPressed: _resultRows.isEmpty ? null : _export,
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      bottomNavigationBar:
          _source.isEmpty
              ? null
              : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: ElevatedButton.icon(
                    onPressed: _running ? null : _run,
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
              ),
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
              : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _section('READY-MADE REPORTS'),
                  FadingHScroll(
                    child: Row(
                      children: [
                        for (var i = 0; i < _templates.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          _TemplateCard(
                            t: _templates[i],
                            onTap: () => _applyTemplate(_templates[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _section('SOURCE'),
                  _card(
                    AppSelect<String>(
                      value: _source.isEmpty ? null : _source,
                      hint: 'What do you want to report on?',
                      options: [
                        for (final s in _sources)
                          SelectOption('${s['key']}', '${s['label']}'),
                      ],
                      onChanged: _pickSource,
                    ),
                    note: _src?['description']?.toString(),
                  ),
                  if (_source.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildFilters(),
                    const SizedBox(height: 16),
                    _buildGrouping(),
                    if (!_grouped) ...[
                      const SizedBox(height: 16),
                      _buildColumns(),
                    ],
                    const SizedBox(height: 16),
                    _buildSortLimit(),
                    const SizedBox(height: 20),
                    _buildResult(),
                  ],
                ],
              ),
    );
  }

  Widget _buildColumns() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('COLUMNS'),
        _card(
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in _fields)
                TogglePill(
                  label: '${f['label']}',
                  selected: _columns.contains(f['key']),
                  onChanged:
                      (v) => setState(() {
                        if (v) {
                          _columns.add(f['key']);
                        } else {
                          _columns.remove(f['key']);
                        }
                      }),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _section('FILTERS')),
            TextButton.icon(
              onPressed: _addFilter,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add filter'),
            ),
          ],
        ),
        if (_filters.isEmpty)
          _card(
            const Text(
              'No filters: every row is included.',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
          )
        else
          for (var i = 0; i < _filters.length; i++) ...[
            _FilterEditor(
              key: ValueKey('f$i-${_filters[i]['field']}-${_filters[i]['op']}'),
              filter: _filters[i],
              fields: _fields,
              onChanged: (f) => setState(() => _filters[i] = f),
              onRemove: () => setState(() => _filters.removeAt(i)),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _buildGrouping() {
    final groupable = _fields.where((f) => f['type'] != 'id').toList();
    final measurable =
        _fields.where((f) => _measurable.contains(f['type'])).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _section('GROUP BY')),
            if (_groupBy.length < 2)
              TextButton.icon(
                onPressed: _addGroup,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Group'),
              ),
          ],
        ),
        if (_groupBy.isEmpty)
          _card(
            const Text(
              'Not grouped: one row per record.',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
          )
        else
          _card(
            Column(
              children: [
                for (var i = 0; i < _groupBy.length; i++)
                  Row(
                    children: [
                      Expanded(
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
                      if (_dates.contains(
                        _field(_groupBy[i]['field'])?['type'],
                      )) ...[
                        const SizedBox(width: 8),
                        AppSelect<String>(
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
                      ],
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _removeGroup(i),
                      ),
                    ],
                  ),
                if (measurable.isNotEmpty) ...[
                  const Divider(),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Totals (besides the count)',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed:
                            () => setState(
                              () => _measures.add({
                                'field': measurable.first['key'],
                                'fn': 'sum',
                              }),
                            ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Total'),
                      ),
                    ],
                  ),
                  for (var i = 0; i < _measures.length; i++)
                    Row(
                      children: [
                        AppSelect<String>(
                          dense: true,
                          value: _measures[i]['fn'],
                          options: const [
                            SelectOption('sum', 'Sum'),
                            SelectOption('avg', 'Average'),
                            SelectOption('min', 'Min'),
                            SelectOption('max', 'Max'),
                          ],
                          onChanged:
                              (v) => setState(() => _measures[i]['fn'] = v),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppSelect<String>(
                            dense: true,
                            value: _measures[i]['field'],
                            options: [
                              for (final f in measurable)
                                SelectOption('${f['key']}', '${f['label']}'),
                            ],
                            onChanged:
                                (v) =>
                                    setState(() => _measures[i]['field'] = v),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed:
                              () => setState(() => _measures.removeAt(i)),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSortLimit() {
    // Sort keys: output columns of the last run, else the chosen columns.
    final keys = <String, String>{
      if (_resultColumns.isNotEmpty)
        for (final c in _resultColumns) '${c['key']}': '${c['label']}'
      else if (!_grouped)
        for (final k in _columns) k: '${_field(k)?['label'] ?? k}'
      else ...{
        'count': 'Count',
        for (var i = 0; i < _groupBy.length; i++)
          'g$i':
              '${_field(_groupBy[i]['field'])?['label'] ?? 'Group ${i + 1}'}',
      },
    };
    final sortKey = _sort?['key']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('SORT & LIMIT'),
        _card(
          Row(
            children: [
              Expanded(
                child: AppSelect<String>(
                  dense: true,
                  value: keys.containsKey(sortKey) ? sortKey : null,
                  hint: 'Sort by',
                  options: [
                    for (final e in keys.entries) SelectOption(e.key, e.value),
                  ],
                  onChanged:
                      (v) => setState(
                        () => _sort = {'key': v, 'dir': _sort?['dir'] ?? 'asc'},
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Direction',
                icon: Icon(
                  _sort?['dir'] == 'desc'
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  size: 18,
                ),
                onPressed:
                    _sort == null
                        ? null
                        : () => setState(
                          () =>
                              _sort = {
                                ..._sort!,
                                'dir': _sort!['dir'] == 'desc' ? 'asc' : 'desc',
                              },
                        ),
              ),
              const SizedBox(width: 8),
              AppSelect<int>(
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
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    if (_runError != null) {
      return _card(
        Text(
          _runError!,
          style: const TextStyle(color: AppColors.dangerInk, fontSize: 13),
        ),
      );
    }
    if (_result == null) return const SizedBox.shrink();
    final cols = _resultColumns;
    final rows = _resultRows;
    final total = int.tryParse('${_result!['total']}') ?? rows.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('RESULT'),
        Text(
          _result!['truncated'] == true
              ? 'Showing ${rows.length} of $total rows. Raise the limit or add filters to see the rest.'
              : '$total row${total == 1 ? '' : 's'}',
          style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          _card(
            const Text(
              'No rows match.',
              style: TextStyle(color: AppColors.inkMuted),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 52,
                headingTextStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
                columns: [
                  for (final c in cols)
                    DataColumn(
                      label: Text('${c['label']}'),
                      numeric: _numeric.contains(c['type']),
                    ),
                ],
                rows: [
                  for (final r in rows.take(500))
                    DataRow(
                      cells: [
                        for (final c in cols)
                          DataCell(
                            Text(
                              _fmt(r[c['key']], '${c['type']}'),
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        if (rows.length > 500)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'The first 500 rows are shown; export to see them all.',
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
          ),
      ],
    );
  }

  static String _fmt(dynamic v, String type) {
    if (v == null || '$v'.isEmpty) return '—';
    final n = num.tryParse('$v');
    if (n != null) {
      if (type == 'money')
        return NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(n);
      if (type == 'gb') return '${NumberFormat('#,##0.##').format(n)} GB';
      if (type == 'percent') return '${NumberFormat('#,##0.#').format(n)}%';
      if (type == 'number') return NumberFormat('#,##0.##').format(n);
    }
    return '$v';
  }

  Widget _section(String t) => SectionHeading(t);

  Widget _card(Widget child, {String? note}) => AppCard(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child,
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            note,
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
          ),
        ],
      ],
    ),
  );
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.t, required this.onTap});
  final Map<String, dynamic> t;
  final VoidCallback onTap;

  static const _icons = {
    'tickets': Icons.confirmation_number_outlined,
    'service_lines': Icons.satellite_alt_outlined,
    'billing': Icons.receipt_long_outlined,
    'usage_cycles': Icons.data_usage_rounded,
    'daily_usage': Icons.show_chart_rounded,
    'accounts': Icons.groups_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final source = '${(t['request'] as Map)['source']}';
    return SizedBox(
      width: 210,
      height: 132,
      child: Material(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.lineSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        _icons[source] ?? Icons.table_chart_outlined,
                        size: 17,
                        color: AppColors.brand,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.play_circle_outline_rounded,
                      size: 18,
                      color: AppColors.inkFaint,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${t['name']}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    '${t['description']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.inkMuted,
                      height: 1.3,
                    ),
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
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 5,
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
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
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
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          if (valueInput != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: valueInput,
            ),
        ],
      ),
    );
  }
}
