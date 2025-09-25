import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../services/ai_service.dart';
import '../services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _photoController = TextEditingController();
  final _prefsController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  bool _uploading = false;
  bool _photoUploading = false;

  late final String _uid;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _uid = user!.uid;
    _loadProfile();
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
    } catch (e) {
      _error = 'Failed to load profile';
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      appBar: AppBar(
        title: const Text('Your Profile'),
        actions: [
          IconButton(
            onPressed: _isLoading
                ? null
                : () async {
                    await FirebaseAuth.instance.signOut();
                  },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                    ],
                    // Avatar row
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(_uid)
                          .snapshots(),
                      builder: (context, snap) {
                        final pic =
                            snap.data?.data()?['profilePic'] as String? ??
                            _photoController.text.trim();
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundImage: (pic.isNotEmpty)
                                  ? NetworkImage(pic)
                                  : null,
                              child: (pic.isEmpty)
                                  ? const Icon(Icons.person, size: 36)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _photoUploading
                                  ? null
                                  : _changeProfilePhoto,
                              icon: _photoUploading
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.photo_camera_back_outlined,
                                    ),
                              label: const Text('Change photo'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: (_photoUploading || (pic.isEmpty))
                                  ? null
                                  : _removeProfilePhoto,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remove'),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Name is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _photoController,
                      decoration: const InputDecoration(
                        labelText: 'Profile picture URL (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _prefsController,
                      decoration: const InputDecoration(
                        labelText: 'Preferences (comma separated)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _uploading ? null : _pickAndAnalyzeImage,
                      icon: _uploading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Add from Photo (AI)'),
                    ),
                    const SizedBox(height: 16),
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
                    // Removed duplicate Save button below history
                    const SizedBox(height: 24),
                    const Text(
                      'Swap History',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(_uid)
                          .snapshots(),
                      builder: (context, snap) {
                        final historyIds =
                            ((snap.data?.data()?['history'] as List<dynamic>? ??
                                    [])
                                .cast<String>());
                        if (historyIds.isEmpty) {
                          return const Text('No swaps yet');
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: historyIds.length,
                          itemBuilder: (context, index) {
                            final id = historyIds[index];
                            return StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: FirebaseFirestore.instance
                                  .collection('swaps')
                                  .doc(id)
                                  .snapshots(),
                              builder: (context, s) {
                                final d = s.data?.data();
                                final title = d?['itemName'] ?? id;
                                final status = d?['status'] ?? 'unknown';
                                final imageUrl = d?['imageUrl'] as String?;
                                return ListTile(
                                  leading: imageUrl != null
                                      ? CircleAvatar(
                                          backgroundImage: NetworkImage(
                                            imageUrl,
                                          ),
                                        )
                                      : const CircleAvatar(
                                          child: Icon(
                                            Icons.shopping_bag_outlined,
                                          ),
                                        ),
                                  title: Text(title.toString()),
                                  subtitle: Text('Status: $status'),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
