// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/db_keys.dart';
import '../data/auth_repository.dart';

class AuthSessionController extends ChangeNotifier {
  AuthSessionController({
    required AuthRepository repository,
    required SharedPreferences preferences,
    required String server,
  })  : _repository = repository,
        _preferences = preferences,
        _server = server {
    if (_preferences.getString(DBKeys.uiLoginServer.name) == _server) {
      final refreshToken =
          _preferences.getString(DBKeys.uiLoginRefreshToken.name);
      if (refreshToken != null && !_isExpired(refreshToken)) {
        _refreshToken = refreshToken;
      }
    }
  }

  static const _refreshBeforeExpiry = Duration(seconds: 30);

  final AuthRepository _repository;
  final SharedPreferences _preferences;
  final String _server;

  String? _accessToken;
  String? _refreshToken;
  Future<void>? _loggingIn;
  Future<String?>? _refreshing;
  Timer? _refreshTimer;
  bool _isLoading = false;
  bool _disposed = false;
  int _sessionRevision = 0;

  String? get accessToken => _accessToken;
  bool get isLoggedIn => _refreshToken != null;
  bool get isLoading => _isLoading;

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final pendingLogin = _loggingIn;
    if (pendingLogin != null) {
      await pendingLogin;
      return;
    }

    final operation = _performLogin(
      username: username,
      password: password,
    );
    _loggingIn = operation;
    try {
      await operation;
    } finally {
      if (identical(_loggingIn, operation)) _loggingIn = null;
    }
  }

  Future<void> _performLogin({
    required String username,
    required String password,
  }) async {
    final revision = ++_sessionRevision;
    _setLoading(true);
    try {
      final tokens = await _repository.login(
        username: username,
        password: password,
      );
      if (_sessionRevision != revision) return;

      await Future.wait([
        _preferences.setString(
          DBKeys.uiLoginRefreshToken.name,
          tokens.refreshToken,
        ),
        _preferences.setString(DBKeys.uiLoginServer.name, _server),
      ]);
      if (_sessionRevision != revision) return;

      _refreshing = null;
      _refreshToken = tokens.refreshToken;
      _setAccessToken(tokens.accessToken);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _sessionRevision++;
    _refreshing = null;
    _refreshTimer?.cancel();
    _refreshToken = null;
    _accessToken = null;
    await Future.wait([
      _preferences.remove(DBKeys.uiLoginRefreshToken.name),
      _preferences.remove(DBKeys.uiLoginServer.name),
    ]);
    _notifyListeners();
  }

  Future<String?> getValidAccessToken() async {
    final accessToken = _accessToken;
    if (accessToken != null && !_expiresSoon(accessToken)) {
      return accessToken;
    }

    final pendingRefresh = _refreshing;
    if (pendingRefresh != null) return pendingRefresh;
    if (_refreshToken == null) return null;

    final refresh = _refreshAccessToken();
    _refreshing = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshing, refresh)) _refreshing = null;
    }
  }

  Future<String?> _refreshAccessToken() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return null;
    if (_isExpired(refreshToken)) {
      await logout();
      return null;
    }

    final accessToken =
        await _repository.refreshAccessToken(refreshToken);
    if (_refreshToken != refreshToken) return _accessToken;

    _setAccessToken(accessToken);
    return accessToken;
  }

  void _setAccessToken(String accessToken) {
    _accessToken = accessToken;
    _scheduleRefresh(accessToken);
    _notifyListeners();
  }

  void _scheduleRefresh(String accessToken) {
    _refreshTimer?.cancel();
    final expiry = _expirationOf(accessToken);
    if (expiry == null) return;

    final delay = expiry.difference(DateTime.now()) - _refreshBeforeExpiry;
    _refreshTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      refreshInBackground,
    );
  }

  Future<void> refreshInBackground() async {
    try {
      await getValidAccessToken();
    } catch (_) {
      // Keep the refresh token so a transient network failure can be retried.
    }
  }

  bool _expiresSoon(String token) {
    final expiration = _expirationOf(token);
    return expiration == null ||
        !expiration.isAfter(DateTime.now().add(_refreshBeforeExpiry));
  }

  bool _isExpired(String token) {
    final expiration = _expirationOf(token);
    return expiration == null || !expiration.isAfter(DateTime.now());
  }

  DateTime? _expirationOf(String token) {
    try {
      final segments = token.split('.');
      if (segments.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      final expiration =
          payload is Map<String, dynamic> ? payload['exp'] : null;
      if (expiration is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(
        expiration.toInt() * Duration.millisecondsPerSecond,
      );
    } catch (_) {
      return null;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    _notifyListeners();
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionRevision++;
    _refreshTimer?.cancel();
    super.dispose();
  }
}
