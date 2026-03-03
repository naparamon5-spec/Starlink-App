import 'package:flutter/material.dart';
import 'dart:math' as math;

class MyTicketsPage extends StatefulWidget {
  const MyTicketsPage();

  @override
  State<MyTicketsPage> createState() => MyTicketsPageState();
}

class MyTicketsPageState extends State<MyTicketsPage> {
  int _filterIndex = 0;
  final _filters = ['All', 'Open', 'In Progress', 'Resolved', 'Pending'];

  static const _tickets = [
    TicketItem(
      id: 'TKT-2041',
      title: 'Cannot login after password reset',
      company: 'Acme Corp',
      priority: 'High',
      status: 'Open',
      time: '10 min ago',
      priorityColor: Color(0xFFF43F5E),
      statusColor: Color(0xFFF59E0B),
    ),
    TicketItem(
      id: 'TKT-2040',
      title: 'Dashboard widget not loading data',
      company: 'NovaTech Inc.',
      priority: 'Medium',
      status: 'In Progress',
      time: '45 min ago',
      priorityColor: Color(0xFFF59E0B),
      statusColor: Color(0xFF6366F1),
    ),
    TicketItem(
      id: 'TKT-2039',
      title: 'Bulk export returns empty file',
      company: 'PixelWave Co.',
      priority: 'High',
      status: 'Open',
      time: '1 hour ago',
      priorityColor: Color(0xFFF43F5E),
      statusColor: Color(0xFFF59E0B),
    ),
    TicketItem(
      id: 'TKT-2038',
      title: 'Email notifications delayed',
      company: 'BlueSky Ltd.',
      priority: 'Low',
      status: 'Resolved',
      time: '1 hour ago',
      priorityColor: Color(0xFF10B981),
      statusColor: Color(0xFF10B981),
    ),
    TicketItem(
      id: 'TKT-2036',
      title: 'API key regeneration failing',
      company: 'DataStream AI',
      priority: 'Medium',
      status: 'Pending',
      time: '3 hours ago',
      priorityColor: Color(0xFFF59E0B),
      statusColor: Color(0xFF64748B),
    ),
    TicketItem(
      id: 'TKT-2033',
      title: 'User role permissions not saving',
      company: 'CloudSync GmbH',
      priority: 'Medium',
      status: 'In Progress',
      time: '5 hours ago',
      priorityColor: Color(0xFFF59E0B),
      statusColor: Color(0xFF6366F1),
    ),
  ];

  List<TicketItem> get _filtered =>
      _filterIndex == 0
          ? _tickets
          : _tickets.where((t) => t.status == _filters[_filterIndex]).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          color: const Color(0xFF0F1923),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Tickets',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.add, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Create Ticket',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      _filters.asMap().entries.map((e) {
                        final sel = e.key == _filterIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _filterIndex = e.key),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  sel
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFF162032),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    sel
                                        ? const Color(0xFF6366F1)
                                        : const Color(0xFF1E3050),
                              ),
                            ),
                            child: Text(
                              e.value,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    sel
                                        ? Colors.white
                                        : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              _filtered.isEmpty
                  ? Center(
                    child: Text(
                      'No ${_filters[_filterIndex]} tickets',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                      ),
                    ),
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => TicketCard(data: _filtered[i]),
                  ),
        ),
      ],
    );
  }
}

class TicketItem {
  final String id, title, company, priority, status, time;
  final Color priorityColor, statusColor;
  const TicketItem({
    required this.id,
    required this.title,
    required this.company,
    required this.priority,
    required this.status,
    required this.time,
    required this.priorityColor,
    required this.statusColor,
  });
}

class TicketCard extends StatelessWidget {
  final TicketItem data;
  const TicketCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF162032),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3050)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                data.id,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: data.priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.priority,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: data.priorityColor,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: data.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.status,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: data.statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.business_outlined,
                size: 12,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Text(
                data.company,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const Spacer(),
              const Icon(Icons.access_time, size: 11, color: Color(0xFF64748B)),
              const SizedBox(width: 3),
              Text(
                data.time,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
