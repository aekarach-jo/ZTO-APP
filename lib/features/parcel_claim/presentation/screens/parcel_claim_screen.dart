import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/network/network_providers.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../data/parcel_claim_repository.dart';

class ParcelClaimScreen extends ConsumerStatefulWidget {
  const ParcelClaimScreen({super.key});

  static const String routePath = '/parcels/claim';

  @override
  ConsumerState<ParcelClaimScreen> createState() => _ParcelClaimScreenState();
}

class _ParcelClaimScreenState extends ConsumerState<ParcelClaimScreen> {
  static const int _perPage = 20;
  static const double _loadMoreExtentThreshold = 240;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, _SelectedParcel> _selectedParcels =
      <String, _SelectedParcel>{};

  Timer? _searchDebounce;
  String _searchText = '';
  bool _isSubmitting = false;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  int _requestVersion = 0;
  int _currentPage = 0;
  int _total = 0;
  Object? _loadError;
  List<UnownedParcel> _items = const <UnownedParcel>[];

  bool get _hasNextPage =>
      _items.isEmpty || (_currentPage > 0 && _items.length < _total);

  UnownedParcelsQuery _buildQuery(int page) => UnownedParcelsQuery(
    page: page,
    perPage: _perPage,
    searchText: _searchText,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    Future.microtask(_reloadParcels);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phoneAsync = ref.watch(currentUserPhoneProvider);
    final selectedCount = _selectedParcels.length;

    return Scaffold(
      appBar: AppBar(title: Text('parcel_claim_title'.tr())),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reloadParcels,
                child: ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
                  children: [
                    _IntroCard(
                      title: 'parcel_claim_entry_title'.tr(),
                      subtitle: 'parcel_claim_intro'.tr(),
                    ),
                    SizedBox(height: 14.h),
                    _SearchField(
                      controller: _searchController,
                      onChanged: _handleSearchChanged,
                    ),
                    SizedBox(height: 12.h),
                    phoneAsync.when(
                      data: (phone) => _InlineInfoText(
                        phone == null || phone.isEmpty
                            ? 'parcel_claim_phone_missing'.tr()
                            : 'parcel_claim_phone_label'.tr(args: [phone]),
                        color: phone == null || phone.isEmpty
                            ? const Color(0xFFB14A39)
                            : const Color(0xFF667587),
                      ),
                      loading: () => _InlineInfoText(
                        'common_loading'.tr(),
                        color: const Color(0xFF667587),
                      ),
                      error: (error, stackTrace) => _InlineInfoText(
                        'parcel_claim_phone_missing'.tr(),
                        color: const Color(0xFFB14A39),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _buildParcelResults(),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE3E8EF))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'parcel_claim_selected_count'.tr(args: ['$selectedCount']),
                    style: TextStyle(
                      color: const Color(0xFF4D5C6B),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (selectedCount > 0) ...[
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'parcel_claim_selected_title'.tr(),
                            style: TextStyle(
                              color: const Color(0xFF677689),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          key: const ValueKey('parcel-claim-clear-selection'),
                          onPressed: _clearSelections,
                          child: Text('parcel_claim_clear_selection'.tr()),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: _selectedParcels.values
                          .map(
                            (parcel) => InputChip(
                              label: Text(parcel.trackNo),
                              onDeleted: () =>
                                  _removeSelection(parcel.selectionKey),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  SizedBox(height: 10.h),
                  PrimaryButton(
                    key: const ValueKey('parcel-claim-submit-button'),
                    label: 'parcel_claim_submit_button'.tr(),
                    isLoading: _isSubmitting,
                    onPressed: selectedCount == 0 ? null : _submitClaim,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParcelResults() {
    if (_isInitialLoading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null && _items.isEmpty) {
      return _LoadErrorState(
        message: _mapLoadError(_loadError!),
        onRetry: _reloadParcels,
      );
    }

    if (_items.isEmpty) {
      return _EmptyState(message: 'parcel_claim_empty'.tr());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'parcel_claim_total_label'.tr(args: ['$_total']),
          style: TextStyle(
            color: const Color(0xFF677689),
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 12.h),
        for (var i = 0; i < _items.length; i++) ...[
          _ParcelSelectionCard(
            parcel: _items[i],
            selected: _selectedParcels.containsKey(_items[i].selectionKey),
            onChanged: (selected) => _toggleSelection(_items[i], selected),
          ),
          if (i != _items.length - 1) SizedBox(height: 12.h),
        ],
        _LoadMoreFooter(
          isLoading: _isLoadingMore,
          onRetry: _loadError != null && _items.isNotEmpty && !_isLoadingMore
              ? _loadNextPage
              : null,
        ),
      ],
    );
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchText = value.trim();
      });
      _reloadParcels();
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _isInitialLoading ||
        _isLoadingMore ||
        !_hasNextPage) {
      return;
    }
    if (_scrollController.position.extentAfter > _loadMoreExtentThreshold) {
      return;
    }
    _loadNextPage();
  }

  void _toggleSelection(UnownedParcel parcel, bool selected) {
    setState(() {
      if (selected) {
        _selectedParcels[parcel.selectionKey] = _SelectedParcel(
          selectionKey: parcel.selectionKey,
          claimId: parcel.claimId,
          trackNo: parcel.trackNo,
        );
      } else {
        _selectedParcels.remove(parcel.selectionKey);
      }
    });
  }

  void _removeSelection(String selectionKey) {
    setState(() {
      _selectedParcels.remove(selectionKey);
    });
  }

  void _clearSelections() {
    setState(() {
      _selectedParcels.clear();
    });
  }

  Future<void> _reloadParcels() async {
    _requestVersion += 1;
    await _loadPage(page: 1, reset: true, requestVersion: _requestVersion);
  }

  Future<void> _loadNextPage() async {
    if (_isInitialLoading || _isLoadingMore || !_hasNextPage) {
      return;
    }
    await _loadPage(
      page: _currentPage + 1,
      reset: false,
      requestVersion: _requestVersion,
    );
  }

  Future<void> _loadPage({
    required int page,
    required bool reset,
    required int requestVersion,
  }) async {
    setState(() {
      if (reset) {
        _isInitialLoading = true;
        _isLoadingMore = false;
        _loadError = null;
        _currentPage = 0;
        _total = 0;
        _items = const <UnownedParcel>[];
      } else {
        _isLoadingMore = true;
        _loadError = null;
      }
    });

    try {
      final pageData = await ref
          .read(parcelClaimRepositoryProvider)
          .fetchUnownedParcels(_buildQuery(page));
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _items = reset
            ? pageData.items
            : <UnownedParcel>[..._items, ...pageData.items];
        _currentPage = pageData.currentPage;
        _total = pageData.total;
        _loadError = null;
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }
      setState(() {
        _loadError = error;
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _submitClaim() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(parcelClaimRepositoryProvider)
          .submitClaim(
            parcelIds: _selectedParcels.values
                .map((parcel) => parcel.claimId)
                .toList(growable: false),
          );

      if (!mounted) {
        return;
      }
      setState(() {
        _selectedParcels.clear();
      });
      await _reloadParcels();
      if (!mounted) {
        return;
      }
      _showMessage('parcel_claim_submit_success'.tr());
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_mapSubmitError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _mapLoadError(Object error) {
    return 'parcel_claim_load_error'.tr();
  }

  String _mapSubmitError(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 422) {
        return 'parcel_claim_validation_error'.tr();
      }
    }
    return 'parcel_claim_submit_error'.tr();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF1E6), Color(0xFFFFFBF3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFFFD8B3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: const Color(0xFF23160D),
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            subtitle,
            style: TextStyle(
              color: const Color(0xFF7B5A3D),
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'parcel_claim_search_hint'.tr(),
        hintStyle: const TextStyle(
          color: Color(0xFFA2AFBF),
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: const Icon(Icons.search, color: Color(0xFFA2AFBF)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Color(0xFFE0E6EF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Color(0xFFE0E6EF)),
        ),
      ),
    );
  }
}

class _InlineInfoText extends StatelessWidget {
  const _InlineInfoText(this.message, {required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(
        color: color,
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ParcelSelectionCard extends StatelessWidget {
  const _ParcelSelectionCard({
    required this.parcel,
    required this.selected,
    required this.onChanged,
  });

  final UnownedParcel parcel;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(parcel.status);

    return InkWell(
      borderRadius: BorderRadius.circular(20.r),
      onTap: () => onChanged(!selected),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF5EC) : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: selected ? const Color(0xFFE67E22) : const Color(0xFFE2E7EF),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: selected,
              onChanged: (value) => onChanged(value ?? false),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          parcel.trackNo,
                          style: TextStyle(
                            color: const Color(0xFF171717),
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _StatusChip(
                        label: statusStyle.labelKey.tr(),
                        backgroundColor: statusStyle.backgroundColor,
                        foregroundColor: statusStyle.foregroundColor,
                      ),
                    ],
                  ),
                  if (parcel.name != null && parcel.name!.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      parcel.name!,
                      style: TextStyle(
                        color: const Color(0xFF667587),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      const Icon(
                        Icons.scale_outlined,
                        size: 16,
                        color: Color(0xFF96A3B5),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        parcel.weightLabel,
                        style: TextStyle(
                          color: const Color(0xFF95A2B3),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: 12.sp,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE2E7EF)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: const Color(0xFFA2AFBF),
            size: 24.sp,
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF768499),
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE2E7EF)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: const Color(0xFFB14A39),
            size: 24.sp,
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF768499),
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10.h),
          TextButton(onPressed: onRetry, child: Text('common_retry'.tr())),
        ],
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.isLoading, this.onRetry});

  final bool isLoading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (onRetry == null) {
      return SizedBox(height: 4.h);
    }
    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: Center(
        child: TextButton(onPressed: onRetry, child: Text('common_retry'.tr())),
      ),
    );
  }
}

_ParcelStatusStyle _statusStyle(String status) {
  switch (status) {
    case 'ready':
      return const _ParcelStatusStyle(
        labelKey: 'status_ready',
        backgroundColor: Color(0xFFDDF6E7),
        foregroundColor: Color(0xFF198754),
      );
    case 'wait_import':
      return const _ParcelStatusStyle(
        labelKey: 'status_wait_import',
        backgroundColor: Color(0xFFEDF1F5),
        foregroundColor: Color(0xFF6F8196),
      );
    case 'pending':
    default:
      return const _ParcelStatusStyle(
        labelKey: 'status_pending',
        backgroundColor: Color(0xFFFDF0A6),
        foregroundColor: Color(0xFF8D7000),
      );
  }
}

class _ParcelStatusStyle {
  const _ParcelStatusStyle({
    required this.labelKey,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String labelKey;
  final Color backgroundColor;
  final Color foregroundColor;
}

class _SelectedParcel {
  const _SelectedParcel({
    required this.selectionKey,
    required this.claimId,
    required this.trackNo,
  });

  final String selectionKey;
  final Object claimId;
  final String trackNo;
}
