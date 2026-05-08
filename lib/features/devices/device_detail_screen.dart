import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/auth/auth_service.dart';
import '../../shared/models/device_model.dart';
import '../../shared/models/rental_model.dart';
import '../../shared/services/device_service.dart';
import '../../shared/services/rental_service.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String deviceId;
  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final _deviceService = DeviceService();
  final _rentalService = RentalService();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  DateTime? _startDate;
  DateTime? _endDate;
  bool _booking = false;
  List<DateTime> _bookedDates = [];

  @override
  void initState() {
    super.initState();
    _loadBookedDates();
  }

  Future<void> _loadBookedDates() async {
    final dates = await _rentalService.getBookedDates(widget.deviceId);
    setState(() => _bookedDates = dates);
  }

  bool _isDateBooked(DateTime date) {
    return _bookedDates.any((d) =>
        d.year == date.year && d.month == date.month && d.day == date.day);
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? now : (_startDate ?? now).add(const Duration(days: 1)),
      firstDate: isStart ? now : (_startDate ?? now).add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 90)),
      selectableDayPredicate: (day) => !_isDateBooked(day),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  double _calculateTotal(Device device) {
    if (_startDate == null || _endDate == null) return 0;
    final days = _endDate!.difference(_startDate!).inDays + 1;
    return days * device.pricePerDay;
  }

  Future<void> _bookDevice(Device device) async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kies een begin- en einddatum')));
      return;
    }
    // Check of geen enkele dag al geboekt is
    final range = List.generate(
      _endDate!.difference(_startDate!).inDays + 1,
      (i) => _startDate!.add(Duration(days: i)),
    );
    if (range.any((d) => _isDateBooked(d))) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sommige datums zijn al geboekt!')));
      return;
    }

    setState(() => _booking = true);
    try {
      final authService = context.read<AuthService>();
      final uid = authService.currentUser!.uid;
      final renterName = await authService.getCurrentUserName() ?? 'Anoniem';
      final rental = Rental(
        id: '',
        deviceId: device.id,
        deviceTitle: device.title,
        deviceImageUrl: device.imageUrl,
        renterId: uid,
        renterName: renterName,
        ownerId: device.ownerId,
        startDate: _startDate!,
        endDate: _endDate!,
        totalPrice: _calculateTotal(device),
        status: RentalStatus.pending,
        createdAt: DateTime.now(),
      );
      await _rentalService.createRental(rental);
      await _loadBookedDates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reservering aangevraagd!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fout: $e')));
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  void _openMaps(Device device) async {
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${device.lat},${device.lng}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Device?>(
      future: _deviceService.getDeviceById(widget.deviceId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final device = snapshot.data;
        if (device == null) {
          return const Scaffold(body: Center(child: Text('Toestel niet gevonden')));
        }
        final currentUserId = context.read<AuthService>().currentUser?.uid;
        final isOwner = device.ownerId == currentUserId;
        final total = _calculateTotal(device);

        return Scaffold(
          appBar: AppBar(title: Text(device.title)),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 240,
                  child: device.imageUrl.isNotEmpty
                      ? Image.network(device.imageUrl, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, size: 80, color: Colors.grey)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Chip(label: Text(device.category)),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(device.available ? 'Beschikbaar' : 'Niet beschikbaar'),
                          backgroundColor: device.available ? Colors.green[100] : Colors.red[100],
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        '€${device.pricePerDay.toStringAsFixed(2)} per dag',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(device.city, style: const TextStyle(color: Colors.grey)),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _openMaps(device),
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: const Text('Bekijk op Maps'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ]),
                      const Divider(height: 24),
                      const Text('Beschrijving',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(device.description),
                      const Divider(height: 24),
                      const Text('Aangeboden door',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(device.ownerName),

                      if (_bookedDates.isNotEmpty) ...[
                        const Divider(height: 24),
                        const Text('Al geboekte periodes',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _getBookedRanges().map((range) => Chip(
                            label: Text(range, style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.red[50],
                          )).toList(),
                        ),
                      ],

                      if (!isOwner && device.available) ...[
                        const Divider(height: 32),
                        const Text('Reserveren',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        const Text('Grijze datums zijn al geboekt',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickDate(true),
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(_startDate == null
                                  ? 'Startdatum'
                                  : _dateFormat.format(_startDate!)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _startDate == null ? null : () => _pickDate(false),
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(_endDate == null
                                  ? 'Einddatum'
                                  : _dateFormat.format(_endDate!)),
                            ),
                          ),
                        ]),
                        if (total > 0) ...[
                          const SizedBox(height: 12),
                          Text('Totaal: €${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _booking ? null : () => _bookDevice(device),
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48)),
                          child: _booking
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Reserveer nu'),
                        ),
                      ],
                      if (isOwner)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text('Dit is jouw toestel.',
                              style: TextStyle(color: Colors.grey)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<String> _getBookedRanges() {
    if (_bookedDates.isEmpty) return [];
    final sorted = List<DateTime>.from(_bookedDates)..sort((a, b) => a.compareTo(b));
    final ranges = <String>[];
    DateTime? start = sorted.first;
    DateTime? prev = sorted.first;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i].difference(prev!).inDays == 1) {
        prev = sorted[i];
      } else {
        ranges.add(start == prev
            ? _dateFormat.format(start!)
            : '${_dateFormat.format(start!)} → ${_dateFormat.format(prev)}');
        start = sorted[i];
        prev = sorted[i];
      }
    }
    ranges.add(start == prev
        ? _dateFormat.format(start!)
        : '${_dateFormat.format(start!)} → ${_dateFormat.format(prev!)}');
    return ranges;
  }
}