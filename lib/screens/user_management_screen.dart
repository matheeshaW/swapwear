import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/admin_service.dart';
import 'user_management_utils.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _search = '';
  final AdminService _adminService = AdminService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, email or UID',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
              ),
              onChanged: (val) => setState(() => _search = val.trim()),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _adminService.streamAllUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No users found'));
                  }
                  final docs = snapshot.data!.docs.where((doc) {
                    final d = doc.data();
                    final s = _search.toLowerCase();
                    return _search.isEmpty ||
                        (d['name'] ?? '').toString().toLowerCase().contains(
                          s,
                        ) ||
                        (d['email'] ?? '').toString().toLowerCase().contains(
                          s,
                        ) ||
                        doc.id.toLowerCase().contains(s);
                  }).toList();
                  if (docs.isEmpty)
                    return const Center(
                      child: Text('No users match your search'),
                    );
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 26),
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final d = doc.data();
                      final name = (d['name'] ?? '').toString();
                      final email = (d['email'] ?? doc.id).toString();
                      final pic = d['profilePic'] ?? '';
                      final role = d['role'] ?? 'customer';
                      return ListTile(
                        leading: (pic != null && pic.toString().isNotEmpty)
                            ? CircleAvatar(
                                backgroundColor: Colors.grey[100],
                                radius: 22,
                                child: ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: pic,
                                    width: 42,
                                    height: 42,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) => Icon(
                                      Icons.person,
                                      color: Colors.grey[400],
                                    ),
                                    placeholder: (context, url) =>
                                        const CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                  ),
                                ),
                              )
                            : CircleAvatar(
                                backgroundColor: Colors.indigo[50],
                                radius: 22,
                                child: Icon(
                                  Icons.person_outline,
                                  color: Colors.indigo[400],
                                ),
                              ),
                        title: Text(
                          name.isNotEmpty ? name : email,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(email, style: const TextStyle(fontSize: 13)),
                            Text(
                              'Role: $role',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit',
                              onPressed: () {
                                editUserDialog(
                                  context: context,
                                  doc: doc,
                                  adminService: _adminService,
                                  onUserUpdated: () => setState(() {}),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete',
                              onPressed: () async {
                                await confirmDeleteUser(
                                  context: context,
                                  uid: doc.id,
                                  adminService: _adminService,
                                  onUserDeleted: () => setState(() {}),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
