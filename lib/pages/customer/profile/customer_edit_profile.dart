import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../services/api_service.dart';

/// Customer Edit Profile Screen
///
/// This screen allows customers to edit their profile information including:
/// - First Name, Last Name, Middle Name (optional)
/// - Profile image upload with the following features:
///   * Image picker from gallery
///   * File size validation (max 5MB)
///   * Local storage of images in app documents directory
///   * Persistent storage of image path in SharedPreferences
///   * Loading states during image processing
///   * Long press gesture for image options (take photo, choose from gallery, remove)
///   * Fallback to default person icon when no image is selected
///
/// The screen provides a modern, user-friendly interface with proper validation
/// and feedback mechanisms for all user interactions.

class EditProfileScreen extends StatefulWidget {
  final Function(Map<String, String>)? onProfileUpdated;

  const EditProfileScreen({super.key, this.onProfileUpdated});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late SharedPreferences _prefs;

  // Profile Information
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _emailController = TextEditingController();

  // Profile Image
  File? _selectedImageFile;
  String? _savedImagePath;
  bool _isImageLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    _prefs = await SharedPreferences.getInstance();
    int? userId = _prefs.getInt('user_id');
    String? firstName;
    String? lastName;
    String? middleName;
    String? email;
    if (userId != null) {
      try {
        final response = await ApiService.getCurrentUser(userId);
        if (response['status'] == 'success' && response['data'] != null) {
          final userData = response['data'];
          firstName =
              userData['first_name'] ??
              userData['name'] ??
              _prefs.getString('firstName') ??
              'John';
          lastName =
              userData['last_name'] ?? _prefs.getString('lastName') ?? 'Doe';
          middleName =
              userData['middle_name'] ?? _prefs.getString('middleName') ?? '';
          email =
              userData['email'] ??
              _prefs.getString('email') ??
              'johndoe@example.com';
        }
      } catch (e) {
        firstName = _prefs.getString('firstName') ?? 'John';
        lastName = _prefs.getString('lastName') ?? 'Doe';
        middleName = _prefs.getString('middleName') ?? '';
        email = _prefs.getString('email') ?? 'johndoe@example.com';
      }
    } else {
      firstName = _prefs.getString('firstName') ?? 'John';
      lastName = _prefs.getString('lastName') ?? 'Doe';
      middleName = _prefs.getString('middleName') ?? '';
      email = _prefs.getString('email') ?? 'johndoe@example.com';
    }
    setState(() {
      _firstNameController.text = firstName!;
      _lastNameController.text = lastName!;
      _middleNameController.text = middleName!;
      _emailController.text = email!;
      _savedImagePath = _prefs.getString('profileImagePath');
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      int? userId = _prefs.getInt('user_id');
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User ID not found.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final updateData = {
        'user_id': userId,
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'middle_name': _middleNameController.text,
      };
      bool updateSuccess = false;
      String errorMsg = '';
      try {
        final response = await ApiService.updateUserProfile(updateData);
        if (response['status'] == 'success') {
          updateSuccess = true;
          await _prefs.setString('firstName', _firstNameController.text);
          await _prefs.setString('lastName', _lastNameController.text);
          await _prefs.setString('middleName', _middleNameController.text);
        } else {
          errorMsg = response['message'] ?? 'Failed to update profile.';
        }
      } catch (e) {
        errorMsg = e.toString();
      }
      if (mounted) {
        if (updateSuccess) {
          Navigator.pop(context, {
            'firstName': _firstNameController.text,
            'lastName': _lastNameController.text,
            'middleName': _middleNameController.text,
            'profileImagePath': _savedImagePath,
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Profile updated successfully!',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF133343),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update profile: $errorMsg'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      setState(() {
        _isImageLoading = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Validate file size (max 5MB)
        const maxFileSize = 5 * 1024 * 1024; // 5MB
        if (file.size > maxFileSize) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image size must be less than 5MB'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        if (file.bytes != null) {
          // Process image in background to avoid blocking main thread
          final processedImage = await _compressImage(file.bytes!);

          if (processedImage != null) {
            final fileName =
                'profile_image_${DateTime.now().millisecondsSinceEpoch}.jpg';

            // Save image in background
            final savedFile = await _saveImageInBackground(
              processedImage,
              fileName,
            );

            if (savedFile != null && mounted) {
              setState(() {
                _selectedImageFile = savedFile;
                _savedImagePath = savedFile.path;
              });
              // Save image path to SharedPreferences
              await _prefs.setString('profileImagePath', savedFile.path);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Image selected successfully'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to save image'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to process image'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImageLoading = false;
        });
      }
    }
  }

  Future<void> _removeProfileImage() async {
    // Remove from SharedPreferences first
    await _prefs.remove('profileImagePath');

    // Update state only once
    if (mounted) {
      setState(() {
        _selectedImageFile = null;
        _savedImagePath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile image removed'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              if (_selectedImageFile != null || _savedImagePath != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfileImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
        elevation: 2,
        backgroundColor: const Color(0xFF133343),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Image Section
                Center(
                  child: GestureDetector(
                    onLongPress: _showImageOptions,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).primaryColor,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: _getProfileImage(),
                            backgroundColor: Colors.grey[200],
                            child:
                                _isImageLoading
                                    ? const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF133343),
                                      ),
                                    )
                                    : _getProfileImage() == null
                                    ? const Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Color(0xFF133343),
                                    )
                                    : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon:
                                  _isImageLoading
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                      : const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                              onPressed:
                                  _isImageLoading ? null : _showImageOptions,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Long press for more options',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Profile Information Section
                _buildSectionTitle('Profile Information'),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _firstNameController,
                  label: 'First Name',
                  icon: Icons.person_outline,
                  validator:
                      (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _lastNameController,
                  label: 'Last Name',
                  icon: Icons.person_outline,
                  validator:
                      (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _middleNameController,
                  label: 'Middle Name (Optional)',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                  readOnly: true,
                ),

                const SizedBox(height: 32),
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF133343),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF133343),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
      ),
      validator: validator,
      readOnly: readOnly,
    );
  }

  ImageProvider? _getProfileImage() {
    try {
      if (_selectedImageFile != null) {
        return FileImage(_selectedImageFile!);
      } else if (_savedImagePath != null) {
        final savedFile = File(_savedImagePath!);
        if (savedFile.existsSync()) {
          return FileImage(savedFile);
        }
      }
      return null;
    } catch (e) {
      print('Error loading profile image: $e');
      return null;
    }
  }

  /// Compresses and resizes image to improve performance
  Future<Uint8List?> _compressImage(Uint8List imageBytes) async {
    try {
      // Compress image to reduce file size and memory usage
      final compressedBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minHeight: 400, // Resize to reasonable dimensions
        minWidth: 400,
        quality: 85, // Good quality with reasonable file size
        format: CompressFormat.jpeg,
      );

      print('Original size: ${imageBytes.length} bytes');
      print('Compressed size: ${compressedBytes.length} bytes');
      print(
        'Compression ratio: ${(1 - compressedBytes.length / imageBytes.length) * 100}%',
      );

      return compressedBytes;
    } catch (e) {
      print('Error compressing image: $e');
      // Fallback to original bytes if compression fails
      return imageBytes;
    }
  }

  /// Saves image file in background to avoid blocking main thread
  Future<File?> _saveImageInBackground(
    Uint8List imageBytes,
    String fileName,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final savedFile = File('${directory.path}/$fileName');
      await savedFile.writeAsBytes(imageBytes);
      return savedFile;
    } catch (e) {
      print('Error saving image: $e');
      return null;
    }
  }
}
