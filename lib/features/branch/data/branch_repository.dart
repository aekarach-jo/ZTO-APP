import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';

/// A selectable branch/brand returned by `GET /branches`.
class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.code,
    this.domain,
  });

  final String id;
  final String name;
  final String code;
  final String? domain;

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: (json['id'] ?? json['_id'] ?? json['branchId'] ?? '').toString(),
      name: (json['name'] ?? json['branchName'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      domain: json['domain']?.toString(),
    );
  }

  /// Short label shown on the toggle (falls back to name when code is empty).
  ///
  /// `KD` is shown as `TT` — display only; the stored/sent code stays `KD`.
  String get label {
    if (code.trim().toUpperCase() == 'KD') {
      return 'TT';
    }
    return code.isNotEmpty ? code : name;
  }
}

class BranchRepository {
  BranchRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<Branch>> fetchBranches() async {
    final response = await _dio.get<dynamic>('/branches');
    final list = _extractList(response.data);
    final branches = list
        .whereType<Map<String, dynamic>>()
        .map(Branch.fromJson)
        .where((branch) => branch.id.isNotEmpty)
        .toList(growable: false);
    if (kDebugMode) {
      debugPrint(
        '[BranchRepository] branches=${branches.map((b) => '${b.code}:${b.id}').join(', ')}',
      );
    }
    return branches;
  }

  Future<String?> fetchCurrentBranchId() async {
    final response = await _dio.get<dynamic>('/users/me');
    final data = _unwrapMap(response.data);
    if (data == null) {
      return null;
    }
    final direct = data['branchId'] ?? data['branch_id'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }
    final branch = data['branch'];
    if (branch is Map<String, dynamic>) {
      final nested = branch['id'] ?? branch['branchId'] ?? branch['_id'];
      if (nested != null && nested.toString().trim().isNotEmpty) {
        return nested.toString().trim();
      }
    }
    return null;
  }

  Future<void> selectBranch(String branchId) async {
    try {
      final response = await _dio.patch<dynamic>(
        '/users/me/branch',
        data: {'branchId': branchId},
      );
      if (kDebugMode) {
        debugPrint(
          '[BranchRepository] PATCH /users/me/branch ok: '
          'branchId=$branchId status=${response.statusCode} '
          'body=${response.data}',
        );
      }
    } on DioException catch (error) {
      // The branch switch failing silently is what makes the parcel list look
      // "stuck" on the previous branch, so surface the real status/body here.
      if (kDebugMode) {
        debugPrint(
          '[BranchRepository] PATCH /users/me/branch failed: '
          'branchId=$branchId status=${error.response?.statusCode} '
          'type=${error.type} message=${error.message} '
          'body=${error.response?.data}',
        );
      }
      rethrow;
    }
  }

  static Map<String, dynamic>? _unwrapMap(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }
    final inner = data['data'];
    if (inner is Map<String, dynamic>) {
      return inner;
    }
    return data;
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List<dynamic>) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final direct = data['data'];
      if (direct is List<dynamic>) {
        return direct;
      }
      final root = data['items'] ?? data['branches'] ?? data['results'];
      if (root is List<dynamic>) {
        return root;
      }
    }
    return const <dynamic>[];
  }
}

final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  final dio = ref.watch(apiClientProvider).dio;
  return BranchRepository(dio: dio);
});

final branchesProvider = FutureProvider<List<Branch>>((ref) {
  return ref.watch(branchRepositoryProvider).fetchBranches();
});

final currentBranchIdProvider = FutureProvider<String?>((ref) {
  return ref.watch(branchRepositoryProvider).fetchCurrentBranchId();
});
