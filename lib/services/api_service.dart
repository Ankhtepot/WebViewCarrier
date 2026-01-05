import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/page_item.dart';

enum FetchStatus { idle, success, empty, failed }

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final ValueNotifier<bool> isWorking = ValueNotifier<bool>(false);
  final ValueNotifier<List<PageItem>> pages = ValueNotifier<List<PageItem>>([]);
  final ValueNotifier<FetchStatus> fetchStatus = ValueNotifier<FetchStatus>(FetchStatus.idle);

  /// Returns true if pages were updated successfully with a non-empty list.
  /// If the request fails or returns an empty list, the previous pages are preserved
  /// (unless `forceClear` is true). `fetchStatus` is updated to reflect the
  /// observable outcome when there are no pages to show.
  Future<bool> fetchPages({
    required String baseUrl,
    required String totpCode,
    bool forceClear = false,
  }) async {
    final uri = Uri.parse('$baseUrl/api/pages');
    final _previous = List<PageItem>.from(pages.value);
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
            fetchStatus.value = FetchStatus.success;
            if (kDebugMode) debugPrint('ApiService: pages updated (${newPages.length})');
            return true;
          } else {
            // Empty list returned: keep previous pages (offline-first)
            if (_previous.isEmpty) {
              // there are no previous pages either -> show empty state
              fetchStatus.value = FetchStatus.empty;
            } else {
              // keep previous pages and retain success state
              fetchStatus.value = FetchStatus.success;
            }
            if (kDebugMode) debugPrint('ApiService: fetched empty list — preserving previous pages');
            return false;
          }
        } else {
          if (kDebugMode) debugPrint('ApiService: unexpected response format — preserving previous pages');
          if (pages.value.isEmpty) fetchStatus.value = FetchStatus.empty;
          return false;
        }
      } else {
        if (kDebugMode) debugPrint('ApiService: http ${resp.statusCode} — preserving previous pages');
        if (pages.value.isEmpty) fetchStatus.value = FetchStatus.failed;
        return false;
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ApiService: fetch error — preserving previous pages');
        debugPrint('$e\n$st');
      }
      if (pages.value.isEmpty) fetchStatus.value = FetchStatus.failed;
      return false;
    } finally {
      isWorking.value = false;
    }
  }
}
