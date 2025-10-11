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
  String? _providerId;
  bool _isLoading = true;
  int _selectedDeliveryTab =
      0; // 0: All, 1: Pending, 2: Approved, 3: Picked Up, 4: In Transit, 5: Delivered
  final _deliveryService = DeliveryService();

  @override
  void initState() {
    super.initState();
    _loadProviderData();
  }

  Future<void> _loadProviderData() async {
    final user = FirebaseAuth.instance.currentUser;
    print('Provider Dashboard - Loading provider data for user: ${user?.uid}');

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
            // Use the main delivery provider ID so all providers see all deliveries
            _providerId = 'main_delivery_provider';
            _isLoading = false;
          });
          print(
            'Provider Dashboard - Provider ID set to: $_providerId, Name: $_providerName',
          );
        } else {
          setState(() {
            _providerName = 'Provider';
            // Use the main delivery provider ID so all providers see all deliveries
            _providerId = 'main_delivery_provider';
            _isLoading = false;
          });
          print(
            'Provider Dashboard - User doc not found, Provider ID set to: $_providerId',
          );
        }
      } catch (e) {
        print('Provider Dashboard - Error loading provider data: $e');
        setState(() {
          _providerName = 'Provider';
          // Use the main delivery provider ID so all providers see all deliveries
          _providerId = 'main_delivery_provider';
          _isLoading = false;
        });
      }
    } else {
      print('Provider Dashboard - No user logged in');
      setState(() {
        _providerId = null;
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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () {
            // Navigate back to browsing screen with profile tab
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/browse',
              (route) => false,
              arguments: {
                'userId': FirebaseAuth.instance.currentUser?.uid,
                'initialTab': 3, // Profile tab index
              },
            );
          },
        ),
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

            // Delivery Management Section with Tabs
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
                    'Delivery Management',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Delivery Tabs
                  _buildDeliveryTabs(),

                  const SizedBox(height: 16),

                  // Delivery Content
                  _buildDeliveryContent(),
                ],
              ),
            ),
            const SizedBox(height: 24),
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

  // Get status icon
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'approved':
        return Icons.check_circle_outline;
      case 'picked up':
        return Icons.inventory_2;
      case 'in transit':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      default:
        return Icons.info_outline;
    }
  }

  // Format time ago (like notifications)
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  // Show status update dialog
  Future<void> _showStatusUpdateDialog(DeliveryModel delivery) async {
    final statusSteps = DeliveryModel.statusSteps;
    final currentIndex = statusSteps.indexOf(delivery.status);
    final availableStatuses = statusSteps.skip(currentIndex + 1).toList();

    if (availableStatuses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No further status updates available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? selectedStatus = availableStatuses.first;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Status for ${delivery.itemName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Status: ${delivery.status}'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'New Status',
                border: OutlineInputBorder(),
              ),
              items: availableStatuses.map((status) {
                return DropdownMenuItem(value: status, child: Text(status));
              }).toList(),
              onChanged: (value) {
                selectedStatus = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, selectedStatus),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _deliveryService.updateDeliveryStatus(
          deliveryId: delivery.id!,
          newStatus: result,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status updated to $result'),
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
  }

  // Get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'approved':
        return const Color(0xFF3B82F6);
      case 'picked up':
        return const Color(0xFF8B5CF6);
      case 'in transit':
        return const Color(0xFF7C3AED);
      case 'delivered':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }

  // Build delivery tabs
  Widget _buildDeliveryTabs() {
    final tabs = [
      'All',
      'Pending',
      'Approved',
      'Picked Up',
      'In Transit',
      'Delivered',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = _selectedDeliveryTab == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDeliveryTab = index;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF10B981)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF10B981)
                      : const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              child: Text(
                tab,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Build delivery content based on selected tab
  Widget _buildDeliveryContent() {
    return StreamBuilder<List<DeliveryModel>>(
      stream: _deliveryService.streamAllDeliveries(),
      builder: (context, snapshot) {
        print(
          'Provider Dashboard - StreamBuilder: Connection State: ${snapshot.connectionState}, Has Data: ${snapshot.hasData}, Data Length: ${snapshot.data?.length ?? 0}',
        );

        if (snapshot.hasError) {
          print('Provider Dashboard - StreamBuilder Error: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
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
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        // Filter deliveries based on selected tab
        List<DeliveryModel> filteredDeliveries = _filterDeliveriesByTab(
          snapshot.data!,
        );

        if (filteredDeliveries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    _getTabIcon(_selectedDeliveryTab),
                    size: 48,
                    color: const Color(0xFF6B7280),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No deliveries available yet',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Group deliveries by swap pair to show both items together
        Map<String, List<DeliveryModel>> groupedDeliveries =
            _groupDeliveriesBySwapPair(filteredDeliveries);

        // Display grouped deliveries (two items per swap)
        return Column(
          children: groupedDeliveries.entries
              .map((entry) => _buildSwapDeliveryGroup(entry.key, entry.value))
              .toList(),
        );
      },
    );
  }

  // Filter deliveries based on selected tab
  List<DeliveryModel> _filterDeliveriesByTab(List<DeliveryModel> deliveries) {
    switch (_selectedDeliveryTab) {
      case 0: // All
        return deliveries;
      case 1: // Pending
        return deliveries
            .where((d) => d.status.toLowerCase() == 'pending')
            .toList();
      case 2: // Approved
        return deliveries
            .where((d) => d.status.toLowerCase() == 'approved')
            .toList();
      case 3: // Picked Up
        return deliveries
            .where((d) => d.status.toLowerCase() == 'picked up')
            .toList();
      case 4: // In Transit
        return deliveries
            .where((d) => d.status.toLowerCase() == 'in transit')
            .toList();
      case 5: // Delivered
        return deliveries
            .where((d) => d.status.toLowerCase() == 'delivered')
            .toList();
      default:
        return deliveries;
    }
  }

  // Get tab icon
  IconData _getTabIcon(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return Icons.list;
      case 1:
        return Icons.schedule;
      case 2:
        return Icons.check_circle_outline;
      case 3:
        return Icons.inventory_2;
      case 4:
        return Icons.local_shipping;
      case 5:
        return Icons.check_circle;
      default:
        return Icons.list;
    }
  }

  // Group deliveries by swap pair
  Map<String, List<DeliveryModel>> _groupDeliveriesBySwapPair(
    List<DeliveryModel> deliveries,
  ) {
    final Map<String, List<DeliveryModel>> grouped = {};

    for (final delivery in deliveries) {
      final swapPairId = delivery.swapPairId;
      if (swapPairId.isNotEmpty) {
        if (!grouped.containsKey(swapPairId)) {
          grouped[swapPairId] = [];
        }
        grouped[swapPairId]!.add(delivery);
      }
    }

    return grouped;
  }

  // Build swap delivery group (shows both items for a swap)
  Widget _buildSwapDeliveryGroup(
    String swapPairId,
    List<DeliveryModel> deliveries,
  ) {
    if (deliveries.isEmpty) return const SizedBox.shrink();

    final swapId = deliveries.first.swapId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
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
          // Swap header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Swap ID: $swapId',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${deliveries.length} items',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          // Individual delivery items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: deliveries
                  .map((delivery) => _buildIndividualDeliveryCard(delivery))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Build individual delivery card within a swap group
  Widget _buildIndividualDeliveryCard(DeliveryModel delivery) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getStatusColor(delivery.status).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Item image or icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getStatusColor(delivery.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: delivery.itemImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      delivery.itemImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        _getStatusIcon(delivery.status),
                        color: _getStatusColor(delivery.status),
                        size: 24,
                      ),
                    ),
                  )
                : Icon(
                    _getStatusIcon(delivery.status),
                    color: _getStatusColor(delivery.status),
                    size: 24,
                  ),
          ),
          const SizedBox(width: 12),

          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item name
                Text(
                  delivery.itemName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),

                // Owner info
                Text(
                  'Owner: ${delivery.receiverName}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),

                // Status and timestamp
                Row(
                  children: [
                    // Status tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(delivery.status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        delivery.status,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Timestamp
                    Text(
                      _formatTimeAgo(delivery.lastUpdated ?? DateTime.now()),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Update button
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showStatusUpdateDialog(delivery),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
