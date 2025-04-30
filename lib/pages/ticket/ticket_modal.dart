import 'package:flutter/material.dart';

class NewTicketModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onConfirm;
  final VoidCallback? onCancel;

  const NewTicketModal({super.key, required this.onConfirm, this.onCancel});

  @override
  // ignore: library_private_types_in_public_api
  _NewTicketModalState createState() => _NewTicketModalState();
}

class _NewTicketModalState extends State<NewTicketModal> {
  String? _selectedTicketType;
  String? _selectedContact;
  String? _selectedSubscription;
  final _descriptionController = TextEditingController();
  final List<String> _attachedFiles = [];

  final List<String> _ticketTypes = [
    'Technical Support',
    'Billing Issue',
    'Feature Request',
    'Bug Report',
    'Other',
  ];
  final List<String> _contacts = ['John Doe', 'Jane Smith', 'Alex Johnson'];
  final List<String> _subscriptions = ['Basic', 'Pro', 'Enterprise'];

  void _submitTicket() {
    if (_selectedTicketType != null &&
        _selectedContact != null &&
        _selectedSubscription != null &&
        _descriptionController.text.isNotEmpty) {
      final newTicket = {
        'type': _selectedTicketType,
        'contact': _selectedContact,
        'subscription': _selectedSubscription,
        'description': _descriptionController.text,
        'attachments': _attachedFiles,
      };
      widget.onConfirm(newTicket);
      Navigator.of(context).pop();
    } else {
      // Show error or validation message if needed
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
              // ignore: deprecated_member_use
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
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedTicketType = value;
                    });
                  },
                  validator:
                      (value) =>
                          value == null ? 'Please select a ticket type' : null,
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
                      _contacts.map((contact) {
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
                          value == null ? 'Please select a subscription' : null,
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
                          value!.isEmpty ? 'Please enter a description' : null,
                ),
                const SizedBox(height: 16),

                // Attachments
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Attachments',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
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
            ),
          ),
        ),
      ),
    );
  }
}

// Usage example:
// showDialog(
//   context: context,
//   builder: (context) => NewTicketModal(
//     onConfirm: (ticketDetails) {
//       // Handle ticket creation
//       Navigator.of(context).pop();
//     },
//     onCancel: () {
//       Navigator.of(context).pop();
//     },
//   ),
// );
