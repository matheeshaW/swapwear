import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/admin_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _adminService = AdminService();
  bool _isAdmin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final isAdmin = await _adminService.isAdmin(uid);
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
        _loading = false;
      });
    }
  }

  void _editUserDialog(DocumentSnapshot<Map<String, dynamic>> doc) {
    final nameCtrl = TextEditingController(text: doc.data()?['name'] ?? '');
    final prefs = (doc.data()?['preferences'] as List<dynamic>? ?? [])
        .cast<String>();
    final prefsCtrl = TextEditingController(text: prefs.join(', '));
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit ${doc.id}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: prefsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Preferences (comma separated)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final list = prefsCtrl.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                await _adminService.updateUser(doc.id, {
                  'name': nameCtrl.text.trim(),
                  'preferences': list,
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _addAdminDialog() {
    final uidCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final roleCtrl = TextEditingController(text: 'admin');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Admin'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: uidCtrl,
                decoration: const InputDecoration(labelText: 'User UID'),
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(labelText: 'Role'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _adminService.addAdmin(
                uid: uidCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                role: roleCtrl.text.trim(),
              );
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAdmin) {
      return const Scaffold(body: Center(child: Text('Access denied')));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: _addAdminDialog,
            icon: const Icon(Icons.admin_panel_settings),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _adminService.streamAllUsers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No users'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final d = docs[index].data();
              final uid = docs[index].id;
              return ListTile(
                title: Text(
                  d['name']?.toString().isNotEmpty == true
                      ? d['name']
                      : d['email'] ?? uid,
                ),
                subtitle: Text(d['email'] ?? uid),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _editUserDialog(docs[index]),
                      icon: const Icon(Icons.edit),
                    ),
                    IconButton(
                      onPressed: () async {
                        final confirmed =
                            await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Deactivate user?'),
                                content: Text(
                                  'This will delete profile for $uid.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                        if (confirmed) {
                          await _adminService.deleteUser(uid);
                        }
                      },
                      icon: const Icon(Icons.delete),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
