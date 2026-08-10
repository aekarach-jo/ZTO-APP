import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/delivery_branches.dart';
import '../../../../shared/utils/lao_phone_input.dart';
import '../../data/address_repository.dart';

/// Form for one address book entry (`/users/me/addresses`). Same three fields
/// plus a map pin as the send flow's recipient step, so a saved address can
/// prefill that flow as-is.
///
/// Opened without [address] it creates a new entry — which the backend always
/// makes the default. With [address] it edits that entry in place.
class DefaultForwardingAddressScreen extends ConsumerStatefulWidget {
  const DefaultForwardingAddressScreen({super.key, this.address});

  static const String routePath = '/profile/default-forwarding-address';

  final UserAddress? address;

  @override
  ConsumerState<DefaultForwardingAddressScreen> createState() =>
      _DefaultForwardingAddressScreenState();
}

class _DefaultForwardingAddressScreenState
    extends ConsumerState<DefaultForwardingAddressScreen> {
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _recipientAddressController = TextEditingController();
  final _courierController = TextEditingController();

  /// Delivery branch by display name; stored as [DeliveryBranch.code].
  String? _selectedBranch;

  /// Vientiane — where the pin starts before (or instead of) a device fix.
  static const LatLng _fallbackPinLocation = LatLng(17.9757, 102.6331);
  LatLng _pinLocation = _fallbackPinLocation;
  GoogleMapController? _mapController;

  /// The device fix is fetched once, and only until the customer moves the pin
  /// themselves — after that their choice wins.
  bool _hasMovedPinManually = false;
  bool _isLocatingDevice = false;

  /// True once the pin sits on a saved address or a device fix rather than the
  /// Vientiane fallback. A saved address can be Vientiane itself, so comparing
  /// coordinates would not tell the two apart.
  bool _hasPinTarget = false;

  /// The entry being edited: the one passed in, or the current default once
  /// the address book loads. Null means "saving creates a new one".
  UserAddress? _editing;
  bool _hydrated = false;
  bool _isSaving = false;

  bool get _isWidgetTest => const bool.fromEnvironment('FLUTTER_TEST');

  bool get _isUnsupportedDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  bool get _isFormComplete {
    final subscriberDigits = _recipientPhoneController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    return _recipientNameController.text.trim().isNotEmpty &&
        _recipientAddressController.text.trim().isNotEmpty &&
        subscriberDigits.length >= 6;
  }

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    if (address != null) {
      _hydrate(address);
    }
    _movePinToDeviceLocation();
  }

  /// Fills the form from a saved address. Runs once — either from the entry the
  /// caller passed in, or from the default entry once the book loads.
  void _hydrate(UserAddress address) {
    if (_hydrated) {
      return;
    }
    _hydrated = true;
    _editing = address;
    _recipientNameController.text = address.label;
    _recipientPhoneController.text = laoSubscriberDigitsOf(address.phone);
    _recipientAddressController.text = address.addressLine;
    _courierController.text = address.courier;
    // An unknown code means a branch this build does not list; leave the
    // dropdown empty rather than silently picking a different branch.
    _selectedBranch = deliveryBranchNameOf(address.branchCode);
    if (!_hasMovedPinManually &&
        (address.latitude != 0 || address.longitude != 0)) {
      _pinLocation = LatLng(address.latitude, address.longitude);
      _hasPinTarget = true;
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_pinLocation, 16),
      );
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _recipientAddressController.dispose();
    _courierController.dispose();
    super.dispose();
  }

  /// Starts the pin on the device's own position. Anything that can fail here —
  /// services off, permission refused, no fix in time — just leaves the
  /// Vientiane fallback in place; pinning by hand still works.
  ///
  /// A saved address outranks the device fix: it is the address being edited,
  /// not wherever the phone happens to be.
  Future<void> _movePinToDeviceLocation() async {
    if (_isLocatingDevice ||
        _hasMovedPinManually ||
        _hasPinTarget ||
        _isWidgetTest ||
        _isUnsupportedDesktop) {
      return;
    }
    _isLocatingDevice = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted || _hasMovedPinManually || _hasPinTarget) {
        return;
      }
      final target = LatLng(position.latitude, position.longitude);
      setState(() {
        _pinLocation = target;
        _hasPinTarget = true;
      });
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 16),
      );
    } catch (_) {
      // Keep the fallback pin.
    } finally {
      _isLocatingDevice = false;
    }
  }

  /// Phone in the shape the backend stores, i.e. the `20` prefix the field
  /// renders put back in front of the subscriber digits.
  String get _phoneForApi {
    final digits = _recipientPhoneController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    return digits.isEmpty ? '' : '20$digits';
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final repository = ref.read(addressRepositoryProvider);
    final editing = _editing;
    try {
      if (editing == null) {
        // A new address becomes the default on the backend, which is exactly
        // what this screen is for.
        await repository.createAddress(
          label: _recipientNameController.text.trim(),
          addressLine: _recipientAddressController.text.trim(),
          latitude: _pinLocation.latitude,
          longitude: _pinLocation.longitude,
          phone: _phoneForApi,
          courier: _courierController.text.trim(),
          branchCode: deliveryBranchCodeOf(_selectedBranch),
        );
      } else {
        await repository.updateAddress(
          editing.id,
          label: _recipientNameController.text.trim(),
          phone: _phoneForApi,
          addressLine: _recipientAddressController.text.trim(),
          courier: _courierController.text.trim(),
          branchCode: deliveryBranchCodeOf(_selectedBranch) ?? '',
          latitude: _pinLocation.latitude,
          longitude: _pinLocation.longitude,
          isDefault: true,
        );
      }
      ref.invalidate(userAddressesProvider);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile_forwarding_saved'.tr())),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[DefaultForwardingAddress] save failed error=$error');
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile_forwarding_save_failed'.tr())),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(
          widget.address == null
              ? 'profile_address_add'.tr()
              : 'profile_address_edit'.tr(),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111111),
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 24.h),
        children: [
          _InputLabel(text: 'send_recipient_name_label'.tr()),
          _InputField(
            key: const ValueKey('forwarding-input-recipient-name'),
            hint: 'send_recipient_name_hint'.tr(),
            controller: _recipientNameController,
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: 14.h),
          _InputLabel(text: 'send_recipient_phone_label'.tr()),
          _InputField(
            key: const ValueKey('forwarding-input-recipient-phone'),
            hint: 'send_recipient_phone_hint'.tr(),
            controller: _recipientPhoneController,
            onChanged: (_) => setState(() {}),
            prefixText: '+856 20 ',
            keyboardType: TextInputType.phone,
            inputFormatters: const [LaoSubscriberNumberFormatter()],
          ),
          SizedBox(height: 14.h),
          _InputLabel(text: 'send_recipient_address_label'.tr()),
          _InputField(
            key: const ValueKey('forwarding-input-recipient-address'),
            hint: 'send_recipient_address_hint'.tr(),
            controller: _recipientAddressController,
            onChanged: (_) => setState(() {}),
            maxLines: 3,
            minLines: 3,
          ),
          SizedBox(height: 14.h),
          _InputLabel(text: 'send_courier_label'.tr()),
          _InputField(
            key: const ValueKey('forwarding-input-courier'),
            hint: 'send_courier_hint'.tr(),
            controller: _courierController,
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: 14.h),
          _InputLabel(text: 'send_branch_label'.tr()),
          _BranchDropdown(
            key: const ValueKey('forwarding-input-branch'),
            value: _selectedBranch,
            onChanged: (branch) => setState(() => _selectedBranch = branch),
          ),
          SizedBox(height: 18.h),
          _buildMap(),
          SizedBox(height: 14.h),
          _buildCoordinates(),
          SizedBox(height: 24.h),
          _PrimaryActionButton(
            key: const ValueKey('forwarding-save-button'),
            label: 'profile_forwarding_save'.tr(),
            enabled: _isFormComplete && !_isSaving,
            busy: _isSaving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Container(
      height: 360.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFDDE4EE)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: Stack(
          children: [
            Positioned.fill(
              child: (_isWidgetTest || _isUnsupportedDesktop)
                  ? _MapPlaceholder(
                      message: _isUnsupportedDesktop
                          ? 'send_map_desktop_not_supported'.tr()
                          : 'send_map_placeholder'.tr(),
                    )
                  : GoogleMap(
                      key: const ValueKey('forwarding-google-map'),
                      initialCameraPosition: CameraPosition(
                        target: _pinLocation,
                        zoom: 14,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('forwarding_pin'),
                          position: _pinLocation,
                        ),
                      },
                      onMapCreated: (controller) {
                        _mapController = controller;
                        // The device fix can land before the map finishes
                        // creating, in which case there was no controller to
                        // move the camera with yet.
                        if (_hasPinTarget) {
                          controller.animateCamera(
                            CameraUpdate.newLatLngZoom(_pinLocation, 16),
                          );
                        }
                      },
                      onTap: (latLng) {
                        setState(() {
                          _hasMovedPinManually = true;
                          _hasPinTarget = true;
                          _pinLocation = latLng;
                        });
                      },
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      // The map sits inside the scrolling form, which otherwise
                      // wins every drag and leaves the map unpannable. Claim
                      // gestures that start on the map.
                      gestureRecognizers:
                          <Factory<OneSequenceGestureRecognizer>>{
                            Factory<OneSequenceGestureRecognizer>(
                              EagerGestureRecognizer.new,
                            ),
                          },
                    ),
            ),
            Positioned(
              left: 14.w,
              right: 14.w,
              top: 14.h,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: 10.h,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: AppTheme.brandBlueDark,
                      size: 16.sp,
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        'send_pin_instruction'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF1D1D1D),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinates() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'profile_forwarding_coordinates'.tr(),
            style: TextStyle(
              color: const Color(0xFF8390A3),
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '${_pinLocation.latitude.toStringAsFixed(6)}, '
            '${_pinLocation.longitude.toStringAsFixed(6)}',
            key: const ValueKey('forwarding-coordinates'),
            style: TextStyle(
              color: const Color(0xFF111111),
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InputLabel extends StatelessWidget {
  const _InputLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 2.w, bottom: 6.h),
      child: Text(
        text,
        style: TextStyle(
          color: const Color(0xFF6F7D8F),
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    super.key,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.maxLines = 1,
    this.minLines,
    this.prefixText,
    this.keyboardType,
    this.inputFormatters,
  });

  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final int? minLines;
  final String? prefixText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: const Color(0xFFA7AFBC),
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
        ),
        prefixText: prefixText,
        prefixStyle: TextStyle(
          color: const Color(0xFF111111),
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: const Color(0xFFF3F5F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      ),
    );
  }
}

class _BranchDropdown extends StatelessWidget {
  const _BranchDropdown({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      hint: Text(
        'send_branch_hint'.tr(),
        style: TextStyle(
          color: const Color(0xFFA7AFBC),
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
      items: [
        for (final branch in kDeliveryBranches)
          DropdownMenuItem<String>(
            key: ValueKey('forwarding-branch-option-${branch.code}'),
            value: branch.name,
            child: Text(branch.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF3F5F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE9EEF5),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF6F7D8F),
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54.h,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.brandBlueDark,
          disabledBackgroundColor: const Color(0xFFC5D3E4),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        child: busy
            ? SizedBox(
                width: 22.w,
                height: 22.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
              ),
      ),
    );
  }
}
