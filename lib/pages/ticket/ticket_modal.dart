import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';

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
  String? _selectedSubscription;
  final _descriptionController = TextEditingController();
  final List<PlatformFile> _attachedFiles = [];

  List<String> _ticketTypes = [];
  Map<String, dynamic> _contacts = {};
  List<String> _subscriptions = [];

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
      // Fetch ticket categories
      final categoriesData = await ApiService.getCategories();
      setState(() {
        _ticketTypes = List<String>.from(
          categoriesData['data'].map((item) => item['name']),
        );
      });

      // Fetch agents
      final agentsData = await ApiService.getAgents();
      setState(() {
        _contacts = Map.fromEntries(
          (agentsData['data'] as List).map(
            (agent) => MapEntry(agent['name'] as String, agent['id'] as int),
          ),
        );
      });

      // Fetch subscriptions
      final subscriptionsData = await ApiService.getSubscriptions();
      setState(() {
        _subscriptions = List<String>.from(
          subscriptionsData['data'].map((item) => item['nickname']),
        );
      });
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
        setState(() {
          _attachedFiles.addAll(result.files);
        });
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
      final newTicket = {
        'type': _selectedTicketType,
        'contact': _contacts[_selectedContact], // Agent ID for database
        'contact_name': _selectedContact, // Agent name for display
        'subscription': _selectedSubscription,
        'description': _descriptionController.text,
        'user_id': widget.userId,
        'status': 'open',
        'attachments': null,
      };

      if (_attachedFiles.isEmpty) {
        // Show confirmation dialog if no files are attached
        if (!mounted) return;
        final shouldContinue = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('No Files Attached'),
              content: const Text(
                'You haven\'t attached any files. Do you want to continue without attachments?',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false); // Don't continue
                  },
                  child: const Text('Go Back'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true); // Continue
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );

        if (shouldContinue != true) return;
      }

      // Submit the ticket
      print('Submitting ticket data: $newTicket'); // Debug log
      try {
        await widget.onConfirm(newTicket);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating ticket: $e'),
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
            padding: const EdgeInsets.all(24.0),
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
                const SizedBox(height: 24),

                // Loading or Error State
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  )
                else ...[
                  // Ticket Type Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Ticket Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
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
                  const SizedBox(height: 16),

                  // Contact Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Contact',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
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
                  const SizedBox(height: 16),

                  // Subscription Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Subscription',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    value: _selectedSubscription,
                    items:
                        _subscriptions.map((subscription) {
                          return DropdownMenuItem(
                            value: subscription,
                            child: Text(subscription),
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
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    maxLines: 4,
                    validator:
                        (value) =>
                            value!.isEmpty
                                ? 'Please enter a description'
                                : null,
                  ),
                  const SizedBox(height: 16),

                  // Attachments
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Attachments',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      TextButton.icon(
                        onPressed: _pickFiles,
                        icon: const Icon(Icons.attach_file, size: 20),
                        label: const Text('Add File'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Only PDF, DOCX, JPG, JPEG, or PNG files allowed',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),

                  // Display attached files
                  if (_attachedFiles.isNotEmpty) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _attachedFiles.length,
                        itemBuilder: (context, index) {
                          final file = _attachedFiles[index];
                          return ListTile(
                            leading: Icon(
                              _getFileIcon(file.extension),
                              color: Theme.of(context).primaryColor,
                            ),
                            title: Text(
                              file.name,
                              style: const TextStyle(fontSize: 14),
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
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Container(
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
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 30),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.onCancel != null)
                        TextButton(
                          onPressed: widget.onCancel,
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _submitTicket,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: const Text(
                          'Create Ticket',
                          style: TextStyle(fontSize: 16),
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
