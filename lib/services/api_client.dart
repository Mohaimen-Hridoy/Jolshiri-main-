import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_config.dart';

/// Sniffs the first few bytes of an image to find its real MIME type.
///
/// `http.MultipartFile.fromBytes` defaults to `application/octet-stream`
/// when no [MediaType] is supplied — regardless of what the bytes actually
/// are. The backend's upload middleware
/// (jolshiri-backend/src/middleware/upload.js `ALLOWED_MIME`) only accepts
/// image/jpeg, image/png, image/webp and image/gif, so every upload was
/// being rejected with "Only JPEG, PNG, WEBP or GIF images are allowed"
/// even when the picked file genuinely was a jpeg/png. Detecting the type
/// from magic numbers and passing it explicitly fixes that.
MediaType _detectImageMediaType(Uint8List bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return MediaType('image', 'jpeg');
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return MediaType('image', 'png');
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return MediaType('image', 'webp');
  }
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38 &&
      (bytes[4] == 0x37 || bytes[4] == 0x39) &&
      bytes[5] == 0x61) {
    return MediaType('image', 'gif');
  }
  // Fall back to jpeg rather than octet-stream — the backend would reject
  // octet-stream outright, whereas most unrecognised-but-image-shaped
  // payloads from image pickers are jpeg.
  return MediaType('image', 'jpeg');
}

/// Thrown when the backend responded but rejected the request (4xx/5xx with
/// a JSON `{ message }` body — see jolshiri-backend/src/middleware/errorHandler.js).
/// Callers can show [message] to the user.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thrown when the backend couldn't be reached at all (server down, no
/// network, wrong host in [ApiConfig]). Callers should treat this as
/// "go offline / use local mock data", not as a validation error.
class ApiUnreachableException implements Exception {
  final String reason;
  ApiUnreachableException(this.reason);

  @override
  String toString() => 'ApiUnreachableException: $reason';
}

/// Thin wrapper around package:http that talks to the Jolshiri backend
/// (see ApiConfig.baseUrl) — adds the JSON headers, the Bearer token for
/// authenticated routes, a timeout, and turns error responses into
/// [ApiException] / [ApiUnreachableException] so callers can decide whether
/// to show a real error or silently fall back to mock data.
class ApiClient {
  ApiClient._();

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final full = '${ApiConfig.baseUrl}$path';
    final uri = Uri.parse(full);
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...query.map((k, v) => MapEntry(k, '$v')),
    });
  }

  static Map<String, String> _headers({bool auth = false}) {
    final headers = {'Content-Type': 'application/json'};
    if (auth && AuthSession.token != null) {
      headers['Authorization'] = 'Bearer ${AuthSession.token}';
    }
    return headers;
  }

  static Future<dynamic> _handle(Future<http.Response> Function() send) async {
    http.Response res;
    try {
      res = await send().timeout(ApiConfig.timeout);
    } catch (e) {
      // Covers SocketException, TimeoutException, HandshakeException, etc.
      // — anything that means "couldn't talk to the server at all".
      throw ApiUnreachableException(e.toString());
    }

    final bodyText = res.body.isEmpty ? '{}' : res.body;
    dynamic decoded;
    try {
      decoded = jsonDecode(bodyText);
    } catch (_) {
      decoded = {'message': bodyText};
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }
    final message = (decoded is Map && (decoded['message'] ?? decoded['error']) != null)
        ? (decoded['message'] ?? decoded['error']).toString()
        : 'Request failed (${res.statusCode})';
    throw ApiException(res.statusCode, message);
  }

  static Future<dynamic> get(String path, {Map<String, dynamic>? query, bool auth = false}) {
    return _handle(() => http.get(_uri(path, query), headers: _headers(auth: auth)));
  }

  static Future<dynamic> post(String path, {Map<String, dynamic>? body, bool auth = false}) {
    return _handle(() => http.post(_uri(path), headers: _headers(auth: auth), body: jsonEncode(body ?? {})));
  }

  static Future<dynamic> patch(String path, {Map<String, dynamic>? body, bool auth = false}) {
    return _handle(() => http.patch(_uri(path), headers: _headers(auth: auth), body: jsonEncode(body ?? {})));
  }

  static Future<dynamic> delete(String path, {bool auth = false}) {
    return _handle(() => http.delete(_uri(path), headers: _headers(auth: auth)));
  }

  /// multipart/form-data POST — used wherever a text form also carries an
  /// optional image (e.g. filing a complaint with a photo). [fields] are
  /// sent as plain form fields; [fileBytes]/[fileField]/[fileName] add a
  /// single file part when [fileBytes] is non-null.
  static Future<dynamic> postMultipart(
    String path, {
    Map<String, String>? fields,
    Uint8List? fileBytes,
    String fileField = 'image',
    String fileName = 'upload.jpg',
    bool auth = false,
  }) {
    return _handle(() async {
      final request = http.MultipartRequest('POST', _uri(path));
      if (auth && AuthSession.token != null) {
        request.headers['Authorization'] = 'Bearer ${AuthSession.token}';
      }
      request.fields.addAll(fields ?? {});
      if (fileBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: fileName,
          contentType: _detectImageMediaType(fileBytes),
        ));
      }
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    });
  }

  /// multipart/form-data PATCH — same shape as [postMultipart], used for
  /// edits where a new photo may (or may not) replace the existing one.
  /// If [fileBytes] is null, no file part is sent and the backend keeps
  /// whatever image URL was already stored.
  static Future<dynamic> patchMultipart(
    String path, {
    Map<String, String>? fields,
    Uint8List? fileBytes,
    String fileField = 'image',
    String fileName = 'upload.jpg',
    bool auth = false,
  }) {
    return _handle(() async {
      final request = http.MultipartRequest('PATCH', _uri(path));
      if (auth && AuthSession.token != null) {
        request.headers['Authorization'] = 'Bearer ${AuthSession.token}';
      }
      request.fields.addAll(fields ?? {});
      if (fileBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: fileName,
          contentType: _detectImageMediaType(fileBytes),
        ));
      }
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    });
  }
}
