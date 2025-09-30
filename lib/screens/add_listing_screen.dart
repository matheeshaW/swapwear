import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'browsing_screen.dart';

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

class StepProgressBar extends StatelessWidget {
  final double progress; // 0..1
  final double horizontalInset; // space from left & right
  const StepProgressBar({
    super.key,
    required this.progress,
    this.horizontalInset = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth - (horizontalInset * 2);
        final knobR = 8.0;
        final knobD = knobR * 2;
        final clamped = progress.clamp(0.0, 1.0);

        final travel = (totalW - knobD).clamp(0.0, totalW);
        final knobLeft = travel * clamped;

        final fillW = knobLeft + knobR;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalInset),
          child: SizedBox(
            height: 16,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              alignment: Alignment.centerLeft,
              children: [
                // Track
                Container(
                  height: 6,
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // Fill
                Positioned(
                  left: 0,
                  child: Container(
                    width: fillW,
                    height: 6,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                // Knob
                Positioned(
                  left: fillW - knobR,
                  child: Container(
                    width: knobR * 2,
                    height: knobR * 2,
                    decoration: BoxDecoration(
                      color: clamped >= 1 ? Colors.blue : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BrowsingScreen(userId: widget.userId),
                          ),
                        ),
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
                  const SizedBox(height: 8),
                  StepProgressBar(progress: 0.5),
                  const SizedBox(height: 6),
                  Text(
                    'Item Details',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
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

// step 2: Media & Tags
class AddListingStep2Screen extends StatefulWidget {
  final String userId;
  final ListingData listingData;
  const AddListingStep2Screen({
    super.key,
    required this.userId,
    required this.listingData,
  });

  @override
  State<AddListingStep2Screen> createState() => _AddListingStep2ScreenState();
}

class _AddListingStep2ScreenState extends State<AddListingStep2Screen> {
  final _tagsController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  List<String> _tags = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.listingData.tags);
  }

  @override
  void dispose() {
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = picked);
    }
  }

  void _addTag() {
    final tag = _tagsController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagsController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _uploadListing() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please upload an image!')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      // upload image to firebase storage
      final storageRef = FirebaseStorage.instance.ref().child(
        'listing/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await storageRef.putFile(File(_imageFile!.path));
      final imageUrl = await storageRef.getDownloadURL();

      // save listing in firebase
      await FirebaseFirestore.instance.collection('listings').add({
        'userId': widget.userId,
        'title': widget.listingData.title,
        'size': widget.listingData.size,
        'condition': widget.listingData.condition,
        'imageUrl': imageUrl,
        'description': widget.listingData.description,
        'category': widget.listingData.category,
        'tags': _tags,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing uploaded successfully!')),
      );

      // navigate to Browse listings
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => BrowsingScreen(userId: widget.userId),
        ),
        (route) => false,
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
                        onPressed: () {
                          final w = widget;
                          if (w is _AddListingStep2Proxy) {
                            (w as _AddListingStep2Proxy).onBackToStep1();
                          } else {
                            Navigator.pop(context);
                          }
                        },
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
                      const SizedBox(width: 48), // balance the back button
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Step 2 of 2",
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StepProgressBar(progress: 1.0),
                  const SizedBox(height: 6),
                  Text(
                    'Media & Tags',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // upload image
                    Text(
                      'Upload Image',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            style: BorderStyle.solid,
                            width: 2,
                          ),
                        ),
                        child: _imageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(_imageFile!.path),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add,
                                    size: 60,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Upload / Take Photo',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (_imageFile != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.image, color: Colors.grey[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Preview',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'image.jpg',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 32),
                    // Tags
                    Text(
                      'Tags',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_tags.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _tags.map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _tags.indexOf(tag) % 2 == 0
                                          ? Colors.blue
                                          : Colors.green,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        tag,
                                        style: TextStyle(
                                          color: _tags.indexOf(tag) % 2 == 0
                                              ? Colors.blue
                                              : Colors.green,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () => _removeTag(tag),
                                        child: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: _tags.indexOf(tag) % 2 == 0
                                              ? Colors.blue
                                              : Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _tagsController,
                                  decoration: InputDecoration(
                                    hintText: 'Add a tag...',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onSubmitted: (_) => _addTag(),
                                ),
                              ),
                              TextButton(
                                onPressed: _addTag,
                                child: const Text(
                                  '+ Add more tags',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // post item button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _uploadListing,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Post Item',
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

extension _Step1WithNext on AddListingStep1Screen {
  Widget buildWithNext(void Function(ListingData) onNext) {
    return _AddListingStep1Proxy(userId: userId, onNext: onNext);
  }
}

class _AddListingStep1Proxy extends AddListingStep1Screen {
  final void Function(ListingData) onNext;
  const _AddListingStep1Proxy({
    required super.userId,
    required this.onNext,
    super.key,
  });

  @override
  State<AddListingStep1Screen> createState() => _AddListingStep1ProxyState();
}

class _AddListingStep1ProxyState extends _AddListingStep1ScreenState {
  void _forward(ListingData data) =>
      (widget as _AddListingStep1Proxy).onNext(data);

  @override
  void _goToStep2() {
    if (_titleController.text.isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in title and description')),
      );
      return;
    }
    final data = ListingData(
      title: _titleController.text,
      description: _descriptionController.text.trim(),
      category: _selectedCategory,
      size: _selectedSize,
      condition: _selectedCondition,
      tags: [],
    );
    _forward(data);
  }
}

extension _Step2WithBack on AddListingStep2Screen {
  Widget buildWithBack(VoidCallback onBackToStep1) {
    return _AddListingStep2Proxy(
      userId: userId,
      listingData: listingData,
      onBackToStep1: onBackToStep1,
    );
  }
}

class _AddListingStep2Proxy extends AddListingStep2Screen {
  final VoidCallback onBackToStep1;
  const _AddListingStep2Proxy({
    required super.userId,
    required super.listingData,
    required this.onBackToStep1,
    super.key,
  });

  @override
  State<AddListingStep2Screen> createState() => _AddListingStep2ProxyState();
}

class _AddListingStep2ProxyState extends _AddListingStep2ScreenState {
  @override
  Widget build(BuildContext context) {
    return super.build(context);
  }

  @override
  void initState() {
    super.initState();
  }
}

// main AddListingScreen that hosts both steps
class AddListingScreen extends StatefulWidget {
  final String userId;
  const AddListingScreen({super.key, required this.userId});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  int _step = 1;
  ListingData? _listingDraft;

  void _goToStep2(ListingData data) {
    setState(() {
      _listingDraft = data;
      _step = 2;
    });
  }

  void _backToStep1() {
    setState(() => _step = 1);
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 1) {
      // Inject a callback to move to step 2
      return AddListingStep1Screen(
        userId: widget.userId,
      ).buildWithNext(_goToStep2);
    }
    return AddListingStep2Screen(
      userId: widget.userId,
      listingData: _listingDraft!,
    ).buildWithBack(_backToStep1);
  }
}
