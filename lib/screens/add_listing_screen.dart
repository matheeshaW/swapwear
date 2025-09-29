import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AddListingScreen extends StatefulWidget {
  final String userId;
  const AddListingScreen({super.key, required this.userId});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  String _selectedCategory = 'Tops';
  final List<String> _categories = [
    'Tops',
    'Bottoms',
    'Outerwear',
    'Footwear',
    'Accessories',
  ];
  String _selectedSize = 'M';
  String _selectedCondition = 'Like New';
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  // pick image from gallery
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = picked);
    }
  }

  // upload listing to Firebase
  Future<void> _uploadListing() async {
    if (_titleController.text.isEmpty || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter all details and pick an image!'),
        ),
      );
      return;
    }

    if (_selectedCategory.isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill description and category.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // upload image to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(
        'listing/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await storageRef.putFile(File(_imageFile!.path));
      final imageUrl = await storageRef.getDownloadURL();

      // save listing in firebase
      await FirebaseFirestore.instance.collection('listings').add({
        'userId': widget.userId,
        'title': _titleController.text,
        'size': _selectedSize,
        'condition': _selectedCondition,
        'imageUrl': imageUrl,
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'tags': _tagsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Reset form
      setState(() {
        _isUploading = false;
        _titleController.clear();
        _imageFile = null;
        _descriptionController.clear();
        _tagsController.clear();
        _selectedCategory = 'Tops';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing uploaded successfully!')),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Add Apparel Listing')),
      body: Center(
        child: SingleChildScrollView(
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create New Listing',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Item Title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedCategory = val!),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.category_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Size dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedSize,
                    items: ['S', 'M', 'L', 'XL']
                        .map(
                          (size) =>
                              DropdownMenuItem(value: size, child: Text(size)),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedSize = val!),
                    decoration: InputDecoration(
                      labelText: 'Size',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.straighten),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Condition dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedCondition,
                    items: ['New', 'Like New', 'Used', 'Worn']
                        .map(
                          (cond) =>
                              DropdownMenuItem(value: cond, child: Text(cond)),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedCondition = val!),
                    decoration: InputDecoration(
                      labelText: 'Condition',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.check_circle_outline),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Tags(comma separated)
                  TextField(
                    controller: _tagsController,
                    decoration: InputDecoration(
                      labelText: 'Tags (comma-separated)',
                      hintText: 'e.g. summer, casual, vintage',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Image preview
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: _imageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                File(_imageFile!.path),
                                height: 160,
                                width: 160,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              height: 160,
                              width: 160,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.2,
                                  ),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.image,
                                size: 60,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      icon: Icon(
                        Icons.photo_library,
                        color: theme.colorScheme.primary,
                      ),
                      label: Text(
                        'Pick Image',
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _pickImage,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Upload button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _uploadListing,
                      child: _isUploading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Upload Listing'),
                    ),
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
