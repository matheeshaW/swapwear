import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import 'my_swaps_screen.dart';
import 'provider_dashboard.dart';
import 'eco_impact_dashboard.dart';
import 'achievements_page.dart';
import '../theme/colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _deleteListing(String listingId) async {
    try {
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(listingId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Listing deleted')));
        setState(() {}); // Refresh UI
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  Widget _buildMyListingsSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('listings')
          .where('ownerId', isEqualTo: _uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('You haven’t added any listings yet'),
          );
        }

        final docs = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'My Listings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final listingId = docs[index].id;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading:
                        data['imageUrl'] != null &&
                            data['imageUrl'].toString().isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: data['imageUrl'],
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 48,
                                height: 48,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 48,
                                height: 48,
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                  size: 24,
                                ),
                              ),
                            ),
                          )
                        : const Icon(Icons.image, size: 40),
                    title: Text(data['title'] ?? 'Untitled'),
                    subtitle: Text(data['category'] ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'Edit',
                          onPressed: () {
                            _showEditListingDialog(context, listingId, data);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Listing'),
                                content: const Text(
                                  'Are you sure you want to delete this listing?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _deleteListing(listingId);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _photoController = TextEditingController();
  final _prefsController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  bool _uploading = false;
  bool _photoUploading = false;
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  String? _userRole;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();

    _loadProfile();
    _loadUserRole();
  }

  Future<void> _loadProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      final data = doc.data() ?? {};
      _nameController.text = (data['name'] ?? '') as String;
      _photoController.text = (data['profilePic'] ?? '') as String;
      final prefs = (data['preferences'] as List<dynamic>? ?? [])
          .cast<String>();
      _prefsController.text = prefs.join(', ');
    } catch (e, stack) {
      debugPrint('Error loading profile: $e');
      debugPrint(stack.toString());
      _error = 'Failed to load profile';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserRole() async {
    try {
      final role = await _authService.getUserRole(_uid);
      if (mounted) {
        setState(() => _userRole = role);
      }
    } catch (e) {
      // Role loading failed, but don't show error as it's not critical
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final prefsList = _prefsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      await FirebaseFirestore.instance.collection('users').doc(_uid).update({
        'name': _nameController.text.trim(),
        'profilePic': _photoController.text.trim().isEmpty
            ? null
            : _photoController.text.trim(),
        'preferences': prefsList,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile saved')));
      }
    } catch (e) {
      setState(() => _error = 'Failed to save changes: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndAnalyzeImage() async {
    try {
      final picker = ImagePicker();
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1280,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      await _analyzeAndAppend(bytes, picked.name);
    } catch (e) {
      if (mounted) setState(() => _error = 'Image selection failed');
    }
  }

  Future<void> _changeProfilePhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (picked == null) return;
      setState(() => _photoUploading = true);
      final bytes = await picked.readAsBytes();
      final url = await StorageService().uploadProfilePhoto(
        uid: _uid,
        bytes: bytes,
      );
      await FirebaseFirestore.instance.collection('users').doc(_uid).update({
        'profilePic': url,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to update photo');
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  Future<void> _removeProfilePhoto() async {
    try {
      setState(() => _photoUploading = true);
      await StorageService().deleteProfilePhoto(uid: _uid);
      await FirebaseFirestore.instance.collection('users').doc(_uid).update({
        'profilePic': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo removed')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to remove photo');
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  Future<void> _analyzeAndAppend(Uint8List bytes, String filename) async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final tags = await AiService().analyzeClothingAndUpdatePrefs(
        uid: _uid,
        imageBytes: bytes,
        filename: filename,
      );
      // refresh UI
      await _loadProfile();
      if (mounted && tags.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Added: ${tags.join(', ')}')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Analysis failed');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _showEditListingDialog(
    BuildContext context,
    String listingId,
    Map<String, dynamic> data,
  ) async {
    final titleController = TextEditingController(text: data['title'] ?? '');
    final sizeController = TextEditingController(text: data['size'] ?? '');
    final conditionController = TextEditingController(
      text: data['condition'] ?? '',
    );
    final categoryController = TextEditingController(
      text: data['category'] ?? '',
    );
    final descriptionController = TextEditingController(
      text: data['description'] ?? '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Listing'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: sizeController,
                decoration: const InputDecoration(labelText: 'Size'),
              ),
              TextField(
                controller: conditionController,
                decoration: const InputDecoration(labelText: 'Condition'),
              ),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('listings')
                    .doc(listingId)
                    .update({
                      'title': titleController.text.trim(),
                      'size': sizeController.text.trim(),
                      'condition': conditionController.text.trim(),
                      'category': categoryController.text.trim(),
                      'description': descriptionController.text.trim(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Listing updated successfully'),
                    ),
                  );
                  setState(() {}); // refresh UI
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _photoController.dispose();
    _prefsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Your Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading
                ? null
                : () async {
                    try {
                      await FirebaseAuth.instance.signOut();
                      if (!mounted) return;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/login', (route) => false);
                      });
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Logout failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: Colors.red[600]),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Profile Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Avatar - centered with edit and delete actions
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(_uid)
                                .snapshots(),
                            builder: (context, snap) {
                              final pic =
                                  snap.data?.data()?['profilePic'] as String? ??
                                  _photoController.text.trim();
                              return Column(
                                children: [
                                  const SizedBox(height: 8),
                                  Center(
                                    child: SizedBox(
                                      height:
                                          152, // 56*2 + 40 (avatar + button offset)
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          CircleAvatar(
                                            radius: 56,
                                            backgroundColor: Colors.grey[100],
                                            backgroundImage: (pic.isNotEmpty)
                                                ? NetworkImage(pic)
                                                : null,
                                            child: (pic.isEmpty)
                                                ? const Icon(
                                                    Icons.person,
                                                    size: 56,
                                                  )
                                                : null,
                                          ),
                                          Positioned(
                                            right: -6,
                                            bottom: 0,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                shape: const CircleBorder(),
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                              ),
                                              onPressed: _photoUploading
                                                  ? null
                                                  : _changeProfilePhoto,
                                              child: _photoUploading
                                                  ? const SizedBox(
                                                      height: 16,
                                                      width: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : const Icon(
                                                      Icons.edit,
                                                      size: 16,
                                                    ),
                                            ),
                                          ),
                                          if (pic.isNotEmpty)
                                            Positioned(
                                              left: -6,
                                              bottom: 0,
                                              child: OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  shape: const CircleBorder(),
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                ),
                                                onPressed: _photoUploading
                                                    ? null
                                                    : _removeProfilePhoto,
                                                child: const Icon(
                                                  Icons.delete_outline,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 48),
                                ],
                              );
                            },
                          ),
                          // Name
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Name',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF667eea),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Name is required';
                              return null;
                            },
                          ),
                          /*const SizedBox(height: 12),
                          // Photo URL
                          TextFormField(
                            controller: _photoController,
                            decoration: InputDecoration(
                              labelText: 'Profile picture URL (optional)',
                              prefixIcon: const Icon(Icons.link_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF667eea),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                          */
                          const SizedBox(height: 12),
                          // Preferences
                          TextFormField(
                            controller: _prefsController,
                            decoration: InputDecoration(
                              labelText: 'Preferences (comma separated)',
                              prefixIcon: const Icon(Icons.style_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF667eea),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // AI Add from Photo
                          ElevatedButton.icon(
                            onPressed: _uploading ? null : _pickAndAnalyzeImage,
                            icon: _uploading
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add_a_photo_outlined),
                            label: const Text('Add from Photo (AI)'),
                          ),
                          const SizedBox(height: 12),
                          // Preference chips
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(_uid)
                                .snapshots(),
                            builder: (context, snap) {
                              final prefs =
                                  ((snap.data?.data()?['preferences']
                                              as List<dynamic>? ??
                                          [])
                                      .cast<String>());
                              if (prefs.isEmpty) return const SizedBox.shrink();
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: prefs
                                    .map((p) => Chip(label: Text(p)))
                                    .toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          // Save Button
                          Container(
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  Color.fromARGB(255, 3, 117, 148),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Save Changes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ListTile(
                      leading: const Icon(Icons.swap_horiz),
                      title: const Text('My Swaps'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MySwapsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Eco Impact Section
                    ListTile(
                      leading: const Icon(
                        Icons.eco_outlined,
                        color: Color(0xFF10B981),
                      ),
                      title: const Text(
                        'My Swap Eco Impact',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EcoImpactDashboard(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Achievements Section
                    ListTile(
                      leading: const Icon(
                        Icons.emoji_events_outlined,
                        color: Color(0xFFFFD700),
                      ),
                      title: const Text(
                        'Achievements',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AchievementsPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: _buildMyListingsSection(),
                    ),
                    // Provider Dashboard Button (only for providers)
                    if (_userRole == 'provider') ...[
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(
                          Icons.dashboard,
                          color: Color(0xFF10B981),
                        ),
                        title: const Text(
                          'Manage deliveries',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProviderDashboard(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
