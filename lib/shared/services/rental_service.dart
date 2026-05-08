import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rental_model.dart';

class RentalService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createRental(Rental rental) async {
    await _db.collection('rentals').add(rental.toMap());
  }

  Stream<List<Rental>> getRenterRentals(String renterId) {
    return _db
        .collection('rentals')
        .where('renterId', isEqualTo: renterId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Rental.fromDoc).toList());
  }

  Stream<List<Rental>> getOwnerRentals(String ownerId) {
    return _db
        .collection('rentals')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Rental.fromDoc).toList());
  }

  Future<void> approveRental(String rentalId) async {
    await _db.collection('rentals').doc(rentalId).update({'status': RentalStatus.approved.name});
  }

  Future<void> rejectRental(String rentalId) async {
    await _db.collection('rentals').doc(rentalId).update({'status': RentalStatus.rejected.name});
  }

  Future<void> completeRental(String rentalId) async {
    await _db.collection('rentals').doc(rentalId).update({'status': RentalStatus.completed.name});
  }
  Future<List<DateTime>> getBookedDates(String deviceId) async {
  final snap = await _db
      .collection('rentals')
      .where('deviceId', isEqualTo: deviceId)
      .where('status', whereIn: ['pending', 'approved'])
      .get();

  final dates = <DateTime>[];
  for (final doc in snap.docs) {
    final rental = Rental.fromDoc(doc);
    final current = rental.startDate;
    final end = rental.endDate;
    for (int i = 0; i <= end.difference(current).inDays; i++) {
      dates.add(current.add(Duration(days: i)));
    }
  }
  return dates;
}
}