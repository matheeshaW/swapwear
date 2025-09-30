import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// data model to pass between steps
class ListingData {
  final String title;
  final String description;
  final String category;
  final String size;
  final String condition;
  final List<String> tags;
  final XFile? imageFile;

  ListingData({
    required this.title,
    required this.description,
    required this.category,
    required this.size,
    required this.condition,
    required this.tags,
    this.imageFile,
  });

  ListingData copyWith({
    String? title,
    String? description,
    String? category,
    String? size,
    String? condition,
    List<String>? tags,
    XFile? imageFile,
  }) {
    return ListingData(
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      size: size ?? this.size,
      condition: condition ?? this.condition,
      tags: tags ?? this.tags,
      imageFile: imageFile ?? this.imageFile,
    );
  }
}

// step 1 : Item Details
class AddListingStep1Screen extends StatefulWidget {
  final String userId;
  const AddListingStep1Screen({super.key, required this.userId});

  @override
  State<AddListingStep1Screen> createState() => _AddListingStep1ScreenState();
}

class _AddListingStep1ScreenState extends State<AddListingStep1Screen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _goToStep2() {
    if (_titleController.text.isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in title and description')),
      );
      return;
    }

    final listingData = ListingData(
      title: _titleController.text,
      description: _descriptionController.text.trim(),
      category: _selectedCategory,
      size: _selectedSize,
      condition: _selectedCondition,
      tags: [],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddListingStep2Screen(
          userId: widget.userId,
          listingData: listingData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // header with progress
            Container(
              color: Colors.green,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          'Add New Listing',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Step 1 of 2',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // progress bar
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.5,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Form context
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // title
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        hintText: 'Enter item title...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // description
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe your item...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // category
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ListTile(
                        title: Text('Category'),
                        subtitle: Text(_selectedCategory),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Select Category'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: _categories.map((Category) {
                                  return ListTile(
                                    title: Text(Category),
                                    onTap: () {
                                      setState(
                                        () => _selectedCategory = Category,
                                      );
                                      Navigator.pop(context);
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Size and Condition row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ListTile(
                              title: const Text('Size'),
                              subtitle: Text(_selectedSize),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Select Size'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: ['S', 'M', 'L', 'XL'].map((
                                        size,
                                      ) {
                                        return ListTile(
                                          title: Text(size),
                                          onTap: () {
                                            setState(
                                              () => _selectedSize = size,
                                            );
                                            Navigator.pop(context);
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ListTile(
                              title: const Text('Condition'),
                              subtitle: Text(_selectedCondition),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Select Condition'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children:
                                          [
                                            'New',
                                            'Like New',
                                            'Used',
                                            'Worn',
                                          ].map((condition) {
                                            return ListTile(
                                              title: Text(condition),
                                              onTap: () {
                                                setState(
                                                  () => _selectedCondition =
                                                      condition,
                                                );
                                                Navigator.pop(context);
                                              },
                                            );
                                          }).toList(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    // Next button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _goToStep2,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
