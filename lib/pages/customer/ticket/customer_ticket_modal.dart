import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/api_service.dart';
import 'dart:convert';

class CustomerTicketModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onConfirm;
  final VoidCallback? onCancel;
  final int userId;

  const CustomerTicketModal({
    super.key,
    required this.onConfirm,
    this.onCancel,
    required this.userId,
  });

  @override
  _CustomerTicketModalState createState() => _CustomerTicketModalState();
}

class _CustomerTicketModalState extends State<CustomerTicketModal> {
  String? _selectedTicketType;
  String? _selectedContact;
  String? _selectedSubscription;
  final _descriptionController = TextEditingController();
  final List<PlatformFile> _attachedFiles = [];

  List<String> _ticketTypes = [];
  // FIX: value is dynamic so it can hold int (contact id) returned by getCustomers()
  Map<String, dynamic> _contacts = {};
  Map<String, String> _customerCodes = {};
  List<String> _subscriptions = [];

  bool _isLoading = true;
  bool _isLoadingSubscriptions = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _fetchTicketCategories();
      await _fetchCustomers();
    } catch (e) {
      debugPrint('Error in _fetchInitialData: $e');
      setState(() {
        _errorMessage = 'Error fetching data: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTicketCategories() async {
    try {
      // FIX: getCategories() now returns Map<String, dynamic> — use ['status'] / ['data']
      final categoriesData = await ApiService.getCategories();
      if (categoriesData['status'] == 'success' &&
          categoriesData['data'] != null) {
        final List<dynamic> data = categoriesData['data'];
        setState(() {
          _ticketTypes =
              data.map((item) => item['name']?.toString() ?? '').toList();
        });
      } else {
        throw Exception(
          categoriesData['message'] ?? 'Failed to load ticket categories',
        );
      }
    } catch (e) {
      throw Exception('Error fetching ticket categories: $e');
    }
  }

  Future<void> _fetchCustomers() async {
    try {
      final customersData = await ApiService.getCustomers();
      if (customersData['status'] == 'success' &&
          customersData['data'] != null) {
        final List<dynamic> customers = customersData['data'];
        setState(() {
          _contacts = Map.fromEntries(
            customers.map(
              (customer) => MapEntry(
                customer['name']?.toString() ?? '',
                int.tryParse(customer['id'].toString()) ?? customer['id'],
              ),
            ),
          );

          _customerCodes = Map.fromEntries(
            customers.map(
              (customer) => MapEntry(
                customer['name']?.toString() ?? '',
                customer['code']?.toString() ?? customer['id'].toString(),
              ),
            ),
          );
        });
      } else {
        throw Exception('Failed to load customers');
      }
    } catch (e) {
      throw Exception('Error fetching customers: $e');
    }
  }

  Future<void> _fetchSubscriptionsForCustomer(String customerCode) async {
    setState(() {
      _isLoadingSubscriptions = true;
      _subscriptions = [];
      _selectedSubscription = null;
    });

    try {
      final subscriptionsData = await ApiService.getSubscriptionsByCustomerCode(
        customerCode,
      );

      if (subscriptionsData['status'] == 'success' &&
          subscriptionsData['data'] != null) {
        setState(() {
          _subscriptions = List<String>.from(
            (subscriptionsData['data'] as List).map(
              (item) =>
                  item['nickname']?.toString() ??
                  item['name']?.toString() ??
                  'Unknown',
            ),
          );
        });
      } else {
        setState(() => _subscriptions = []);
      }
    } catch (e) {
      debugPrint('Error fetching subscriptions: $e');
      setState(() => _subscriptions = []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load subscriptions for this customer'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      setState(() => _isLoadingSubscriptions = false);
    }
  }

  void _onCustomerSelected(String? customerName) {
    setState(() {
      _selectedContact = customerName;
      _selectedSubscription = null;
    });

    if (customerName != null) {
      final customerCode = _customerCodes[customerName];
      if (customerCode != null) {
        _fetchSubscriptionsForCustomer(customerCode);
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (var file in result.files) {
            if (!_attachedFiles.any((f) => f.name == file.name)) {
              _attachedFiles.add(file);
            }
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${result.files.length} file(s)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _attachedFiles.removeAt(index);
    });
  }

  bool _isFormValid() {
    return _selectedTicketType != null &&
        _selectedContact != null &&
        _selectedSubscription != null &&
        _descriptionController.text.trim().isNotEmpty;
  }

  void _submitTicket() async {
    if (!_isFormValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      // Process attachments
      List<Map<String, dynamic>> attachmentsData = [];
      for (var file in _attachedFiles) {
        if (file.bytes != null) {
          attachmentsData.add({
            'name': file.name,
            'data': base64Encode(file.bytes!),
            'type': file.extension ?? '',
            'size': file.size,
          });
        }
      }

      final contactId = _contacts[_selectedContact];
      if (contactId == null) {
        throw Exception('Invalid contact selected');
      }

      // FIX: build the Map that the positional createTicket(Map) overload expects
      final newTicket = <String, dynamic>{
        'type': _selectedTicketType,
        'ticket_type': _selectedTicketType, // alias used by createTicketNamed
        'contact': contactId.toString(),
        'contact_name': _selectedContact,
        'subscription': _selectedSubscription,
        'subscription_id': _selectedSubscription, // alias
        'description': _descriptionController.text.trim(),
        'user_id': widget.userId,
        'status': 'open',
        'subject': _selectedTicketType,
        'attachments': attachmentsData,
        'attachments_display':
            _attachedFiles.isNotEmpty
                ? _attachedFiles.map((f) => f.name).join(', ')
                : 'No attachments',
      };

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(width: 16),
              Text('Creating ticket...'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 30),
        ),
      );

      // FIX: call the positional-Map overload — no named args needed
      final response = await ApiService.createTicket(newTicket);

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      if (response['status'] == 'success') {
        final formattedTicket = <String, dynamic>{
          'id': response['data']?['id'] ?? '',
          'Status': 'OPEN',
          'Ticket Type': newTicket['type'] ?? '',
          'Contact': newTicket['contact_name'] ?? '',
          'Subscription': newTicket['subscription'] ?? '',
          'Description': newTicket['description'] ?? '',
          'Created At': DateTime.now().toString(),
          'Attachments': newTicket['attachments_display'] ?? 'No attachments',
          'full_data': {
            ...newTicket,
            'id': response['data']?['id'] ?? '',
            'status': 'OPEN',
            'created_at': DateTime.now().toString(),
            'attachments': attachmentsData,
          },
          'forceRefresh': true,
        };

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket created successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        widget.onConfirm(formattedTicket);

        if (mounted) Navigator.of(context).pop(formattedTicket);
      } else {
        throw Exception(response['message'] ?? 'Failed to create ticket');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating ticket: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create New Ticket',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _fetchInitialData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Ticket Type Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Ticket Type *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    value: _selectedTicketType,
                    items:
                        _ticketTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      setState(() => _selectedTicketType = value);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Contact Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Contact *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    value: _selectedContact,
                    items:
                        _contacts.keys
                            .map(
                              (contact) => DropdownMenuItem(
                                value: contact,
                                child: Text(contact),
                              ),
                            )
                            .toList(),
                    onChanged: _onCustomerSelected,
                  ),
                  const SizedBox(height: 12),

                  // Subscription Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Subscription *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                      suffixIcon:
                          _isLoadingSubscriptions
                              ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                              : null,
                    ),
                    value: _selectedSubscription,
                    items:
                        _subscriptions.isEmpty && !_isLoadingSubscriptions
                            ? [
                              const DropdownMenuItem(
                                value: null,
                                child: Text(
                                  'No subscriptions available',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ]
                            : _subscriptions
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(
                                      s,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                    onChanged:
                        _isLoadingSubscriptions || _subscriptions.isEmpty
                            ? null
                            : (value) =>
                                setState(() => _selectedSubscription = value),
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                    dropdownColor: Colors.white,
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    maxLines: 4,
                    onChanged: (_) => setState(() {}), // refresh form validity
                  ),
                  const SizedBox(height: 12),

                  // Attachments header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Attachments',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickFiles,
                        icon: const Icon(Icons.attach_file, size: 18),
                        label: const Text(
                          'Add File',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Only PDF, DOCX, JPG, JPEG, or PNG files allowed',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 6),

                  // Attached files list
                  if (_attachedFiles.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.15,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children:
                              _attachedFiles.asMap().entries.map((entry) {
                                final index = entry.key;
                                final file = entry.value;
                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey[300]!,
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(
                                        _getFileIcon(file.extension),
                                        color: Theme.of(context).primaryColor,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      file.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${(file.size / 1024).toStringAsFixed(1)} KB',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.close, size: 20),
                                      onPressed: () => _removeFile(index),
                                      tooltip: 'Remove file',
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No files attached. You can add files or continue without them.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.onCancel != null)
                        TextButton(
                          onPressed: widget.onCancel,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isFormValid() ? _submitTicket : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                        ),
                        child: const Text(
                          'Create Ticket',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }
}
