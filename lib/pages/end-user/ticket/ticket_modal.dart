import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/api_service.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

class NewTicketModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onConfirm;
  final VoidCallback? onCancel;
  final int userId;

  const NewTicketModal({
    super.key,
    required this.onConfirm,
    this.onCancel,
    required this.userId,
  });

  @override
  _NewTicketModalState createState() => _NewTicketModalState();
}

class _NewTicketModalState extends State<NewTicketModal> {
  String? _selectedTicketType;
  String? _selectedContact;
  Map<String, dynamic>? _selectedSubscription;
  final _descriptionController = TextEditingController();
  final List<PlatformFile> _attachedFiles = [];

  List<String> _ticketTypes = [];
  Map<String, dynamic> _contacts = {};
  List<Map<String, dynamic>> _subscriptions = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // First get the current user to get their EU code
      final userData = await ApiService.getCurrentUser(widget.userId);

      if (userData['status'] != 'success' || userData['data'] == null) {
        throw Exception('Failed to get user data');
      }

      final user = userData['data'];

      // Try different possible EU code field names
      String? euCode;
      if (user['eu_code'] != null) {
        euCode = user['eu_code'].toString();
      } else if (user['com_eu_code'] != null) {
        euCode = user['com_eu_code'].toString();
      } else if (user['customer_code'] != null) {
        euCode = user['customer_code'].toString();
      }

      if (euCode == null || euCode.isEmpty) {
        // If no EU code found in user data, try to get it from end_users table
        try {
          final endUserData = await ApiService.getEndUserByUserId(
            widget.userId,
          );

          if (endUserData['status'] == 'success' &&
              endUserData['data'] != null) {
            euCode =
                endUserData['data']['eu_code']?.toString() ??
                endUserData['data']['customer_code']?.toString();
          }
        } catch (e) {
          // Continue with the flow even if end user data fails
        }
      }

      if (euCode == null || euCode.isEmpty) {
        throw Exception(
          'Could not find EU code for user. Please contact support.',
        );
      }

      // Fetch ticket categories
      final categoriesData = await ApiService.getCategories();
      setState(() {
        _ticketTypes = List<String>.from(
          categoriesData['data'].map((item) => item['name']),
        );
      });

      // Fetch contacts using EU code
      final contactsData = await ApiService.getContactsByEuCode(euCode);
      if (contactsData['status'] == 'success') {
        setState(() {
          _contacts = Map.fromEntries(
            (contactsData['data'] as List).map(
              (contact) => MapEntry('${contact['name']}', contact['id']),
            ),
          );
        });
      } else {
        throw Exception(contactsData['message'] ?? 'Failed to fetch contacts');
      }

