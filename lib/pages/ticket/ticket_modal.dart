import 'package:flutter/material.dart';

class NewTicketModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onConfirm;
  final VoidCallback? onCancel;

  const NewTicketModal({super.key, required this.onConfirm, this.onCancel});

  @override
  _NewTicketModalState createState() => _NewTicketModalState();
}

class _NewTicketModalState extends State<NewTicketModal> {
  String? _selectedTicketType;
  String? _selectedContact;
  String? _selectedSubscription;
  final _descriptionController = TextEditingController();
  final List<String> _attachedFiles = [];
  bool _isSubmitting = false;
  final _formKey = GlobalKey<FormState>();

  final List<String> _ticketTypes = [
    'Technical Support',
    'Billing Issue',
    'Feature Request',
    'Bug Report',
    'Other',
  ];
  final List<String> _contacts = ['John Doe', 'Jane Smith', 'Alex Johnson'];
  final List<String> _subscriptions = ['Basic', 'Pro', 'Enterprise'];

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      if (_selectedTicketType != null &&
          _selectedContact != null &&
          _selectedSubscription != null &&
          _descriptionController.text.isNotEmpty) {
        final newTicket = {
          'Type': _selectedTicketType,
          'Contact': _selectedContact,
          'Subscription': _selectedSubscription,
          'Description': _descriptionController.text,
          'Attachments':
              _attachedFiles.isEmpty ? 'None' : _attachedFiles.join(', '),
        };
        await widget.onConfirm(newTicket);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating ticket: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_isSubmitting,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
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
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
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
                  const SizedBox(height: 24),

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
                        _ticketTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                    onChanged:
                        _isSubmitting
                            ? null
                            : (value) {
                              setState(() => _selectedTicketType = value);
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
                        _contacts
                            .map(
                              (contact) => DropdownMenuItem(
                                value: contact,
                                child: Text(contact),
                              ),
                            )
                            .toList(),
                    onChanged:
                        _isSubmitting
                            ? null
                            : (value) {
                              setState(() => _selectedContact = value);
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
                        _subscriptions
                            .map(
                              (subscription) => DropdownMenuItem(
                                value: subscription,
                                child: Text(subscription),
                              ),
                            )
                            .toList(),
                    onChanged:
                        _isSubmitting
                            ? null
                            : (value) {
                              setState(() => _selectedSubscription = value);
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
                    enabled: !_isSubmitting,
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
                            value?.isEmpty ?? true
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
                        onPressed:
                            _isSubmitting
                                ? null
                                : () {
                                  // TODO: Implement file picker functionality
                                },
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
                    'Only PDF, DOCX, or JPG files allowed',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),

                  const SizedBox(height: 30),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.onCancel != null && !_isSubmitting)
                        TextButton(
                          onPressed: widget.onCancel,
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitTicket,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child:
                            _isSubmitting
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Text(
                                  'Create Ticket',
                                  style: TextStyle(fontSize: 16),
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
