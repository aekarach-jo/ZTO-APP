import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';

class UnownedParcelsQuery {
  const UnownedParcelsQuery({
    this.page = 1,
    this.perPage = 20,
    this.searchText = '',
  });

  final int page;
  final int perPage;
  final String searchText;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UnownedParcelsQuery &&
            runtimeType == other.runtimeType &&
            page == other.page &&
            perPage == other.perPage &&
            searchText == other.searchText;
  }

  @override
  int get hashCode => Object.hash(page, perPage, searchText);
}

class UnownedParcel {
  const UnownedParcel({
    required this.selectionKey,
    required this.claimId,
    required this.trackNo,
    required this.status,
    required this.weightLabel,
    this.name,
  });

  final String selectionKey;
  final Object claimId;
  final String trackNo;
  final String status;
  final String weightLabel;
  final String? name;

  factory UnownedParcel.fromJson(Map<String, dynamic> json) {
    final rawTrackNo =
        _readString(json, const [
          'track_no',
          'trackingNo',
          'tracking_no',
          'trackingNumber',
        ]) ??
        '-';
    final claimId = _readId(json, const [
      'id',
      '_id',
      'parcelId',
    ], fallback: rawTrackNo);
    final weightRaw =
        _readString(json, const ['weightLabel']) ??
        _readNumberAsString(json, const ['weight']);
    final name = _readString(json, const [
      'name',
      'title',
      'itemName',
      'productName',
      'description',
    ]);

    return UnownedParcel(
      selectionKey: _selectionKey(claimId),
      claimId: claimId,
      trackNo: rawTrackNo.startsWith('#') ? rawTrackNo : '#$rawTrackNo',
      status: (_readString(json, const ['status', 'parcelStatus']) ?? 'pending')
          .toLowerCase(),
      weightLabel: weightRaw == null || weightRaw.isEmpty
          ? '-'
          : '$weightRaw kg',
      name: name,
    );
  }

  static Object _readId(
    Map<String, dynamic> json,
    List<String> keys, {
    required String fallback,
  }) {
    for (final key in keys) {
      if (!json.containsKey(key)) {
        continue;
      }
      final value = json[key];
      if (value is num) {
        return value;
      }
      if (value is String) {
        final normalized = value.trim();
        if (normalized.isNotEmpty) {
          return normalized;
        }
      }
    }
    return fallback;
  }

  static String _selectionKey(Object id) {
    if (id is num) {
      return 'num:$id';
    }
    return 'str:$id';
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) {
        continue;
      }
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  static String? _readNumberAsString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) {
        return value.toString();
      }
      if (value is String) {
        final normalized = value.trim();
        if (normalized.isNotEmpty) {
          return normalized;
        }
      }
    }
    return null;
  }
}

class UnownedParcelPage {
  const UnownedParcelPage({
    required this.items,
    required this.currentPage,
    required this.perPage,
    required this.total,
  });

  final List<UnownedParcel> items;
  final int currentPage;
  final int perPage;
  final int total;

  bool get hasPreviousPage => currentPage > 1;
  bool get hasNextPage => currentPage * perPage < total;
  int get totalPages => total <= 0 ? 1 : ((total - 1) ~/ perPage) + 1;
}

abstract class ParcelClaimRepository {
  Future<UnownedParcelPage> fetchUnownedParcels(UnownedParcelsQuery query);

  Future<void> submitClaim({required List<Object> parcelIds});
}

class ApiParcelClaimRepository implements ParcelClaimRepository {
  ApiParcelClaimRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<UnownedParcelPage> fetchUnownedParcels(
    UnownedParcelsQuery query,
  ) async {
    final response = await _dio.get<dynamic>(
      '/parcels/unowned',
      queryParameters: {
        'page': query.page,
        'perPage': query.perPage,
        if (query.searchText.trim().isNotEmpty) ...{
          'trackNo': query.searchText.trim(),
          'searchText': query.searchText.trim(),
        },
      },
    );

    final payload = _extractPayload(response.data);
    final data = payload['data'];
    final meta = payload['meta'];
    final items = data is List<dynamic>
        ? data
              .whereType<Map<String, dynamic>>()
              .map(UnownedParcel.fromJson)
              .toList()
        : const <UnownedParcel>[];

    return UnownedParcelPage(
      items: items,
      currentPage: _readInt(meta, 'current_page') ?? query.page,
      perPage: _readInt(meta, 'per_page') ?? query.perPage,
      total: _readInt(meta, 'total') ?? items.length,
    );
  }

  @override
  Future<void> submitClaim({required List<Object> parcelIds}) async {
    await _dio.post<dynamic>(
      '/parcels/claim-owner',
      data: {
        'parcelIds': parcelIds
            .map<Object>((id) => id is num || id is String ? id : id.toString())
            .toList(growable: false),
      },
    );
  }

  Map<String, dynamic> _extractPayload(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return const {'data': <dynamic>[], 'meta': <String, dynamic>{}};
    }

    final rootData = data['data'];
    if (rootData is Map<String, dynamic>) {
      return {
        'data': rootData['data'],
        'meta': rootData['meta'] is Map<String, dynamic>
            ? rootData['meta'] as Map<String, dynamic>
            : const <String, dynamic>{},
      };
    }

    return const {'data': <dynamic>[], 'meta': <String, dynamic>{}};
  }

  int? _readInt(Map<String, dynamic>? json, String key) {
    final value = json?[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}

final parcelClaimRepositoryProvider = Provider<ParcelClaimRepository>((ref) {
  final dio = ref.watch(apiClientProvider).dio;
  return ApiParcelClaimRepository(dio: dio);
});

final unownedParcelsProvider =
    FutureProvider.family<UnownedParcelPage, UnownedParcelsQuery>((ref, query) {
      return ref
          .watch(parcelClaimRepositoryProvider)
          .fetchUnownedParcels(query);
    });
