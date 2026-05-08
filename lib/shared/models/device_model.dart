import 'package:cloud_firestore/cloud_firestore.dart';

class Device {
  final String id;
  final String ownerId;
  final String ownerName;
  final String title;
  final String description;
  final String category;
  final String imageUrl;
  final double pricePerDay;
  final bool available;
  final double lat;
  final double lng;
  final String city;
  final DateTime createdAt;

  Device({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.title,
    required this.description,
    required this.category,
    required this.imageUrl,
    required this.pricePerDay,
    required this.available,
    required this.lat,
    required this.lng,
    required this.city,
    required this.createdAt,
  });

  factory Device.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Device(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      ownerName: data['ownerName'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      pricePerDay: (data['pricePerDay'] as num?)?.toDouble() ?? 0.0,
      available: data['available'] ?? true,
      lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
      city: data['city'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'ownerName': ownerName,
      'title': title,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'pricePerDay': pricePerDay,
      'available': available,
      'lat': lat,
      'lng': lng,
      'city': city,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

const List<String> deviceCategories = [
  'Reinigen',
  'Tuin',
  'Keuken',
  'Gereedschap',
  'Sport',
  'Overige',
];