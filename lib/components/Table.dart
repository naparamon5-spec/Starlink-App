// ignore: file_names
import 'package:flutter/material.dart';

class ReusableTable extends StatelessWidget {
  final List<String> headers;
  final List<Map<String, dynamic>> data;

  const ReusableTable({super.key, required this.headers, required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns:
            headers.map((header) => DataColumn(label: Text(header))).toList(),
        rows:
            data
                .map(
                  (row) => DataRow(
                    cells:
                        headers
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
