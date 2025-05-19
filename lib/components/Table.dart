// ignore: file_names
import 'package:flutter/material.dart';

class ReusableTable extends StatefulWidget {
  final List<String> headers;
  final List<Map<String, dynamic>> data;
  final Function(Map<String, dynamic>)? onRowTap;

  const ReusableTable({
    super.key,
    required this.headers,
    required this.data,
    this.onRowTap,
  });

  @override
  State<ReusableTable> createState() => _ReusableTableState();
}

class _ReusableTableState extends State<ReusableTable> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  late List<Map<String, dynamic>> _sortedData;
  int _currentPage = 0;
  static const int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _initSortedData();
  }

  @override
  void didUpdateWidget(ReusableTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      setState(() {
        _initSortedData();
        _currentPage = 0; // Reset to first page when data changes
      });
    }
  }

  void _initSortedData() {
    if (widget.data.isEmpty) {
      _sortedData = [];
      return;
    }

    _sortedData = List.from(widget.data);
    if (_sortColumnIndex != null) {
      _sort(_sortColumnIndex!, _sortAscending);
    }
  }

  void _sort(int columnIndex, bool ascending) {
    if (_sortedData.isEmpty) return;

    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;

      _sortedData.sort((a, b) {
        final aValue = a[widget.headers[columnIndex]]?.toString() ?? '';
        final bValue = b[widget.headers[columnIndex]]?.toString() ?? '';

        return ascending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
      });
    });
  }

  List<Map<String, dynamic>> get _paginatedData {
    if (_sortedData.isEmpty) return [];

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, _sortedData.length);
    return _sortedData.sublist(startIndex, endIndex);
  }

  int get _pageCount => (_sortedData.length / _rowsPerPage).ceil();

  void _nextPage() {
    if (_currentPage < _pageCount - 1) {
      setState(() {
        _currentPage++;
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    }
  }

  void _showDescriptionDialog(BuildContext context, String description) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        description,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSortableHeader(String text, int columnIndex) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        if (_sortColumnIndex == columnIndex)
          Icon(
            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16,
            color: Colors.blue,
          )
        else
          const Icon(Icons.swap_vert, size: 16, color: Colors.grey),
      ],
    );
  }

  Widget _buildTableCell(String value, String header, BuildContext context) {
    if (header == 'Description') {
      final isLongText = value.length > 100;
      return Container(
        constraints: const BoxConstraints(maxWidth: 200, minWidth: 200),
        child: InkWell(
          onTap: () => _showDescriptionDialog(context, value),
          child: Text(
            isLongText ? '${value.substring(0, 100)}...' : value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87, // Changed to regular text color
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      );
    }

    // For other columns
    return Text(value, style: const TextStyle(fontSize: 14));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              horizontalMargin: 12,
              sortColumnIndex:
                  _sortColumnIndex != null ? _sortColumnIndex! + 1 : null,
              sortAscending: _sortAscending,
              headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
              columns: [
                const DataColumn(
                  label: Text(
                    'No.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...widget.headers.asMap().entries.map((entry) {
                  return DataColumn(
                    label: _buildSortableHeader(entry.value, entry.key),
                    onSort:
                        (columnIndex, ascending) =>
                            _sort(columnIndex - 1, ascending),
                  );
                }).toList(),
              ],
              rows:
                  _paginatedData.asMap().entries.map((entry) {
                    final rowData = entry.value;
                    return DataRow(
                      onSelectChanged:
                          widget.onRowTap != null
                              ? (_) => widget.onRowTap!(rowData)
                              : null,
                      cells: [
                        DataCell(
                          Text(
                            '${(_currentPage * _rowsPerPage) + entry.key + 1}',
                            style: const TextStyle(
                              color: Color(0xFF133343),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        ...widget.headers
                            .map(
                              (header) => DataCell(
                                _buildTableCell(
                                  rowData[header]?.toString() ?? '',
                                  header,
                                  context,
                                ),
                              ),
                            )
                            .toList(),
                      ],
                    );
                  }).toList(),
            ),
          ),
        ),
        if (_sortedData.length > _rowsPerPage)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0 ? _previousPage : null,
                  color:
                      _currentPage > 0 ? const Color(0xFF133343) : Colors.grey,
                  tooltip: 'Previous page',
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Page ${_currentPage + 1} of $_pageCount',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF133343),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < _pageCount - 1 ? _nextPage : null,
                  color:
                      _currentPage < _pageCount - 1
                          ? const Color(0xFF133343)
                          : Colors.grey,
                  tooltip: 'Next page',
                ),
              ],
            ),
          ),
      ],
    );
  }
}
