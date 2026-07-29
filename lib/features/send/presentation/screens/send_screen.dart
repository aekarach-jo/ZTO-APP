import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/lak_currency.dart';
import '../../../../shared/utils/lao_phone_input.dart';
import '../../application/send_forward_prefill_provider.dart';
import '../../data/send_repository.dart';
import '../../../home/data/home_parcel_repository.dart';
import '../../../main_layout/application/main_layout_navigation_provider.dart';
import '../../../parcel_payment/data/payment_repository.dart';
import '../../../parcel_payment/presentation/screens/parcel_payment_screen.dart';
import '../../../parcel_status/data/parcel_status_repository.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  String? _selectedParcelId;
  _SendStep _step = _SendStep.selectParcel;
  bool _isSubmitting = false;

  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _recipientAddressController = TextEditingController();
  final _courierController = TextEditingController();
  String? _selectedBranch;
  LatLng _pinLocation = const LatLng(17.9757, 102.6331);

  /// The branches parcels can be delivered to.
  static const List<String> _deliveryBranches = [
    'ອານຸສິດ',
    'ຮຸ່ງອາລຸນ',
    'ມີໄຊ',
  ];

  /// Order ที่สร้างไว้แล้วสำหรับ flow ปัจจุบัน — กันการสร้าง order ซ้ำ
  /// ถ้าผู้ใช้ย้อนกลับจากหน้าชำระเงินแล้วกดยืนยันอีกครั้ง
  ParcelOrder? _createdOrder;

  /// The phone field holds only what follows the `+856 20` prefix it shows.
  String get _recipientPhoneNumber {
    final digits = _recipientPhoneController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    return digits.isEmpty ? '' : '$laoMobilePrefix$digits';
  }

  bool get _isRecipientFormComplete {
    final subscriberDigits = _recipientPhoneController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    return _recipientNameController.text.trim().isNotEmpty &&
        _recipientAddressController.text.trim().isNotEmpty &&
        _courierController.text.trim().isNotEmpty &&
        _selectedBranch != null &&
        subscriberDigits.length >= 6;
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _recipientAddressController.dispose();
    _courierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parcelsAsync = ref.watch(sendParcelsProvider);

    // Forward tapped in the Parcel tab: pre-select that parcel and jump
    // straight to the recipient-details step.
    ref.listen<String?>(sendForwardPrefillProvider, (previous, next) {
      if (next == null) {
        return;
      }
      ref.read(sendForwardPrefillProvider.notifier).state = null;
      setState(() {
        _resetFlow();
        _selectedParcelId = next;
        _step = _SendStep.recipientDetails;
      });
    });

    return _step == _SendStep.selectParcel
        ? _buildSelectParcelStep(context, parcelsAsync)
        : _step == _SendStep.recipientDetails
        ? _buildRecipientStep(context, parcelsAsync)
        : _step == _SendStep.pinAddress
        ? _buildPinMapStep(context, parcelsAsync)
        : _buildPaymentStep(context, parcelsAsync);
  }

  Widget _buildSelectParcelStep(
    BuildContext context,
    AsyncValue<List<SendParcelItem>> parcelsAsync,
  ) {
    final hasSelection = _selectedParcelId != null;

    return _buildRefreshableListView(
      key: const ValueKey('send-select-step'),
      padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 20.h),
      children: [
        _Header(
          title: _SendTextKeys.title.tr(),
          onBack: () => _showNotImplementedSnack(context),
          backTooltip: _SendTextKeys.backTooltip.tr(),
        ),
        SizedBox(height: 12.h),
        Text(
          _SendTextKeys.subtitle.tr(),
          style: TextStyle(
            color: const Color(0xFF7B8798),
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        parcelsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return _SimpleStateCard(
                icon: Icons.inventory_2_outlined,
                message: _SendTextKeys.emptySelectableParcels,
              );
            }
            return Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _SendParcelCard(
                    key: ValueKey('send-item-${items[i].id}'),
                    item: items[i],
                    selected: _selectedParcelId == items[i].id,
                    onTap: () {
                      setState(() {
                        _selectedParcelId = items[i].id;
                        _createdOrder = null;
                      });
                    },
                  ),
                  if (i != items.length - 1) SizedBox(height: 12.h),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _SimpleStateCard(
            icon: Icons.error_outline,
            message: _SendTextKeys.loadParcelsError,
            actionLabel: _SendTextKeys.retry,
            onAction: () => ref.invalidate(sendParcelsProvider),
          ),
        ),
        SizedBox(height: 26.h),
        _PrimaryActionButton(
          key: const ValueKey('send-next-button'),
          label: _SendTextKeys.nextButton.tr(),
          enabled: hasSelection,
          onPressed: () {
            setState(() {
              _step = _SendStep.recipientDetails;
            });
          },
        ),
      ],
    );
  }

  Widget _buildRecipientStep(
    BuildContext context,
    AsyncValue<List<SendParcelItem>> parcelsAsync,
  ) {
    final selectedItem = _selectedParcel(parcelsAsync);
    if (selectedItem == null) {
      return _buildInvalidSelectionState();
    }

    return _buildRefreshableListView(
      key: const ValueKey('send-recipient-step'),
      padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 20.h),
      children: [
        _Header(
          title: _SendTextKeys.recipientTitle.tr(),
          onBack: () {
            setState(() {
              _step = _SendStep.selectParcel;
            });
          },
          backTooltip: _SendTextKeys.backTooltip.tr(),
        ),
        SizedBox(height: 12.h),
        _SelectedParcelSummary(item: selectedItem),
        SizedBox(height: 16.h),
        _InputLabel(text: _SendTextKeys.recipientNameLabel.tr()),
        _InputField(
          key: const ValueKey('send-input-recipient-name'),
          hint: _SendTextKeys.recipientNameHint.tr(),
          controller: _recipientNameController,
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: 14.h),
        _InputLabel(text: _SendTextKeys.recipientPhoneLabel.tr()),
        _InputField(
          key: const ValueKey('send-input-recipient-phone'),
          hint: _SendTextKeys.recipientPhoneHint.tr(),
          controller: _recipientPhoneController,
          onChanged: (_) => setState(() {}),
          prefixText: '+856 20 ',
          keyboardType: TextInputType.phone,
          inputFormatters: const [LaoSubscriberNumberFormatter()],
        ),
        SizedBox(height: 14.h),
        _InputLabel(text: _SendTextKeys.recipientAddressLabel.tr()),
        _InputField(
          key: const ValueKey('send-input-recipient-address'),
          hint: _SendTextKeys.recipientAddressHint.tr(),
          controller: _recipientAddressController,
          onChanged: (_) => setState(() {}),
          maxLines: 3,
          minLines: 3,
        ),
        SizedBox(height: 14.h),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InputLabel(text: _SendTextKeys.courierLabel.tr()),
                  _InputField(
                    key: const ValueKey('send-input-courier'),
                    hint: _SendTextKeys.courierHint.tr(),
                    controller: _courierController,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InputLabel(text: _SendTextKeys.branchLabel.tr()),
                  _DropdownField<String>(
                    key: const ValueKey('send-input-branch'),
                    hint: _SendTextKeys.branchHint.tr(),
                    value: _selectedBranch,
                    items: _deliveryBranches,
                    itemLabel: (branch) => branch,
                    onChanged: (branch) {
                      setState(() {
                        _selectedBranch = branch;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 24.h),
        _PrimaryActionButton(
          key: const ValueKey('send-pin-map-button'),
          label: _SendTextKeys.pinAddressButton.tr(),
          enabled: _isRecipientFormComplete,
          onPressed: () {
            setState(() {
              _step = _SendStep.pinAddress;
            });
          },
        ),
      ],
    );
  }

  Widget _buildPinMapStep(
    BuildContext context,
    AsyncValue<List<SendParcelItem>> parcelsAsync,
  ) {
    final selectedItem = _selectedParcel(parcelsAsync);
    if (selectedItem == null) {
      return _buildInvalidSelectionState();
    }
    final isWidgetTest = const bool.fromEnvironment('FLUTTER_TEST');
    final isUnsupportedDesktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux);

    return _buildRefreshableListView(
      key: const ValueKey('send-pin-step'),
      padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 20.h),
      children: [
        _Header(
          title: _SendTextKeys.pinTitle.tr(),
          onBack: () {
            setState(() {
              _step = _SendStep.recipientDetails;
            });
          },
          backTooltip: _SendTextKeys.backTooltip.tr(),
        ),
        SizedBox(height: 14.h),
        Container(
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
                  child: (isWidgetTest || isUnsupportedDesktop)
                      ? _MapPlaceholder(
                          message: isUnsupportedDesktop
                              ? _SendTextKeys.mapDesktopNotSupported.tr()
                              : _SendTextKeys.mapPlaceholder.tr(),
                        )
                      : GoogleMap(
                          key: const ValueKey('send-google-map'),
                          initialCameraPosition: CameraPosition(
                            target: _pinLocation,
                            zoom: 14,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('recipient_pin'),
                              position: _pinLocation,
                            ),
                          },
                          onTap: (latLng) {
                            setState(() {
                              _pinLocation = latLng;
                            });
                          },
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                          // The map sits inside the scrolling form, which
                          // otherwise wins every drag and leaves the map
                          // unpannable. Claim gestures that start on the map.
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
                            _SendTextKeys.pinInstruction.tr(),
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
        ),
        SizedBox(height: 14.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5F8),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _SendTextKeys.pinCoordinateLabel.tr(
                  args: [selectedItem.trackNo],
                ),
                style: TextStyle(
                  color: const Color(0xFF8390A3),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '${_pinLocation.latitude.toStringAsFixed(6)}, ${_pinLocation.longitude.toStringAsFixed(6)}',
                style: TextStyle(
                  color: const Color(0xFF101010),
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),
        _PrimaryActionButton(
          key: const ValueKey('send-next-summary-button'),
          label: _SendTextKeys.nextSummaryButton.tr(),
          enabled: true,
          onPressed: () {
            setState(() {
              _step = _SendStep.summaryPayment;
            });
          },
        ),
      ],
    );
  }

  Widget _buildPaymentStep(
    BuildContext context,
    AsyncValue<List<SendParcelItem>> parcelsAsync,
  ) {
    final selectedItem = _selectedParcel(parcelsAsync);
    if (selectedItem == null) {
      return _buildInvalidSelectionState();
    }
    final weightKg = selectedItem.weightKg ?? 1.0;
    final feeQuote = ForwardFeeQuote.fromWeight(weightKg);

    return _buildRefreshableListView(
      key: const ValueKey('send-summary-step'),
      padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 20.h),
      children: [
        _Header(
          title: _SendTextKeys.paymentTitle.tr(),
          onBack: () {
            setState(() {
              _step = _SendStep.pinAddress;
              // ข้อมูลผู้รับอาจถูกแก้ไข — order เดิมใช้ไม่ได้แล้ว
              _createdOrder = null;
            });
          },
          backTooltip: _SendTextKeys.backTooltip.tr(),
        ),
        SizedBox(height: 14.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5F8),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: const Color(0xFFE2E8F1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _SendTextKeys.paymentOrderLabel.tr(),
                style: TextStyle(
                  color: const Color(0xFF8B98AA),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                selectedItem.title,
                style: TextStyle(
                  color: const Color(0xFF101010),
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                _SendTextKeys.paymentDestination.tr(
                  args: [_recipientAddressController.text.trim()],
                ),
                style: TextStyle(
                  color: const Color(0xFF758397),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                _SendTextKeys.paymentWeightBilled.tr(
                  args: ['$weightKg', '${feeQuote.billableKg}'],
                ),
                style: TextStyle(
                  color: AppTheme.brandBlue,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 12.h),
              Divider(height: 1, color: const Color(0xFFD8DFE9)),
              SizedBox(height: 12.h),
              _PriceRow(
                label: _SendTextKeys.paymentFeeLabel.tr(),
                amount: formatLak(feeQuote.fee),
              ),
              SizedBox(height: 12.h),
              Divider(
                height: 1,
                color: const Color(0xFFD0D9E4),
                thickness: 1.1,
              ),
              SizedBox(height: 12.h),
              _PriceRow(
                label: _SendTextKeys.paymentTotalLabel.tr(),
                amount: formatLak(feeQuote.total),
                highlight: true,
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        _PrimaryActionButton(
          key: const ValueKey('send-confirm-forward-button'),
          label: _SendTextKeys.paymentConfirmButton.tr(
            args: [formatLak(feeQuote.total)],
          ),
          enabled: !_isSubmitting,
          onPressed: () => _handleForwardConfirm(selectedItem),
        ),
      ],
    );
  }

  Widget _buildInvalidSelectionState() {
    return _buildRefreshableListView(
      key: const ValueKey('send-invalid-selection-step'),
      padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 20.h),
      children: [
        _SimpleStateCard(
          icon: Icons.warning_amber_rounded,
          message: _SendTextKeys.reselectParcel,
          actionLabel: _SendTextKeys.back,
          onAction: () {
            setState(() {
              _step = _SendStep.selectParcel;
              _selectedParcelId = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildRefreshableListView({
    required Key key,
    required EdgeInsetsGeometry padding,
    required List<Widget> children,
  }) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(sendParcelsProvider.future),
      child: ListView(
        key: key,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: children,
      ),
    );
  }

  SendParcelItem? _selectedParcel(
    AsyncValue<List<SendParcelItem>> parcelsAsync,
  ) {
    final selectedId = _selectedParcelId;
    if (selectedId == null) {
      return null;
    }
    final items = parcelsAsync.valueOrNull;
    if (items == null) {
      return null;
    }
    for (final item in items) {
      if (item.id == selectedId) {
        return item;
      }
    }
    return null;
  }

  Future<void> _handleForwardConfirm(SendParcelItem selectedItem) async {
    setState(() {
      _isSubmitting = true;
    });

    // The customer pays only the shipping fee for forwarding, computed the same
    // way as the summary card — not the parcel's own price.
    final feeQuote = ForwardFeeQuote.fromWeight(selectedItem.weightKg ?? 1.0);

    try {
      final order =
          _createdOrder ??
          await ref
              .read(sendRepositoryProvider)
              .createForwardRequest(
                CreateForwardRequest(
                  parcelId: selectedItem.id,
                  recipientName: _recipientNameController.text.trim(),
                  recipientPhone: _recipientPhoneNumber,
                  recipientAddress: _recipientAddressController.text.trim(),
                  courierName: _courierController.text.trim(),
                  branchName: _selectedBranch ?? '',
                  latitude: _pinLocation.latitude,
                  longitude: _pinLocation.longitude,
                ),
              );
      _createdOrder = order;

      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });

      final result = await context.push(
        ParcelPaymentScreen.routePath,
        extra: ParcelPaymentArgs.forOrder(
          order: order,
          itemName: selectedItem.title,
          amountOverride: feeQuote.total,
        ),
      );

      if (!mounted || result != true) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_SendTextKeys.forwardSuccessMessage.tr())),
      );

      setState(() {
        _resetFlow();
      });
      ref.invalidate(sendParcelsProvider);
      ref.invalidate(homeParcelsProvider);
      ref.invalidate(parcelStatusProvider);
      ref.read(customerTabJumpTargetProvider.notifier).state = 0;
    } catch (error, stackTrace) {
      // Surface the real cause: a failed POST /orders/forward otherwise looks
      // like the screen "did nothing" after tapping confirm.
      if (kDebugMode) {
        debugPrint('[SendScreen] forward confirm failed: $error');
        debugPrint('$stackTrace');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_SendTextKeys.submitForwardError.tr())),
      );
    }
  }

  void _resetFlow() {
    _selectedParcelId = null;
    _step = _SendStep.selectParcel;
    _pinLocation = const LatLng(17.9757, 102.6331);
    _createdOrder = null;
    _recipientNameController.clear();
    _recipientPhoneController.clear();
    _recipientAddressController.clear();
    _courierController.clear();
    _selectedBranch = null;
  }

  void _showNotImplementedSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_SendTextKeys.actionNotImplemented.tr())),
    );
  }
}

