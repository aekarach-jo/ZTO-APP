List<dynamic> extractParcelPayloadList(dynamic data) {
  return _findParcelPayloadList(data) ?? const <dynamic>[];
}

List<dynamic>? _findParcelPayloadList(dynamic data) {
  if (data is List<dynamic>) {
    return data;
  }

  if (data is Map<String, dynamic>) {
    for (final key in const ['data', 'items', 'parcels', 'results']) {
      final found = _findParcelPayloadList(data[key]);
      if (found != null) {
        return found;
      }
    }
  }

  return null;
}
