import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/api_client.dart';

class StructuredAddress {
  StructuredAddress({
    this.formattedAddress = '',
    this.addressLine = '',
    this.building = '',
    this.floor = '',
    this.landmark = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.country = '',
    this.latitude,
    this.longitude,
    this.placeId,
    this.instructions = '',
    this.label = 'Delivery',
    this.saveToProfile = false,
  });

  String formattedAddress;
  String addressLine;
  String building;
  String floor;
  String landmark;
  String city;
  String state;
  String pincode;
  String country;
  double? latitude;
  double? longitude;
  String? placeId;
  String instructions;
  String label;
  bool saveToProfile;

  String get fullDisplayAddress {
    final parts = <String>[];
    if (building.isNotEmpty) parts.add(building);
    if (floor.isNotEmpty) parts.add(floor);
    if (addressLine.isNotEmpty && !parts.contains(addressLine)) {
      parts.add(addressLine);
    } else if (formattedAddress.isNotEmpty && parts.isEmpty) {
      parts.add(formattedAddress);
    }
    if (landmark.isNotEmpty) parts.add('Near $landmark');
    if (city.isNotEmpty && !parts.contains(city)) parts.add(city);
    if (pincode.isNotEmpty && !parts.contains(pincode)) parts.add(pincode);

    return parts.isNotEmpty ? parts.join(', ') : formattedAddress;
  }

  Map<String, dynamic> toMap() {
    return {
      'formattedAddress': fullDisplayAddress,
      'addressLine': addressLine.isNotEmpty ? addressLine : formattedAddress,
      'building': building,
      'floor': floor,
      'landmark': landmark,
      'city': city,
      'state': state,
      'pincode': pincode,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'placeId': placeId,
      'instructions': instructions,
      'label': label,
      'saveAddress': saveToProfile,
    };
  }
}

class AddressAutocompleteField extends StatefulWidget {
  const AddressAutocompleteField({
    super.key,
    required this.api,
    this.initialAddress,
    this.onAddressSelected,
    this.allowSave = true,
    this.labelText = 'Delivery / Installation Address',
    this.hintText = 'Enter street, shop, area or landmark',
    this.showExtraFields = true,
    this.isRequired = true,
  });

  final ApiClient api;
  final String? initialAddress;
  final ValueChanged<StructuredAddress>? onAddressSelected;
  final bool allowSave;
  final String labelText;
  final String hintText;
  final bool showExtraFields;
  final bool isRequired;

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  late final TextEditingController _searchCtrl;
  final _buildingCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();

  final _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  Timer? _debounce;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _suggestions = [];
  bool _showOverlay = false;
  OverlayEntry? _overlayEntry;

  List<Map<String, dynamic>> _savedAddresses = [];

  late StructuredAddress _currentAddress;
  bool _extraDetailsExpanded = false;