class _SendParcelCard extends StatelessWidget {
  const _SendParcelCard({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SendParcelItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18.r),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: const Color(0xFFDDE4EE)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: const Color(0xFF101010),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    item.trackNo,
                    style: TextStyle(
                      color: const Color(0xFF8F9CB0),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? AppTheme.brandBlue : const Color(0xFFD4DCE8),
              size: 22.sp,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onBack,
    required this.backTooltip,
  });

  final String title;
  final VoidCallback onBack;
  final String backTooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: Color(0xFF222222)),
          tooltip: backTooltip,
        ),
        SizedBox(width: 4.w),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF111111),
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedParcelSummary extends StatelessWidget {
  const _SelectedParcelSummary({required this.item});

  final SendParcelItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppTheme.borderBlue),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.inventory_2_rounded,
            size: 20.sp,
            color: AppTheme.brandBlueDark,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _SendTextKeys.selectedParcelLabel.tr(),
                  style: TextStyle(
                    color: AppTheme.brandBlue,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  item.title,
                  style: TextStyle(
                    color: AppTheme.brandBlueDark,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
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

/// Picker styled to sit next to [_InputField] in the same row: same fill,
/// radius and padding, so a chosen branch reads like the typed courier beside
/// it rather than a different kind of control.
class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      iconEnabledColor: const Color(0xFF7A869A),
      borderRadius: BorderRadius.circular(14.r),
      style: TextStyle(
        color: const Color(0xFF111111),
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
      ),
      hint: Text(
        hint,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: const Color(0xFFA7AFBC),
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(
            key: ValueKey('send-branch-option-${itemLabel(item)}'),
            value: item,
            child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
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

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54.h,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled
              ? AppTheme.brandBlueDark
              : const Color(0xFF9FC9F7),
          disabledBackgroundColor: const Color(0xFF9FC9F7),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.r),
          ),
          textStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
        ),
        child: Text(label),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: const Color(0xFF6F7D8F),
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.amount,
    this.highlight = false,
  });

  final String label;
  final String amount;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: highlight
                  ? const Color(0xFF101010)
                  : const Color(0xFF6F7D8F),
              fontSize: highlight ? 18.sp : 15.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            color: highlight ? AppTheme.brandBlueDark : const Color(0xFF101010),
            fontSize: highlight ? 32.sp : 24.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SimpleStateCard extends StatelessWidget {
  const _SimpleStateCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF8E9CAF), size: 26.sp),
          SizedBox(height: 8.h),
          Text(
            message.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF6E7D92),
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: 8.h),
            TextButton(onPressed: onAction, child: Text(actionLabel!.tr())),
          ],
        ],
      ),
    );
  }
}

