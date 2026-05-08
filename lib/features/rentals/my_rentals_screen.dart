import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../features/auth/auth_service.dart';
import '../../shared/models/rental_model.dart';
import '../../shared/services/rental_service.dart';

class MyRentalsScreen extends StatelessWidget {
  const MyRentalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser!.uid;
    final rentalService = RentalService();
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Mijn reserveringen')),
      body: StreamBuilder<List<Rental>>(
        stream: rentalService.getRenterRentals(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rentals = snapshot.data ?? [];
          if (rentals.isEmpty) {
            return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.inbox_outlined, size: 60, color: Colors.grey),
              SizedBox(height: 12),
              Text('Geen reserveringen', style: TextStyle(color: Colors.grey)),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rentals.length,
            itemBuilder: (_, i) => _RentalCard(rental: rentals[i], dateFormat: dateFormat),
          );
        },
      ),
    );
  }
}

class _RentalCard extends StatelessWidget {
  final Rental rental;
  final DateFormat dateFormat;
  const _RentalCard({required this.rental, required this.dateFormat});

  Color _statusColor() {
    switch (rental.status) {
      case RentalStatus.pending: return Colors.orange;
      case RentalStatus.approved: return Colors.green;
      case RentalStatus.rejected: return Colors.red;
      case RentalStatus.completed: return Colors.blue;
    }
  }

  String _statusLabel() {
    switch (rental.status) {
      case RentalStatus.pending: return 'In afwachting';
      case RentalStatus.approved: return 'Goedgekeurd';
      case RentalStatus.rejected: return 'Geweigerd';
      case RentalStatus.completed: return 'Voltooid';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 70, height: 70,
                child: rental.deviceImageUrl.isNotEmpty
                    ? Image.network(rental.deviceImageUrl, fit: BoxFit.cover)
                    : const Icon(Icons.image, color: Colors.grey))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rental.deviceTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${dateFormat.format(rental.startDate)} → ${dateFormat.format(rental.endDate)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text('${rental.days} dag(en) · €${rental.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor().withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _statusColor()),
              ),
              child: Text(_statusLabel(), style: TextStyle(color: _statusColor(), fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}