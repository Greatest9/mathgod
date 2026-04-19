// lib/services/license_manager.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'secret_parts.dart';

/// License states — drives the gate UI.
enum LicenseState { valid, invalid, checking, networkError }

class LicenseManager {
  static final LicenseManager instance = LicenseManager._();
  LicenseManager._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _deviceInfo = DeviceInfoPlugin();

  // ─── Google Apps Script endpoint ────────────────────────────────────────────
  // Replace this URL after you deploy your Apps Script web app.
  // Keep the URL only in this one place — nowhere else in the codebase.
  static const String _verifyEndpoint =
      "https://script.google.com/macros/s/AKfycbwiUrYnmOn6OMSfVOEJYkkJ4Z7S-1ZWRyVmBQfsteEJT4IDYCfc8xOMJ9rY0wvUMZ4W/exec";

  // ─── Storage keys ───────────────────────────────────────────────────────────
  static const _kValid = 'mg_lv';
  static const _kHash = 'mg_lh';
  static const _kDevice = 'mg_ld';
  static const _kSlot = 'mg_ls';
  static const _kFallback = 'mg_fb';

  // ─── Key reconstruction (deferred to runtime) ───────────────────────────────
  String get _secretKey => SecretParts.assembled;

  // ────────────────────────────────────────────────────────────────────────────
  //  PUBLIC API
  // ────────────────────────────────────────────────────────────────────────────

  /// Check secure storage — true if device already activated.
  Future<bool> isActivated() async {
    try {
      final valid = await _storage.read(key: _kValid);
      if (valid != '1') return false;

      final storedDevice = await _storage.read(key: _kDevice);
      final currentDevice = await _deviceFingerprint();
      return storedDevice == currentDevice;
    } catch (_) {
      return false;
    }
  }

  /// Attempt online activation. Returns a [LicenseResult].
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

      final response = await http
          .post(
            Uri.parse(_verifyEndpoint),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'license': key,
              'device_id': deviceId,
              'action': 'activate',
              'ts': DateTime.now().millisecondsSinceEpoch.toString(),
            },
          )
          .timeout(const Duration(seconds: 12));

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

  /// Clear local license (support / debug use).
  Future<void> revoke() async {
    await _storage.deleteAll();
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  PRIVATE
  // ────────────────────────────────────────────────────────────────────────────

  bool _looksValid(String key) {
    // Accept: MATH-XXXX-XXXX-XXXX  or any 4-group dash-separated key
    return RegExp(
      r'^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$',
    ).hasMatch(key);
  }

  Future<String> _deviceFingerprint() async {
    try {
      final info = await _deviceInfo.androidInfo;
      final raw = '${info.id}|${info.model}|${info.product}|$_secretKey';
      final bytes = utf8.encode(raw);
      return sha256.convert(bytes).toString();
    } catch (_) {
      // Fallback: stable random stored in secure storage
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
    // Store a tamper-evident hash so local spoofing is detectable.
    final verifyHash = sha256
        .convert(utf8.encode('$key|$deviceId|$slot|$_secretKey'))
        .toString();
    await _storage.write(key: _kValid, value: '1');
    await _storage.write(key: _kHash, value: verifyHash);
    await _storage.write(key: _kDevice, value: deviceId);
    await _storage.write(key: _kSlot, value: slot.toString());
  }
}

// ─── Result type ──────────────────────────────────────────────────────────────
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
