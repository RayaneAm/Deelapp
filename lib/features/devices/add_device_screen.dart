import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  Uint8List? _imageBytes;
  String? _imageFileName;

  final _deviceService = DeviceService();
  final _imagePicker = ImagePicker();

  static const _cloudName = 'dyqj0g0dn';
  static const _uploadPreset = 'wqgs2gzo';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageFileName = picked.name;
      });
    }
  }

  Future<String?> _uploadToCloudinary() async {
    if (_imageBytes == null) return null;
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        _imageBytes!,
        filename: _imageFileName ?? 'image.jpg',
      ));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    final json = jsonDecode(body);
    return json['secure_url'];
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
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(city)}&format=json&limit=1'
      );
      final response = await http.get(uri, headers: {'User-Agent': 'DeelApp/1.0'});
      print('STATUS: ${response.statusCode}');
      print('BODY: ${response.body}');
      final data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lng = double.parse(data[0]['lon']);
        setState(() { _lat = lat; _lng = lng; _city = city; });
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stad niet gevonden, probeer opnieuw')));
      }
    } catch (e) {
      print('FOUT: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout: $e')));
    }
  }
}
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voeg een foto toe')));
      return;
    }
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

      // Upload foto naar Cloudinary
      final imageUrl = await _uploadToCloudinary() ?? '';

      final device = Device(
        id: '',
        ownerId: uid,
        ownerName: ownerName,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        imageUrl: imageUrl,
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
              // Foto picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: _imageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Tik om foto te kiezen',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
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