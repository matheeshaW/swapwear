# SwapWear Delivery Tracking System

A comprehensive logistics and delivery tracking system for the SwapWear mobile app built with Flutter and Firebase.

## 🚀 Features

### User Features
- **Track Delivery Button**: Added to MySwapsScreen for confirmed swaps
- **Real-time Progress Timeline**: Visual progress tracking with 4 stages
- **Delivery Status Updates**: Real-time updates via Firestore streams
- **Push Notifications**: FCM notifications when delivery status changes

### Admin Features
- **Delivery Management Dashboard**: Tabbed interface with user and delivery management
- **Status Updates**: Admin can update delivery status through dropdown interface
- **Delivery Statistics**: Real-time statistics dashboard
- **Bulk Operations**: Complete deliveries with one click

### Technical Features
- **Firestore Integration**: Real-time data synchronization
- **FCM Notifications**: Push notifications for status changes
- **Cloud Functions**: Server-side notification handling
- **Responsive UI**: Beautiful, modern interface design

## 📱 Delivery Flow

1. **Pending** → When swap is confirmed by users
2. **Approved** → When admin approves the swap
3. **Out for Delivery** → When courier picks up the item
4. **Completed** → When user confirms delivery received

## 🗄️ Firestore Structure

### Deliveries Collection
```javascript
deliveries/
├── {deliveryId}/
│   ├── swapId: "SW2847"
│   ├── itemName: "Denim Jacket → Vintage T-Shirt"
│   ├── user: "John Doe ↔ Jane Smith"
│   ├── status: "Out for Delivery"
│   ├── stepNumber: 3
│   ├── courier: "EcoSwap Logistics"
│   ├── expectedDelivery: "10/10/2025 18:00"
│   ├── lastUpdated: Timestamp
│   ├── trackingNote: "Package picked up by courier"
│   ├── fromUserId: "user123"
│   └── toUserId: "user456"
```

### Notifications Collection
```javascript
notifications/
├── {notificationId}/
│   ├── type: "delivery_update"
│   ├── title: "Delivery Update"
│   ├── body: "Denim Jacket status: Out for Delivery"
│   ├── tokens: ["fcm_token_1", "fcm_token_2"]
│   ├── data: {deliveryId, swapId, status, stepNumber}
│   └── createdAt: Timestamp
```

## 🛠️ Implementation Details

### New Files Created
- `lib/models/delivery_model.dart` - Delivery data model
- `lib/services/delivery_service.dart` - Delivery operations service
- `lib/screens/track_delivery_screen.dart` - Delivery tracking UI
- `lib/services/fcm_service.dart` - Firebase Cloud Messaging service

### Modified Files
- `lib/screens/my_swaps_screen.dart` - Added Track Delivery button
- `lib/screens/admin_dashboard.dart` - Added delivery management tabs
- `lib/services/swap_service.dart` - Auto-create delivery records
- `lib/main.dart` - Initialize FCM service
- `pubspec.yaml` - Added firebase_messaging dependency
- `functions/src/index.ts` - Added notification Cloud Function

### Key Components

#### DeliveryModel
- Immutable data model with helper methods
- Status progression logic (Pending → Approved → Out for Delivery → Completed)
- Validation and utility methods

#### DeliveryService
- CRUD operations for delivery records
- Real-time streams for UI updates
- FCM notification integration
- Statistics and analytics

#### TrackDeliveryScreen
- Beautiful progress timeline UI
- Real-time status updates
- Delivery information display
- Responsive design

#### AdminDashboard
- Tabbed interface (Users & Deliveries)
- Delivery management tools
- Statistics dashboard
- Status update dialogs

## 🔧 Setup Instructions

### 1. Dependencies
```bash
flutter pub get
```

### 2. Firebase Configuration
- Ensure Firebase project is configured
- Enable Firestore and Cloud Functions
- Configure FCM for your platform (Android/iOS)

### 3. Cloud Functions Deployment
```bash
cd functions
npm install
firebase deploy --only functions
```

### 4. FCM Setup
- Add FCM configuration to `android/app/google-services.json`
- Configure iOS push notifications in Xcode
- Test notification permissions

## 🎨 UI Design

### Progress Timeline
- Vertical timeline with 4 stages
- Color-coded status indicators
- Smooth animations and transitions
- Modern card-based design

### Admin Dashboard
- Clean, professional interface
- Statistics cards with color coding
- Intuitive status update dialogs
- Responsive layout

## 📊 Real-time Features

### Firestore Streams
- `streamDelivery()` - Single delivery updates
- `streamAllDeliveries()` - Admin dashboard updates
- `streamUserDeliveries()` - User-specific deliveries

### FCM Notifications
- Background message handling
- Foreground notification display
- Deep linking to relevant screens
- Token management and refresh

## 🔒 Security

### Admin Access
- Admin role verification
- Secure status update operations
- User permission checks

### Data Validation
- Input sanitization
- Status progression validation
- Error handling and logging

## 🚀 Usage Examples

### Creating a Delivery
```dart
final deliveryService = DeliveryService();
await deliveryService.createDelivery(
  swapId: 'SW123',
  itemName: 'Denim Jacket → Vintage T-Shirt',
  user: 'John Doe ↔ Jane Smith',
  fromUserId: 'user123',
  toUserId: 'user456',
);
```

### Updating Delivery Status
```dart
await deliveryService.updateDeliveryStatus(
  deliveryId: 'delivery123',
  newStatus: 'Out for Delivery',
  trackingNote: 'Package picked up by courier',
);
```

### Tracking Delivery
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => TrackDeliveryScreen(
      deliveryId: delivery.id!,
      swapId: delivery.swapId,
    ),
  ),
);
```

## 🧪 Testing

### Unit Tests
- Delivery model validation
- Service method testing
- Status progression logic

### Integration Tests
- Firestore operations
- FCM notification flow
- UI state management

## 📈 Future Enhancements

- **GPS Tracking**: Real-time location updates
- **Delivery Photos**: Photo confirmation system
- **Rating System**: Delivery experience ratings
- **Analytics**: Detailed delivery analytics
- **Multi-language**: Internationalization support

## 🐛 Troubleshooting

### Common Issues
1. **FCM Token Issues**: Check Firebase configuration
2. **Permission Denied**: Verify admin role assignment
3. **Stream Errors**: Check Firestore security rules
4. **Notification Failures**: Verify Cloud Functions deployment

### Debug Tips
- Enable Firestore debug logging
- Check Cloud Functions logs
- Verify FCM token registration
- Test with Firebase emulator

## 📝 License

This delivery tracking system is part of the SwapWear project and follows the same licensing terms.

