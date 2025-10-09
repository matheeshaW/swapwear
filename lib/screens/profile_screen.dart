import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import 'my_swaps_screen.dart';
import 'provider_dashboard.dart';
import 'achievements_page.dart';
import 'eco_impact_dashboard.dart';

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
  String? _userRole;

  late final String _uid;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _uid = user!.uid;
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
    } catch (e) {
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
        title: const Text('Your Profile'),
        actions: [
          IconButton(
            onPressed: _isLoading
                ? null
                : () async {
                    try {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/login', (route) => false);
                      }
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
                                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
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
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(
                        Icons.emoji_events,
                        color: Color(0xFF10B981),
                      ),
                      title: const Text(
                        'View Achievements',
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
                            builder: (_) => const AchievementsPage(),
                          ),
                        );
                      },
                    ),
                    // Eco Impact Dashboard Button
                    ListTile(
                      leading: const Icon(Icons.eco, color: Color(0xFF10B981)),
                      title: const Text(
                        'Eco Impact',
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
                            builder: (_) => const EcoImpactDashboard(),
                          ),
                        );
                      },
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
                          'Provider Dashboard',
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
