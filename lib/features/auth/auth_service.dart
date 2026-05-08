import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Huidige ingelogde gebruiker (null = niet ingelogd)
  User? get currentUser => _auth.currentUser;

  // Stream van auth state veranderingen
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Registreer een nieuwe gebruiker en sla profiel op in Firestore
  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Gebruikersprofiel opslaan in Firestore
    await _db.collection('users').doc(credential.user!.uid).set({
      'name': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });

    notifyListeners();
  }

  /// Login met e-mail en wachtwoord
  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    notifyListeners();
  }

  /// Uitloggen
  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }

  /// Haal de naam van de huidige gebruiker op uit Firestore
  Future<String?> getCurrentUserName() async {
    if (currentUser == null) return null;
    final doc = await _db.collection('users').doc(currentUser!.uid).get();
    return doc.data()?['name'];
  }
}