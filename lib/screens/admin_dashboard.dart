import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/admin_service.dart';
import 'user_management_screen.dart';
import 'user_management_utils.dart';
import '../theme/colors.dart';
import '../services/analytics_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _adminService = AdminService();
  final _analyticsService = AnalyticsService();
  bool _isAdmin = false;
  bool _loading = true;
  bool _showUserManagement = false;

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

  void _addProviderDialog() {
    final uidCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final roleCtrl = TextEditingController(text: 'provider');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Provider'),
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
              await _adminService.addProvider(
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 56,
                margin: const EdgeInsets.only(bottom: 12),
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
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.people_outline, color: Colors.white),
                  label: const Text(
                    'User Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserManagementScreen(),
                      ),
                    );
                  },
                ),
              ),
              Container(
                height: 56,
                margin: const EdgeInsets.only(bottom: 16),
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
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Add Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: _addAdminDialog,
                ),
              ),
              Container(
                height: 52,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.local_shipping, color: Colors.white),
                  label: const Text(
                    'Add Provider',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _addProviderDialog,
                ),
              ),

              // Eco-Impact Summary Dashboard
              const SizedBox(height: 24),
              const Text(
                'Eco-Impact Summary',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 16),
              _buildEcoImpactDashboard(),

              // Placeholder for future admin features
              // Example: Analytics, Reports, etc.
              if (_showUserManagement) ...[
                const Text(
                  'All Users',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 600, // or MediaQuery height - adjust as needed
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _adminService.streamAllUsers(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty)
                        return const Center(child: Text('No users'));
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final d = docs[index].data();
                          final uid = docs[index].id;
                          final title = d['name']?.toString().isNotEmpty == true
                              ? d['name']
                              : d['email'] ?? uid;
                          final email = d['email'] ?? uid;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: Colors.indigo[50],
                                child: const Icon(
                                  Icons.person_outline,
                                  color: Color(0xFF667eea),
                                ),
                              ),
                              title: Text(
                                title.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(email.toString()),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit',
                                    onPressed: () => editUserDialog(
                                      context: context,
                                      doc: docs[index],
                                      adminService: _adminService,
                                      onUserUpdated: () {
                                        // No specific action needed here for now
                                      },
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: () async {
                                      await confirmDeleteUser(
                                        context: context,
                                        uid: uid,
                                        adminService: _adminService,
                                        onUserDeleted: () {
                                          // No specific action needed here for now
                                        },
                                      );
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEcoImpactDashboard() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _analyticsService.getEcoImpactSummary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF10B981)),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Text(
              'Unable to load eco-impact data',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
            ),
          );
        }

        final data = snapshot.data!;
        final totalSwaps = data['totalSwaps'] as int;
        final activeUsers = data['activeUsers'] as int;
        final swapActivity = data['swapActivity'] as List<Map<String, dynamic>>;
        final environmentalImpact =
            data['environmentalImpact'] as Map<String, double>;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Total Swaps',
                    value: totalSwaps.toString(),
                    icon: Icons.swap_horiz,
                    color: const Color(0xFF10B981),
                    trend: '+12% this month',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Active Users',
                    value: activeUsers.toString(),
                    icon: Icons.people,
                    color: const Color(0xFF3B82F6),
                    trend: '+8% this week',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Swap Activity Chart
            _buildSwapActivityChart(swapActivity),

            const SizedBox(height: 24),

            // Environmental Impact
            _buildEnvironmentalImpact(environmentalImpact),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                trend,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwapActivityChart(List<Map<String, dynamic>> activity) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Swap Activity (Last 7 Days)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxY(activity),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < activity.length) {
                          return Text(
                            activity[index]['dayName'],
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: activity.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: (data['count'] as int).toDouble(),
                        color: const Color(0xFF10B981),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentalImpact(Map<String, double> impact) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.eco,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Environmental Impact',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildImpactMetric(
            icon: Icons.local_laundry_service,
            value: '${impact['textileWastePrevented']!.toStringAsFixed(0)} kg',
            label: 'textile waste prevented',
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 16),
          _buildImpactMetric(
            icon: Icons.water_drop,
            value: '${impact['waterSaved']!.toStringAsFixed(0)} liters',
            label: 'water saved',
            color: const Color(0xFF3B82F6),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactMetric({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  double _getMaxY(List<Map<String, dynamic>> activity) {
    final maxCount = activity.fold<int>(
      0,
      (max, data) =>
          (data['count'] as int) > max ? (data['count'] as int) : max,
    );
    return (maxCount * 1.2).ceilToDouble();
  }
}
