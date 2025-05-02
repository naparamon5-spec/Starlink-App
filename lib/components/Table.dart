// ignore: file_names
import 'package:flutter/material.dart';

class ReusableTable extends StatefulWidget {
  final List<String> headers;
  final List<Map<String, dynamic>> data;

  const ReusableTable({super.key, required this.headers, required this.data});

  @override
  State<ReusableTable> createState() => _ReusableTableState();
}

class _ReusableTableState extends State<ReusableTable> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  late List<Map<String, dynamic>> _sortedData;

  @override
  void initState() {
    super.initState();
    _initSortedData();
  }

  @override
  void didUpdateWidget(ReusableTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      _initSortedData();
    }
  }

  void _initSortedData() {
    _sortedData = List.from(widget.data);
    if (_sortColumnIndex != null) {
      _sort(_sortColumnIndex!, _sortAscending);
    }
  }

  void _sort(int columnIndex, bool ascending) {
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

  Widget _buildSortableHeader(String text, int columnIndex) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: _sortColumnIndex,
        sortAscending: _sortAscending,
        headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
        columns:
            widget.headers.asMap().entries.map((entry) {
              return DataColumn(
                label: _buildSortableHeader(entry.value, entry.key),
                onSort:
                    (columnIndex, ascending) => _sort(columnIndex, ascending),
              );
            }).toList(),
        rows:
            _sortedData
                .map(
                  (row) => DataRow(
                    cells:
                        widget.headers
                            .map(
                              (header) =>
                                  DataCell(Text(row[header]?.toString() ?? '')),
                            )
                            .toList(),
                  ),
                )
                .toList(),
      ),
    );
  }
}
