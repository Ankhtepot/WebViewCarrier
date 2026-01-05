import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/page_item.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final ValueNotifier<bool> isWorking = ValueNotifier<bool>(false);
  final ValueNotifier<List<PageItem>> pages = ValueNotifier<List<PageItem>>([]);

  /// Returns true if pages were updated successfully with a non-empty list.
  /// If the request fails or returns an empty list, the previous pages are preserved
  /// (unless `forceClear` is true).
  Future<bool> fetchPages({
    required String baseUrl,
    required String totpCode,
    bool forceClear = false,
  }) async {
    final uri = Uri.parse('$baseUrl/api/pages');
    final previous = List<PageItem>.from(pages.value);
    if (forceClear) pages.value = [];
    isWorking.value = true;
    try {
      final resp = await http.get(
        uri,
        headers: {'X-App-Auth': totpCode},
      );

      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        if (decoded is List) {
          final List<PageItem> newPages = decoded.map<PageItem>((e) {
            if (e is Map<String, dynamic>) return PageItem.fromJson(e);
            return PageItem.fromJson(Map<String, dynamic>.from(e));
          }).toList();

          if (newPages.isNotEmpty) {
            pages.value = newPages;
            if (kDebugMode) debugPrint('ApiService: pages updated (${newPages.length})');
            return true;
          } else {
            // Empty list returned: keep previous pages (offline-first)
            if (kDebugMode) debugPrint('ApiService: fetched empty list — preserving previous pages');
            return false;
          }
        } else {
          if (kDebugMode) debugPrint('ApiService: unexpected response format — preserving previous pages');
          return false;
        }
      } else {
        if (kDebugMode) debugPrint('ApiService: http ${resp.statusCode} — preserving previous pages');
        return false;
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ApiService: fetch error — preserving previous pages');
        debugPrint('$e\n$st');
      }
      return false;
    } finally {
      isWorking.value = false;
    }
  }
}
