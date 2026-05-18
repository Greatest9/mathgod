// lib/services/license_manager.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'secret_parts.dart';

class LicenseManager {
  static final LicenseManager instance = LicenseManager._();
  LicenseManager._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _deviceInfo = DeviceInfoPlugin();

  // Replace with your deployed Apps Script web app URL (must end with /exec)
  static const String _verifyEndpoint =
      "https://script.google.com/macros/s/AKfycbxuP-P6uQmjFuub5awiDqQwmv-ioZw4Q8IH52XQEopt99OIqk3jsg9zoOUpAhEd5WKl/exec";

  static const _kValid = 'mg_lv';
  static const _kHash = 'mg_lh';
  static const _kDevice = 'mg_ld';
  static const _kSlot = 'mg_ls';
  static const _kFallback = 'mg_fb';
  static const _kRawKey = 'mg_rk';

  String get _secretKey => SecretParts.assembled;

  // ────────────────────────────────────────────────────────────
  // PUBLIC API
  // ────────────────────────────────────────────────────────────
  Future<bool> isActivated() async {
    try {
      final valid = await _storage.read(key: _kValid);
      if (valid != '1') return false;
      if (!await _verifyHash()) return false;
      final storedDevice = await _storage.read(key: _kDevice);
      final currentDevice = await _deviceFingerprint();
      return storedDevice == currentDevice;
    } catch (_) {
      return false;
    }
  }

  Future<LicenseResult> activate(String rawKey) async {
    final key = rawKey.trim().toUpperCase();
    if (key.isEmpty) {
      return LicenseResult.fail("Please enter your license key.");
    }
    if (!_looksValid(key)) {
      return LicenseResult.fail(
        "Invalid key format. Expected: MATH-XXXX-XXXX-XXXX",
      );
    }

    try {
      final deviceId = await _deviceFingerprint();

      // GET request with query parameters
      final uri = Uri.parse(
        _verifyEndpoint,
      ).replace(queryParameters: {'license': key, 'device_id': deviceId});

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        debugPrint('[License] GET ${uri.toString()}');
        debugPrint('[License] Status: ${response.statusCode}');
        debugPrint('[License] Body: ${response.body}');
      }

      if (response.statusCode != 200) {
        return LicenseResult.networkError();
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['valid'] == true) {
        await _persist(key, deviceId, data['slot'] ?? 1);
        return LicenseResult.ok(data['message'] ?? 'License activated!');
      } else {
        return LicenseResult.fail(data['message'] ?? 'Invalid license key.');
      }
    } on FormatException {
      return LicenseResult.fail("Server returned unexpected data.");
    } catch (e) {
      if (kDebugMode) debugPrint('[License] error: $e');
      return LicenseResult.networkError();
    }
  }

  Future<void> revoke() async {
    await _storage.deleteAll();
  }

  // ────────────────────────────────────────────────────────────
  // PRIVATE
  // ────────────────────────────────────────────────────────────
  bool _looksValid(String key) {
    // Expects: MATH-XXXX-XXXX-XXXX (3 groups after MATH-)
    return RegExp(
      r'^MATH-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$',
      caseSensitive: false,
    ).hasMatch(key);
  }

  Future<String> _deviceFingerprint() async {
    try {
      final info = await _deviceInfo.androidInfo;
      final raw = '${info.id}|${info.model}|${info.product}|$_secretKey';
      final bytes = utf8.encode(raw);
      return sha256.convert(bytes).toString();
    } catch (_) {
      var fb = await _storage.read(key: _kFallback);
      if (fb == null) {
        fb = sha256
            .convert(
              utf8.encode(DateTime.now().microsecondsSinceEpoch.toString()),
            )
            .toString();
        await _storage.write(key: _kFallback, value: fb);
      }
      return sha256.convert(utf8.encode(fb + _secretKey)).toString();
    }
  }

  Future<void> _persist(String key, String deviceId, int slot) async {
    await _storage.write(key: _kRawKey, value: key);
    final verifyHash = sha256
        .convert(utf8.encode('$key|$deviceId|$slot|$_secretKey'))
        .toString();
    await _storage.write(key: _kValid, value: '1');
    await _storage.write(key: _kHash, value: verifyHash);
    await _storage.write(key: _kDevice, value: deviceId);
    await _storage.write(key: _kSlot, value: slot.toString());
  }

  Future<bool> _verifyHash() async {
    try {
      final storedHash = await _storage.read(key: _kHash);
      final storedDevice = await _storage.read(key: _kDevice);
      final storedSlot = await _storage.read(key: _kSlot);
      final storedKey = await _storage.read(key: _kRawKey);
      if (storedHash == null ||
          storedDevice == null ||
          storedSlot == null ||
          storedKey == null) {
        return false;
      }
      final expected = sha256
          .convert(
            utf8.encode('$storedKey|$storedDevice|$storedSlot|$_secretKey'),
          )
          .toString();
      return storedHash == expected;
    } catch (_) {
      return false;
    }
  }
}

class LicenseResult {
  final bool success;
  final String message;
  final bool isNetworkError;

  const LicenseResult._({
    required this.success,
    required this.message,
    this.isNetworkError = false,
  });

  factory LicenseResult.ok(String msg) =>
      LicenseResult._(success: true, message: msg);
  factory LicenseResult.fail(String msg) =>
      LicenseResult._(success: false, message: msg);
  factory LicenseResult.networkError() => LicenseResult._(
    success: false,
    message: "Network error. Check your connection and try again.",
    isNetworkError: true,
  );
}