  @override
  void initState() {
    super.initState();
    _currentAddress = StructuredAddress(
      formattedAddress: widget.initialAddress ?? '',
      addressLine: widget.initialAddress ?? '',
    );
    _searchCtrl = TextEditingController(text: widget.initialAddress ?? '');

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _hideSuggestions();
      }
    });

    _loadSavedAddresses();
  }

  Future<void> _loadSavedAddresses() async {
    try {
      final list = await widget.api.getSavedAddresses();
      if (mounted) {
        setState(() {
          _savedAddresses = list;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _searchCtrl.dispose();
    _buildingCtrl.dispose();
    _floorCtrl.dispose();
    _landmarkCtrl.dispose();
    _instructionsCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();

    _currentAddress.formattedAddress = trimmed;
    _currentAddress.addressLine = trimmed;
    _notifyAddressChanged();

    if (trimmed.length < 3) {
      _hideSuggestions();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchSuggestions(trimmed);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _showSuggestionsDropdown();

    try {
      final results = await widget.api.autocompleteLocation(query);
      if (!mounted) return;

      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
      _updateOverlay();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load address suggestions. Tap to retry.';
      });
      _updateOverlay();
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> item) async {
    _hideSuggestions();
    final placeId = item['placeId']?.toString() ?? '';
    final provider = item['provider']?.toString();
    final description = item['description']?.toString() ?? '';

    _searchCtrl.text = description;
    _currentAddress.formattedAddress = description;
    _currentAddress.addressLine = description;
    _currentAddress.placeId = placeId;

    setState(() => _isLoading = true);
    try {
      if (placeId.isNotEmpty) {
        final details = await widget.api.getLocationDetails(
          placeId,
          provider: provider,
        );

        if (details.isNotEmpty) {
          _currentAddress.formattedAddress =
              details['formattedAddress']?.toString() ?? description;
          _currentAddress.addressLine =
              details['addressLine']?.toString() ?? description;
          _currentAddress.city = details['city']?.toString() ?? '';
          _currentAddress.state = details['state']?.toString() ?? '';
          _currentAddress.pincode = details['pincode']?.toString() ?? '';
          _currentAddress.country = details['country']?.toString() ?? '';

          final lat = details['latitude'];
          final lon = details['longitude'];
          if (lat != null) _currentAddress.latitude = (lat as num).toDouble();
          if (lon != null) _currentAddress.longitude = (lon as num).toDouble();

          _searchCtrl.text = _currentAddress.formattedAddress;
        }
      }
    } catch (_) {
      // Keep basic formatted address on lookup failure
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _notifyAddressChanged();
    }
  }

  void _selectSavedAddress(Map<String, dynamic> addr) {
    final addrLine = addr['addressLine']?.toString() ??
        addr['address_line']?.toString() ??
        '';
    final city = addr['city']?.toString() ?? '';
    final state = addr['state']?.toString() ?? '';
    final pincode = addr['pincode']?.toString() ?? '';

    final full = [addrLine, city, state, pincode]
        .where((s) => s.trim().isNotEmpty)
        .join(', ');

    _searchCtrl.text = full.isNotEmpty ? full : addrLine;
    _currentAddress = StructuredAddress(
      formattedAddress: full.isNotEmpty ? full : addrLine,
      addressLine: addrLine,
      city: city,
      state: state,
      pincode: pincode,
      label: addr['label']?.toString() ?? 'Saved',
    );

    final lat = addr['latitude'];
    final lon = addr['longitude'];
    if (lat != null) _currentAddress.latitude = (lat as num).toDouble();
    if (lon != null) _currentAddress.longitude = (lon as num).toDouble();

    _hideSuggestions();
    setState(() {});
    _notifyAddressChanged();
  }

  void _notifyAddressChanged() {
    _currentAddress.building = _buildingCtrl.text.trim();
    _currentAddress.floor = _floorCtrl.text.trim();
    _currentAddress.landmark = _landmarkCtrl.text.trim();
    _currentAddress.instructions = _instructionsCtrl.text.trim();

    widget.onAddressSelected?.call(_currentAddress);
  }

  void _showSuggestionsDropdown() {
    if (_showOverlay) {
      _updateOverlay();
      return;
    }
    _showOverlay = true;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideSuggestions() {
    _showOverlay = false;
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? Size.zero;

    return OverlayEntry(
      builder: (ctx) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: AppColors.navyCard,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: AppColors.navyCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
              ),
              child: _buildOverlayContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.gold),
            ),
            SizedBox(width: 12),
            Text('Searching live address suggestions...',
                style: TextStyle(color: AppColors.white70, fontSize: 13)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: InkWell(
          onTap: () => _fetchSuggestions(_searchCtrl.text.trim()),
          child: Row(
            children: [
              const Icon(Icons.refresh, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style:
                      const TextStyle(color: AppColors.goldLight, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No matching location found. You can enter address manually.',
          style: TextStyle(color: AppColors.white54, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      shrinkWrap: true,
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) =>
          Divider(color: AppColors.navyLight.withValues(alpha: 0.5), height: 1),
      itemBuilder: (ctx, idx) {
        final item = _suggestions[idx];
        final main = item['mainText']?.toString() ?? '';
        final secondary = item['secondaryText']?.toString() ?? '';

        return ListTile(
          dense: true,
          leading: const Icon(Icons.location_on_outlined,
              color: AppColors.gold, size: 20),
          title: Text(
            main,
            style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14),
          ),
          subtitle: secondary.isNotEmpty
              ? Text(
                  secondary,
                  style:
                      const TextStyle(color: AppColors.white54, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          onTap: () => _selectSuggestion(item),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Saved Addresses Chips ──────────────────────────────────────────
        if (_savedAddresses.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.bookmark_border, color: AppColors.gold, size: 16),
              SizedBox(width: 6),
              Text(
                'Saved Addresses:',
                style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _savedAddresses.map((addr) {
                final label = addr['label']?.toString() ?? 'Address';
                final isDefault = addr['isDefault'] == true;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(
                      label.toLowerCase() == 'home'
                          ? Icons.home_outlined
                          : label.toLowerCase() == 'shop'
                              ? Icons.storefront_outlined
                              : Icons.business_outlined,
                      size: 16,
                      color: isDefault ? AppColors.navyDeep : AppColors.gold,
                    ),
                    label: Text(label),
                    backgroundColor:
                        isDefault ? AppColors.gold : AppColors.navyCard,
                    labelStyle: TextStyle(
                      color: isDefault ? AppColors.navyDeep : AppColors.white,
                      fontSize: 12,
                      fontWeight:
                          isDefault ? FontWeight.w700 : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDefault
                            ? AppColors.gold
                            : AppColors.navyLight,
                      ),
                    ),
                    onPressed: () => _selectSavedAddress(addr),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Main Search Field ──────────────────────────────────────────────
        CompositedTransformTarget(
          link: _layerLink,
          child: TextFormField(
            controller: _searchCtrl,
            focusNode: _focusNode,
            style: const TextStyle(color: AppColors.white, fontSize: 14),
            onChanged: _onSearchChanged,
            validator: widget.isRequired
                ? (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter delivery / installation address'
                    : null
                : null,
            decoration: InputDecoration(
              labelText: widget.labelText,
              labelStyle: const TextStyle(color: AppColors.gold, fontSize: 13),
              hintText: widget.hintText,
              hintStyle:
                  const TextStyle(color: AppColors.white54, fontSize: 13),
              filled: true,
              fillColor: AppColors.navyCard,
              prefixIcon: const Icon(Icons.search, color: AppColors.gold),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.gold),
                      ),
                    ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear,
                          color: AppColors.white54, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                    ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.navyLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.navyLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
              ),
            ),
          ),
        ),

        // ── Structured Address Details Toggle ──────────────────────────────
        if (widget.showExtraFields) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              setState(() => _extraDetailsExpanded = !_extraDetailsExpanded);
            },
            child: Row(
              children: [
                Icon(
                  _extraDetailsExpanded
                      ? Icons.arrow_drop_down
                      : Icons.arrow_right,
                  color: AppColors.gold,
                  size: 20,
                ),
                Text(
                  _extraDetailsExpanded
                      ? 'Hide extra delivery details'
                      : 'Add Shop/Building #, Landmark or instructions (optional)',
                  style: const TextStyle(
                      color: AppColors.goldLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (_extraDetailsExpanded) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _buildingCtrl,
                    style: const TextStyle(color: AppColors.white, fontSize: 13),
                    onChanged: (_) => _notifyAddressChanged(),
                    decoration: InputDecoration(
                      labelText: 'Shop / House / Building #',
                      labelStyle:
                          const TextStyle(color: AppColors.white70, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.navyCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppColors.navyLight),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _floorCtrl,
                    style: const TextStyle(color: AppColors.white, fontSize: 13),
                    onChanged: (_) => _notifyAddressChanged(),
                    decoration: InputDecoration(
                      labelText: 'Floor / Unit',
                      labelStyle:
                          const TextStyle(color: AppColors.white70, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.navyCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppColors.navyLight),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _landmarkCtrl,
              style: const TextStyle(color: AppColors.white, fontSize: 13),
              onChanged: (_) => _notifyAddressChanged(),
              decoration: InputDecoration(
                labelText: 'Nearby Landmark',
                labelStyle:
                    const TextStyle(color: AppColors.white70, fontSize: 12),
                filled: true,
                fillColor: AppColors.navyCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.navyLight),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _instructionsCtrl,
              style: const TextStyle(color: AppColors.white, fontSize: 13),
              onChanged: (_) => _notifyAddressChanged(),
              decoration: InputDecoration(
                labelText: 'Delivery Instructions (optional)',
                labelStyle:
                    const TextStyle(color: AppColors.white70, fontSize: 12),
                filled: true,
                fillColor: AppColors.navyCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.navyLight),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            if (widget.allowSave) ...[
              const SizedBox(height: 4),
              CheckboxListTile(
                value: _currentAddress.saveToProfile,
                onChanged: (val) {
                  setState(() {
                    _currentAddress.saveToProfile = val == true;
                  });
                  _notifyAddressChanged();
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.gold,
                title: const Text(
                  'Save this delivery address to my profile',
                  style: TextStyle(color: AppColors.white70, fontSize: 13),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ],
        ],
      ],
    );
  }
}
