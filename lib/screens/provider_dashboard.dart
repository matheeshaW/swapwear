import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/delivery_model.dart';
import '../services/delivery_service.dart';

class ProviderDashboard extends StatefulWidget {
  const ProviderDashboard({super.key});

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard> {
  String? _providerName;
  bool _isLoading = true;
  bool _showDeliveryManagement = false;
  final _deliveryService = DeliveryService();

  @override
  void initState() {
    super.initState();
    _loadProviderData();
  }

  Future<void> _loadProviderData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          setState(() {
            _providerName = data?['name'] ?? 'Provider';
            _isLoading = false;
          });
        } else {
          setState(() {
            _providerName = 'Provider';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _providerName = 'Provider';
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF10B981)),
        title: const Text(
          'Provider Dashboard',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withOpacity(0.2),
                  const Color(0xFFD1FAE5),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome, $_providerName!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage your delivery operations efficiently',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Stats Cards
            StreamBuilder<List<DeliveryModel>>(
              stream: _deliveryService.streamAllDeliveries(),
              builder: (context, snapshot) {
                int activeDeliveries = 0;
                int completedDeliveries = 0;

                if (snapshot.hasData) {
                  for (final delivery in snapshot.data!) {
                    if (delivery.isCompleted) {
                      completedDeliveries++;
                    } else {
                      activeDeliveries++;
                    }
                  }
                }

                return Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Active Deliveries',
                        activeDeliveries.toString(),
                        Icons.local_shipping,
                        const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Completed Deliveries',
                        completedDeliveries.toString(),
                        Icons.check_circle,
                        const Color(0xFF059669),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Manage Deliveries Button
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showDeliveryManagement = !_showDeliveryManagement;
                        });
                      },
                      icon: const Icon(
                        Icons.assignment_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'Manage All Deliveries',
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
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Profile Button
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981),
                        width: 2,
                      ),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/profile');
                      },
                      icon: const Icon(
                        Icons.person_outline,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                      label: const Text(
                        'View Profile',
                        style: TextStyle(
                          color: Color(0xFF10B981),
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
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Delivery Management Section
            if (_showDeliveryManagement) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manage All Deliveries',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<List<DeliveryModel>>(
                      stream: _deliveryService.streamAllDeliveries(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                color: Color(0xFF10B981),
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.local_shipping_outlined,
                                    size: 48,
                                    color: Color(0xFF6B7280),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No deliveries available yet',
                                    style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: snapshot.data!
                              .map((delivery) => _buildDeliveryCard(delivery))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(DeliveryModel delivery) {
    Color getStatusColor() {
      switch (delivery.status) {
        case 'Pending':
          return const Color(0xFF6B7280);
        case 'Approved':
          return const Color(0xFF3B82F6);
        case 'Out for Delivery':
          return const Color(0xFFF59E0B);
        case 'Completed':
          return const Color(0xFF10B981);
        default:
          return const Color(0xFF6B7280);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: getStatusColor().withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Item Image
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD1FAE5), width: 1),
                  image: delivery.itemImageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(delivery.itemImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: delivery.itemImageUrl == null
                    ? const Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFF10B981),
                        size: 24,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Item Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.itemName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'To: ${delivery.receiverName ?? 'Unknown'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Provider: ${delivery.providerName ?? 'Unknown'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Swap #${delivery.swapId}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  delivery.status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: getStatusColor(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Status Update Section
          if (!delivery.isCompleted) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Update Status:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: getStatusColor(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButton<String>(
                    value: delivery.nextStatus,
                    isExpanded: true,
                    underline: Container(),
                    items: DeliveryModel.statusSteps
                        .where((status) => delivery.canUpdateTo(status))
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(
                              status,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (newStatus) async {
                      if (newStatus != null) {
                        try {
                          await _deliveryService.updateDeliveryStatus(
                            deliveryId: delivery.id!,
                            newStatus: newStatus,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Status updated to $newStatus'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update status: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF10B981),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Delivery completed successfully',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: getStatusColor(),
                  ),
                ),
              ],
            ),
          ],
          if (delivery.lastUpdated != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last updated: ${_formatDateTime(delivery.lastUpdated!)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    }
  }
}
