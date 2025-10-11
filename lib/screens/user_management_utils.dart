import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_service.dart';

/// Utility dialogs for user management (edit/delete)
/// Used by: admin_dashboard, user_management_dialog, user_management_screen

void editUserDialog({
  required BuildContext context,
  required DocumentSnapshot<Map<String, dynamic>> doc,
  required AdminService adminService,
  VoidCallback? onUserUpdated,
}) {
  final data = doc.data() ?? {};
  final email = (data['email'] ?? doc.id) as String;
  final nameCtrl = TextEditingController(text: data['name'] ?? '');
  final prefs = (data['preferences'] as List<dynamic>? ?? []).cast<String>();
  final prefsCtrl = TextEditingController(text: prefs.join(', '));
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Edit $email'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Text(
                      'User ID',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(flex: 3, child: SelectableText(doc.id, maxLines: 1)),
                  IconButton(
                    tooltip: 'Copy UID',
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: doc.id));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User ID copied')),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
              await adminService.updateUser(doc.id, {
                'name': nameCtrl.text.trim(),
                'preferences': list,
              });
              if (onUserUpdated != null) onUserUpdated();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

Future<void> confirmDeleteUser({
  required BuildContext context,
  required String uid,
  required AdminService adminService,
  VoidCallback? onUserDeleted,
}) async {
  final confirmed =
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Deactivate user?'),
          content: Text('This will delete profile for $uid.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
  if (confirmed) {
    await adminService.deleteUser(uid);
    if (onUserDeleted != null) onUserDeleted();
  }
}
