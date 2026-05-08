import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/device_model.dart';

class DeviceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

Future<String> uploadImage(File imageFile) async {
  // Storage nog niet geconfigureerd, tijdelijk overgeslagen
  return '';
}

  Future<void> addDevice(Device device) async {
    await _db.collection('devices').add(device.toMap());
  }

  Stream<List<Device>> getDevices() {
    return _db
        .collection('devices')
        .where('available', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Device.fromDoc).toList());
  }

  Stream<List<Device>> getDevicesByCategory(String category) {
    return _db
        .collection('devices')
        .where('available', isEqualTo: true)
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Device.fromDoc).toList());
  }

  Stream<List<Device>> getMyDevices(String ownerId) {
    return _db
        .collection('devices')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Device.fromDoc).toList());
  }

  Future<Device?> getDeviceById(String id) async {
    final doc = await _db.collection('devices').doc(id).get();
    if (!doc.exists) return null;
    return Device.fromDoc(doc);
  }

  Future<void> updateAvailability(String deviceId, bool available) async {
    await _db.collection('devices').doc(deviceId).update({'available': available});
  }

  Future<void> deleteDevice(String deviceId) async {
    await _db.collection('devices').doc(deviceId).delete();
  }
}