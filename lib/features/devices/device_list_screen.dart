import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/auth_service.dart';
import '../../shared/models/device_model.dart';
import '../../shared/services/device_service.dart';
import '../../shared/widgets/device_card.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final _deviceService = DeviceService();
  final _searchController = TextEditingController();
  String? _selectedCategory;
  String _searchQuery = '';
  SearchType _searchType = SearchType.city;
  bool _distanceFilterEnabled = false;
  double _maxDistanceKm = 10;
  double? _userLat;
  double? _userLng;
  bool _locating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _setMyLiveLocation() async {
    setState(() => _locating = true);
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
      if (!mounted) return;
      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij locatie ophalen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openDistanceFilterSheet() async {
    var localEnabled = _distanceFilterEnabled;
    var localRadius = _maxDistanceKm;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Filter op bereik'),
                    value: localEnabled,
                    onChanged: (value) =>
                        setModalState(() => localEnabled = value),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: _locating
                        ? null
                        : () async {
                            await _setMyLiveLocation();
                            if (context.mounted) {
                              setModalState(() {});
                            }
                          },
                    icon: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(
                      _userLat == null
                          ? 'Gebruik mijn live locatie'
                          : 'Live locatie ingesteld ✓',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Radius: ${localRadius.toStringAsFixed(1)} km'),
                  Slider(
                    value: localRadius,
                    min: 1,
                    max: 50,
                    divisions: 49,
                    label: '${localRadius.toStringAsFixed(1)} km',
                    onChanged: localEnabled
                        ? (value) => setModalState(() => localRadius = value)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _distanceFilterEnabled = localEnabled;
                        _maxDistanceKm = localRadius;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Toepassen'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('DeelApp'),
        actions: [
          IconButton(
            icon: Icon(
              _distanceFilterEnabled ? Icons.radar : Icons.radar_outlined,
            ),
            tooltip: 'Bereik filter (${_maxDistanceKm.toStringAsFixed(0)} km)',
            onPressed: _openDistanceFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            tooltip: 'Mijn dashboard',
            onPressed: () => context.push('/dashboard'),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'Mijn reserveringen',
            onPressed: () => context.push('/my-rentals'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Uitloggen',
            onPressed: () async {
              await authService.logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Kies waarop je zoekt
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Stad'),
                  selected: _searchType == SearchType.city,
                  onSelected: (_) =>
                      setState(() => _searchType = SearchType.city),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Product'),
                  selected: _searchType == SearchType.product,
                  onSelected: (_) =>
                      setState(() => _searchType = SearchType.product),
                ),
              ],
            ),
          ),
          // Zoekbalk
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _searchType == SearchType.city
                    ? 'Zoek op stad...'
                    : 'Zoek op product...',
                prefixIcon: Icon(
                  _searchType == SearchType.city
                      ? Icons.location_on_outlined
                      : Icons.inventory_2_outlined,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: 8),
          // Categorie filters
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Alle'),
                    selected: _selectedCategory == null,
                    onSelected: (_) => setState(() => _selectedCategory = null),
                  ),
                ),
                ...deviceCategories.map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat),
                        selected: _selectedCategory == cat,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                      ),
                    )),
              ],
            ),
          ),
          // Lijst
          Expanded(
            child: StreamBuilder<List<Device>>(
              stream: _selectedCategory == null
                  ? _deviceService.getDevices()
                  : _deviceService.getDevicesByCategory(_selectedCategory!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Fout: ${snapshot.error}'));
                }
                var devices = snapshot.data ?? [];
                final isDistanceActive = _distanceFilterEnabled &&
                    _userLat != null &&
                    _userLng != null;

                // Filter op stad of product
                if (_searchQuery.isNotEmpty) {
                  devices = devices.where((d) {
                    if (_searchType == SearchType.city) {
                      return d.city.toLowerCase().contains(_searchQuery);
                    }
                    return d.title.toLowerCase().contains(_searchQuery);
                  }).toList();
                }

                if (isDistanceActive) {
                  devices = devices.where((d) {
                    final distanceMeters = Geolocator.distanceBetween(
                      _userLat!,
                      _userLng!,
                      d.lat,
                      d.lng,
                    );
                    return distanceMeters <= (_maxDistanceKm * 1000);
                  }).toList();
                }

                if (devices.isEmpty) {
                  return Column(
                    children: [
                      if (isDistanceActive)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '0 producten binnen ${_maxDistanceKm.toStringAsFixed(1)} km',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off,
                                  size: 60, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('Geen toestellen gevonden',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    if (isDistanceActive)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${devices.length} producten binnen ${_maxDistanceKm.toStringAsFixed(1)} km',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: devices.length,
                        itemBuilder: (_, i) => DeviceCard(
                          device: devices[i],
                          onTap: () => context.push('/device/${devices[i].id}'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-device'),
        icon: const Icon(Icons.add),
        label: const Text('Verhuren'),
      ),
    );
  }
}

enum SearchType { city, product }
