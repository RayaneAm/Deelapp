import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../features/auth/auth_service.dart';
import '../../shared/models/rental_model.dart';
import '../../shared/services/rental_service.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser!.uid;
    final rentalService = RentalService();
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Mijn dashboard')),
      body: StreamBuilder<List<Rental>>(
        stream: rentalService.getOwnerRentals(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rentals = snapshot.data ?? [];
          final pending = rentals.where((r) => r.status == RentalStatus.pending).toList();
          final approved = rentals.where((r) => r.status == RentalStatus.approved).toList();
          final others = rentals.where((r) => r.status != RentalStatus.pending && r.status != RentalStatus.approved).toList();

          if (rentals.isEmpty) {
            return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.pending_actions, size: 60, color: Colors.grey),
              SizedBox(height: 12),
              Text('Nog geen reserveringsaanvragen', style: TextStyle(color: Colors.grey)),
            ]));
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (pending.isNotEmpty) ...[
                const _SectionHeader(title: 'In afwachting', color: Colors.orange),
                ...pending.map((r) => _DashboardCard(rental: r, dateFormat: dateFormat, rentalService: rentalService)),
              ],
              if (approved.isNotEmpty) ...[
                const _SectionHeader(title: 'Goedgekeurd', color: Colors.green),
                ...approved.map((r) => _DashboardCard(rental: r, dateFormat: dateFormat, rentalService: rentalService)),
              ],
              if (others.isNotEmpty) ...[
                const _SectionHeader(title: 'Geschiedenis', color: Colors.grey),
                ...others.map((r) => _DashboardCard(rental: r, dateFormat: dateFormat, rentalService: rentalService)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final Rental rental;
  final DateFormat dateFormat;
  final RentalService rentalService;
  const _DashboardCard({required this.rental, required this.dateFormat, required this.rentalService});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(6),
                child: SizedBox(width: 60, height: 60,
                  child: rental.deviceImageUrl.isNotEmpty
                      ? Image.network(rental.deviceImageUrl, fit: BoxFit.cover)
                      : const Icon(Icons.image, color: Colors.grey))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rental.deviceTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Huurder: ${rental.renterName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text('${dateFormat.format(rental.startDate)} → ${dateFormat.format(rental.endDate)}',
                    style: const TextStyle(fontSize: 12)),
                Text('€${rental.totalPrice.toStringAsFixed(2)} (${rental.days} dag(en))',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ])),
            ]),
            if (rental.status == RentalStatus.pending) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => rentalService.rejectRental(rental.id),
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('Weigeren', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                )),
                const SizedBox(width: 8),
                Expanded(child: FilledButton.icon(
                  onPressed: () => rentalService.approveRental(rental.id),
                  icon: const Icon(Icons.check),
                  label: const Text('Goedkeuren'),
                )),
              ]),
            ],
            if (rental.status == RentalStatus.approved) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => rentalService.completeRental(rental.id),
                icon: const Icon(Icons.done_all),
                label: const Text('Markeer als voltooid'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}