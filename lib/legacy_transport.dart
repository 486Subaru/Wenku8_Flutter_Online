import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'online_component.dart';

/// Android transport for the official Wenku8 website.
/// Cookies remain in Android WebView storage and never enter Dart or backups.
abstract final class LegacyTransport {
  static const channel = MethodChannel('org.mewx.wenku8/official_web');

  static Never _throwPlatform(PlatformException failure) {
    if (failure.code == 'WEB_LOGIN_REQUIRED') {
      throw const OnlineAuthenticationRequired();
    }
    if (failure.code == 'WEB_CHALLENGE') {
      throw const OnlineChallengeRequired();
    }
    throw FormatException(failure.message ?? '文库官网暂时不可用，请稍后重试');
  }

  static Future<String> getText(String url, {String? referer}) async {
    try {
      final value = await channel.invokeMethod<String>('getText', {
        'url': url,
        if (referer != null) 'referer': referer,
      });
      if (value == null || value.trim().isEmpty) {
        throw const FormatException('官网返回了空内容');
      }
      return value;
    } on MissingPluginException {
      throw const OnlineComponentUnavailable();
    } on PlatformException catch (failure) {
      _throwPlatform(failure);
    }
  }

  static Future<String> search(
    String query, {
    String field = 'articlename',
    int page = 1,
  }) async {
    try {
      final value = await channel.invokeMethod<String>('search', {
        'query': query,
        'field': field,
        'page': page,
      });
      if (value == null || value.trim().isEmpty) {
        throw const FormatException('搜索结果为空');
      }
      return value;
    } on MissingPluginException {
      throw const OnlineComponentUnavailable();
    } on PlatformException catch (failure) {
      _throwPlatform(failure);
    }
  }

  static Future<Uint8List> getBytes(String url, {String? referer}) async {
    try {
      final value = await channel.invokeMethod<Uint8List>('getBytes', {
        'url': url,
        if (referer != null) 'referer': referer,
      });
      if (value == null || value.isEmpty) {
        throw const FormatException('官网图片内容为空');
      }
      return value;
    } on MissingPluginException {
      throw const OnlineComponentUnavailable();
    } on PlatformException catch (failure) {
      _throwPlatform(failure);
    }
  }

  static Future<bool> hasSession() async {
    try {
      return await channel.invokeMethod<bool>('hasSession') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (failure) {
      _throwPlatform(failure);
    }
  }

  static Future<bool> openLogin() async {
    try {
      return await channel.invokeMethod<bool>('openLogin') ?? false;
    } on MissingPluginException {
      throw const OnlineComponentUnavailable();
    } on PlatformException catch (failure) {
      _throwPlatform(failure);
    }
  }

  static Future<void> clearSession() async {
    try {
      await channel.invokeMethod<void>('clearSession');
    } on MissingPluginException {
      throw const OnlineComponentUnavailable();
    } on PlatformException catch (failure) {
      _throwPlatform(failure);
    }
  }

  static Future<void> setUpdatePriority(bool enabled) async {}

  static Future<Uint8List> Function(String) illustrationReader = getBytes;

  static Future<Uint8List> illustration(
    String url, {
    bool cacheForViewing = true,
  }) => illustrationReader(url);

  static Future<void> clearIllustrations() async {}
}