class _SendTextKeys {
  static const String title = 'send_select_title';
  static const String subtitle = 'send_select_subtitle';
  static const String nextButton = 'send_next_button';
  static const String recipientTitle = 'send_recipient_title';
  static const String selectedParcelLabel = 'send_selected_parcel_label';
  static const String recipientNameLabel = 'send_recipient_name_label';
  static const String recipientNameHint = 'send_recipient_name_hint';
  static const String recipientPhoneLabel = 'send_recipient_phone_label';
  static const String recipientPhoneHint = 'send_recipient_phone_hint';
  static const String recipientAddressLabel = 'send_recipient_address_label';
  static const String recipientAddressHint = 'send_recipient_address_hint';
  static const String courierLabel = 'send_courier_label';
  static const String courierHint = 'send_courier_hint';
  static const String branchLabel = 'send_branch_label';
  static const String branchHint = 'send_branch_hint';
  static const String pinAddressButton = 'send_pin_address_button';
  static const String pinTitle = 'send_pin_title';
  static const String pinInstruction = 'send_pin_instruction';
  static const String pinCoordinateLabel = 'send_pin_coordinate_label';
  static const String nextSummaryButton = 'send_next_summary_button';
  static const String paymentTitle = 'send_payment_title';
  static const String paymentOrderLabel = 'send_payment_order_label';
  static const String paymentDestination = 'send_payment_destination';
  static const String paymentWeightBilled = 'send_payment_weight_billed';
  static const String paymentFeeLabel = 'send_payment_fee_label';
  static const String paymentTotalLabel = 'send_payment_total_label';
  static const String paymentConfirmButton = 'send_payment_confirm_button';
  static const String forwardSuccessMessage = 'send_forward_success_message';
  static const String mapPlaceholder = 'send_map_placeholder';
  static const String mapDesktopNotSupported = 'send_map_desktop_not_supported';
  static const String backTooltip = 'send_back_tooltip';
  static const String actionNotImplemented = 'action_not_implemented';
  static const String emptySelectableParcels = 'send_empty_selectable_parcels';
  static const String loadParcelsError = 'send_load_parcels_error';
  static const String reselectParcel = 'send_reselect_parcel';
  static const String submitForwardError = 'send_submit_forward_error';
  static const String retry = 'common_retry';
  static const String back = 'common_back';
}

enum _SendStep { selectParcel, recipientDetails, pinAddress, summaryPayment }