      // Fetch subscriptions using EU code
      final subscriptionsData = await ApiService.getSubscriptionsByEuCode(
        euCode,
      );
      if (subscriptionsData['status'] == 'success') {
        setState(() {
          _subscriptions = List<Map<String, dynamic>>.from(
            subscriptionsData['data'],
          );
        });
      } else {
        throw Exception(
          subscriptionsData['message'] ?? 'Failed to fetch subscriptions',
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching data: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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
        // Validate file sizes (e.g., max 5MB per file)
        const maxFileSize = 5 * 1024 * 1024; // 5MB in bytes
        final oversizedFiles = result.files.where(
          (file) => file.size > maxFileSize,
        );

        if (oversizedFiles.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Some files exceed the 5MB limit: ${oversizedFiles.map((f) => f.name).join(', ')}',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        setState(() {
          for (var file in result.files) {
            if (!_attachedFiles.any((f) => f.name == file.name)) {
              _attachedFiles.add(file);
            }
          }
        });

        // Show success message
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

  void _submitTicket() async {
    if (_selectedTicketType != null &&
        _selectedContact != null &&
        _selectedSubscription != null &&
        _descriptionController.text.isNotEmpty) {
      try {
        // Process attachments
        List<Map<String, dynamic>> attachmentsData = [];
        if (_attachedFiles.isNotEmpty) {
          for (var file in _attachedFiles) {
            if (file.bytes != null) {
              attachmentsData.add({
                'name': file.name,
                'data': base64Encode(file.bytes!),
                'type': file.extension ?? '',
                'size': file.size,
                'file_path': 'uploads/tickets/${file.name}',
              });
            }
          }
        }

        // Create the ticket with attachments
        final newTicket = {
          'user_id': widget.userId,
          'type': _selectedTicketType,
          'contact': _contacts[_selectedContact],
          'contact_name': _selectedContact,
          'subscription': _selectedSubscription?['serviceLineNumber'],
          'subject': _selectedSubscription?['nickname'],
          'description': _descriptionController.text,
          'status': 'open',
          'attachments': attachmentsData,
          'attachments_display': _attachedFiles
              .map((file) => file.name)
              .join(', '),
        };

        // Show loading indicator
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

        // Submit the ticket using ApiService
        final response = await ApiService.createTicket(newTicket);

        // Clear the loading snackbar
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();

        if (response['status'] == 'success') {
          final ticketId = response['data']['id'];

          // Upload attachments to the specified API
          if (_attachedFiles.isNotEmpty) {
            try {
              // Create multipart request
              final request = http.MultipartRequest(
                'POST',
                Uri.parse(
                  'https://starlink.ardentnetworks.com.ph/tickets/upload_attachment',
                ),
              );

              // Add basic fields
              request.fields['user_id'] = widget.userId.toString();
              request.fields['ticket_no'] = ticketId.toString();

              // Add files
              for (var file in _attachedFiles) {
                if (file.bytes != null) {
                  request.files.add(
                    http.MultipartFile.fromBytes(
                      'attachments[]',
                      file.bytes!,
                      filename: 'uploads/tickets/${file.name}',
                    ),
                  );
                }
              }

              // Send the request
              final streamedResponse = await request.send();
              final uploadResponse = await http.Response.fromStream(
                streamedResponse,
              );

              if (uploadResponse.statusCode != 200) {
                // Handle upload failure silently
              }
            } catch (e) {
              // Handle upload error silently
            }
          }

          // Format the ticket data to match the expected structure
          final formattedTicket = {
            'id': ticketId,
            'Status': 'OPEN',
            'Ticket Type': _selectedTicketType,
            'Contact': _selectedContact,
            'Subscription': _selectedSubscription?['nickname'],
            'Description': _descriptionController.text,
            'Created At': DateTime.now().toString(),
            'Attachments': _attachedFiles.map((file) => file.name).join(', '),
            'full_data': {
              ...response['data'],
              'status': 'OPEN',
              'created_at': DateTime.now().toString(),
              'attachments': attachmentsData,
              'user_id': widget.userId,
              'contact': _contacts[_selectedContact],
              'contact_name': _selectedContact,
              'type': _selectedTicketType,
              'subscription': _selectedSubscription?['serviceLineNumber'],
              'nickname': _selectedSubscription?['nickname'],
              'description': _descriptionController.text,
            },
          };

          // Call the parent's onConfirm callback with the formatted ticket
          widget.onConfirm(formattedTicket);

          // Close the modal and return the formatted ticket data
          if (mounted) {
            Navigator.of(context).pop(formattedTicket);
          }
        } else {
          throw Exception(response['message'] ?? 'Failed to create ticket');
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();

        // Format the error message
        String errorMessage = e.toString();
        if (errorMessage.contains('Integrity constraint violation')) {
          errorMessage = 'Error saving file information. Please try again.';
        } else if (errorMessage.contains('FormatException')) {
          errorMessage =
              'Server returned an invalid response. Please try again.';
        } else if (errorMessage.contains('<br />')) {
          errorMessage = 'Server error. Please try again later.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating ticket: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
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
                // Title
                Text(
                  'Create New Ticket',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),

                // Loading or Error State
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  )
                else ...[
                  // Ticket Type Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Ticket Type',
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
                        _ticketTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTicketType = value;
                      });
                    },
                    validator:
                        (value) =>
                            value == null
                                ? 'Please select a ticket type'
                                : null,
                  ),
                  const SizedBox(height: 12),

                  // Contact Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Contact',
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
                        _contacts.keys.map((contact) {
                          return DropdownMenuItem(
                            value: contact,
                            child: Text(contact),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedContact = value;
                      });
                    },
                    validator:
                        (value) =>
                            value == null ? 'Please select a contact' : null,
                  ),
                  const SizedBox(height: 12),

                  // Subscription Dropdown
                  DropdownButtonFormField<Map<String, dynamic>>(
                    decoration: InputDecoration(
                      labelText: 'Subscription',
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
                    ),
                    value: _selectedSubscription,
                    items:
                        _subscriptions.map((subscription) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: subscription,
                            child: Text(subscription['nickname'] ?? 'Unknown'),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSubscription = value;
                      });
                    },
                    validator:
                        (value) =>
                            value == null
                                ? 'Please select a subscription'
                                : null,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                    dropdownColor: Colors.white,
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
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
                    validator:
                        (value) =>
                            value!.isEmpty
                                ? 'Please enter a description'
                                : null,
                  ),
                  const SizedBox(height: 12),

                  // Attachments
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

                  // Display attached files
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
                              _attachedFiles.map((file) {
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
                                      onPressed:
                                          () => _removeFile(
                                            _attachedFiles.indexOf(file),
                                          ),
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
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No files attached. You can add files or continue without them.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Actions
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
                        onPressed: _submitTicket,
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
