import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/auth_service.dart';
import '../../shared/models/device_model.dart';
import '../../shared/services/device_service.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String _selectedCategory = deviceCategories.first;
  double? _lat;
  double? _lng;
  String _city = '';
  bool _loading = false;

  final _deviceService = DeviceService();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    final controller = TextEditingController();
    final city = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Jouw stad'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'bv. Gent, Antwerpen...'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuleer')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('OK')),
        ],
      ),
    );
    if (city != null && city.isNotEmpty) {
      setState(() {
        _lat = 51.0543;
        _lng = 3.7174;
        _city = city;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voeg je locatie toe')));
      return;
    }
    setState(() => _loading = true);
    try {
      final authService = context.read<AuthService>();
      final uid = authService.currentUser!.uid;
      final ownerName = await authService.getCurrentUserName() ?? 'Anoniem';
      final device = Device(
        id: '',
        ownerId: uid,
        ownerName: ownerName,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        imageUrl: '',
        pricePerDay: double.parse(_priceController.text.trim()),
        available: true,
        lat: _lat!,
        lng: _lng!,
        city: _city,
        createdAt: DateTime.now(),
      );
      await _deviceService.addDevice(device);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Toestel succesvol toegevoegd!')));
        context.go('/devices');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fout: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Toestel toevoegen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                    labelText: 'Naam toestel',
                    hintText: 'bv. Karcher stofzuiger',
                    border: OutlineInputBorder()),
                validator: (v) => v!.isNotEmpty ? null : 'Vereist',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Beschrijving',
                    border: OutlineInputBorder()),
                validator: (v) => v!.isNotEmpty ? null : 'Vereist',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                    labelText: 'Categorie', border: OutlineInputBorder()),
                items: deviceCategories
                    .map((cat) =>
                        DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Prijs per dag (€)',
                    prefixText: '€ ',
                    border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Vereist';
                  if (double.tryParse(v) == null) return 'Ongeldig bedrag';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _getLocation,
                icon: const Icon(Icons.my_location),
                label: Text(_lat == null
                    ? 'Gebruik mijn locatie'
                    : 'Locatie: $_city ✓'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Toestel toevoegen',
                        style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}