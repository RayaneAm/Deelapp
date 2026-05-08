import 'package:cloud_firestore/cloud_firestore.dart';

enum RentalStatus { pending, approved, rejected, completed }

class Rental {
  final String id;
  final String deviceId;
  final String deviceTitle;
  final String deviceImageUrl;
  final String renterId;
  final String renterName;
  final String ownerId;
  final DateTime startDate;
  final DateTime endDate;
  final double totalPrice;
  final RentalStatus status;
  final DateTime createdAt;

  Rental({
    required this.id,
    required this.deviceId,
    required this.deviceTitle,
    required this.deviceImageUrl,
    required this.renterId,
    required this.renterName,
    required this.ownerId,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
  });

  int get days => endDate.difference(startDate).inDays + 1;

  factory Rental.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Rental(
      id: doc.id,
      deviceId: data['deviceId'] ?? '',
      deviceTitle: data['deviceTitle'] ?? '',
      deviceImageUrl: data['deviceImageUrl'] ?? '',
      renterId: data['renterId'] ?? '',
      renterName: data['renterName'] ?? '',
      ownerId: data['ownerId'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0.0,
      status: RentalStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => RentalStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'deviceTitle': deviceTitle,
      'deviceImageUrl': deviceImageUrl,
      'renterId': renterId,
      'renterName': renterName,
      'ownerId': ownerId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalPrice': totalPrice,
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}