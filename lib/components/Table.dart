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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        horizontalMargin: 12,
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
                              (header) => DataCell(
                                _buildTableCell(
                                  row[header]?.toString() ?? '',
                                  header,
                                  context,
                                ),
                              ),
                            )
                            .toList(),
                  ),
                )
                .toList(),
      ),
    );
  }
}
