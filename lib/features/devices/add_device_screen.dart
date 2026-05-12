import 'dart:typed_data';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  bool _useLiveLocation = false;
  double _radiusKm = 2.0;
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
    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
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

  Future<void> _pickCityManually() async {
    final controller = TextEditingController();
    final city = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kies je stad'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'bv. Gent, Antwerpen...'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (city == null || city.isEmpty) return;

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(city)}&format=json&limit=1',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'DeelApp/1.0'},
      );
      final data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lng = double.parse(data[0]['lon']);
        setState(() {
          _lat = lat;
          _lng = lng;
          _city = city;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Stad niet gevonden, probeer opnieuw')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout: $e')),
        );
      }
    }
  }

  Future<void> _shareLiveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Locatieservice staat uit.')),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Locatie-permissie geweigerd.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _setLocation(position.latitude, position.longitude,
          updateCity: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij live locatie: $e')),
        );
      }
    }
  }

  Future<void> _setLocation(
    double lat,
    double lng, {
    bool updateCity = false,
  }) async {
    String city = _city;
    if (updateCity) {
      try {
        final marks = await placemarkFromCoordinates(lat, lng);
        final first = marks.isNotEmpty ? marks.first : null;
        city = first?.locality ?? first?.subAdministrativeArea ?? _city;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _lat = lat;
      _lng = lng;
      _city = city;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Voeg een foto toe')));
      return;
    }
    if (_lat == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Voeg je locatie toe')));
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
        rentalRadiusKm: _radiusKm,
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
                            Icon(Icons.add_a_photo,
                                size: 40, color: Colors.grey),
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
                    labelText: 'Beschrijving', border: OutlineInputBorder()),
                validator: (v) => v!.isNotEmpty ? null : 'Vereist',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                    labelText: 'Categorie', border: OutlineInputBorder()),
                items: deviceCategories
                    .map(
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)))
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
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Zelf kiezen'),
                    selected: !_useLiveLocation,
                    onSelected: (_) => setState(() => _useLiveLocation = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Je live locatie delen'),
                    selected: _useLiveLocation,
                    onSelected: (_) => setState(() => _useLiveLocation = true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed:
                    _useLiveLocation ? _shareLiveLocation : _pickCityManually,
                icon: Icon(
                    _useLiveLocation ? Icons.gps_fixed : Icons.location_city),
                label: Text(
                  _lat == null
                      ? (_useLiveLocation
                          ? 'Je live locatie delen'
                          : 'Kies je stad')
                      : 'Locatie: ${_city.isEmpty ? 'Gekozen' : _city} ✓',
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 220,
                  child: GoogleMap(
                    myLocationEnabled: _useLiveLocation,
                    myLocationButtonEnabled: false,
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_lat ?? 50.8503, _lng ?? 4.3517),
                      zoom: _lat == null ? 7 : 14,
                    ),
                    onTap: _useLiveLocation
                        ? null
                        : (pos) => _setLocation(
                              pos.latitude,
                              pos.longitude,
                              updateCity: true,
                            ),
                    markers: {
                      if (_lat != null && _lng != null)
                        Marker(
                          markerId: const MarkerId('selected-location'),
                          position: LatLng(_lat!, _lng!),
                          draggable: !_useLiveLocation,
                          onDragEnd: (pos) => _setLocation(
                            pos.latitude,
                            pos.longitude,
                            updateCity: true,
                          ),
                        ),
                    },
                    circles: {
                      if (_lat != null && _lng != null)
                        Circle(
                          circleId: const CircleId('radius-circle'),
                          center: LatLng(_lat!, _lng!),
                          radius: _radiusKm * 1000,
                          strokeWidth: 2,
                          strokeColor: Colors.blue,
                          fillColor: Colors.blue.withValues(alpha: 0.15),
                        ),
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('Bereik: ${_radiusKm.toStringAsFixed(1)} km'),
              Slider(
                value: _radiusKm,
                min: 0.5,
                max: 20,
                divisions: 39,
                label: '${_radiusKm.toStringAsFixed(1)} km',
                onChanged: (value) => setState(() => _radiusKm = value),
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
