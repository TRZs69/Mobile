import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiCacheService {
  static final StreamController<String> errorController =
      StreamController<String>.broadcast();
  static const Duration _timeout = Duration(seconds: 15);

  static String cacheKeyFor(Uri url) => 'api_cache_${url.toString()}';

  static Future<void> clearCacheForUrl(Uri url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cacheKeyFor(url));
  }

  static Future<void> clearCacheContaining(String needle) async {
    final prefs = await SharedPreferences.getInstance();
    final keysToDelete = prefs
        .getKeys()
        .where((key) => key.startsWith('api_cache_') && key.contains(needle))
        .toList();

    for (final key in keysToDelete) {
      await prefs.remove(key);
    }
  }

  static Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<void> _handleCriticalError(String message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('name');
    await prefs.remove('role');
    await prefs.remove('sessionId');

    errorController.add(message);
  }

  static Future<http.Response> forceRefresh(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = cacheKeyFor(url);
    return _fetchAndCache(url,
        headers: headers, prefs: prefs, cacheKey: cacheKey);
  }

  static Future<http.Response> get(Uri url,
      {Map<String, String>? headers}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = cacheKeyFor(url);

    final cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      _fetchAndCache(url, headers: headers, prefs: prefs, cacheKey: cacheKey)
          .catchError((_) => http.Response('error', 500));

      return http.Response(cachedData, 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }

    return await _fetchAndCache(url,
        headers: headers, prefs: prefs, cacheKey: cacheKey);
  }

  static Future<http.Response> _fetchAndCache(Uri url,
      {Map<String, String>? headers,
      required SharedPreferences prefs,
      required String cacheKey}) async {
    try {
      final authHeaders = await _getAuthHeaders();
      final allHeaders = {...authHeaders, ...?headers};
      final response =
          await http.get(url, headers: allHeaders).timeout(_timeout);

      if (response.statusCode == 401) {
        await _handleCriticalError(
            "Sesi Anda telah berakhir. Silakan login kembali.");
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await prefs.setString(cacheKey, response.body);
      }
      return response;
    } on TimeoutException catch (_) {
      rethrow;
    } on SocketException catch (_) {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  static Future<http.Response> getSWR(
    Uri url, {
    Map<String, String>? headers,
    required void Function(http.Response freshResponse) onRevalidated,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = cacheKeyFor(url);
    final cachedData = prefs.getString(cacheKey);

    if (cachedData != null) {
      unawaited(
        _fetchAndCache(url, headers: headers, prefs: prefs, cacheKey: cacheKey)
            .then((freshResponse) {
          if (freshResponse.statusCode >= 200 &&
              freshResponse.statusCode < 300) {
            onRevalidated(freshResponse);
          }
        }).catchError((_) {}),
      );

      return http.Response(
        cachedData,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }

    return _fetchAndCache(url,
        headers: headers, prefs: prefs, cacheKey: cacheKey);
  }

  static Future<http.Response> post(Uri url,
      {Map<String, String>? headers, Object? body}) async {
    try {
      final authHeaders = await _getAuthHeaders();
      final allHeaders = {...authHeaders, ...?headers};
      final response = await http
          .post(url,
              headers: allHeaders, body: body != null ? jsonEncode(body) : null)
          .timeout(_timeout);

      if (response.statusCode == 401) {
        await _handleCriticalError(
            "Sesi Anda telah berakhir. Silakan login kembali.");
      }

      return response;
    } on TimeoutException catch (_) {
      rethrow;
    } on SocketException catch (_) {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  static Future<http.Response> put(Uri url,
      {Map<String, String>? headers, Object? body}) async {
    try {
      final authHeaders = await _getAuthHeaders();
      final allHeaders = {...authHeaders, ...?headers};
      final response = await http
          .put(url,
              headers: allHeaders, body: body != null ? jsonEncode(body) : null)
          .timeout(_timeout);

      if (response.statusCode == 401) {
        await _handleCriticalError(
            "Sesi Anda telah berakhir. Silakan login kembali.");
      }

      return response;
    } on TimeoutException catch (_) {
      rethrow;
    } on SocketException catch (_) {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  static Future<http.Response> patch(Uri url,
      {Map<String, String>? headers, Object? body}) async {
    try {
      final authHeaders = await _getAuthHeaders();
      final allHeaders = {...authHeaders, ...?headers};
      final response = await http
          .patch(url,
              headers: allHeaders, body: body != null ? jsonEncode(body) : null)
          .timeout(_timeout);

      if (response.statusCode == 401) {
        await _handleCriticalError(
            "Sesi Anda telah berakhir. Silakan login kembali.");
      }

      return response;
    } on TimeoutException catch (_) {
      rethrow;
    } on SocketException catch (_) {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  static Future<http.Response> delete(Uri url,
      {Map<String, String>? headers}) async {
    try {
      final authHeaders = await _getAuthHeaders();
      final allHeaders = {...authHeaders, ...?headers};
      final response =
          await http.delete(url, headers: allHeaders).timeout(_timeout);

      if (response.statusCode == 401) {
        await _handleCriticalError(
            "Sesi Anda telah berakhir. Silakan login kembali.");
      }

      return response;
    } on TimeoutException catch (_) {
      rethrow;
    } on SocketException catch (_) {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }
}
