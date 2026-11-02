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

  static Future<String> getSourceText(
    String url, {
    required String baseUrl,
  }) async {
    try {
      final value = await channel.invokeMethod<String>('getSourceText', {
        'url': url,
        'baseUrl': baseUrl,
      });
      if (value == null || value.trim().isEmpty) {
        throw const FormatException('书源网站返回了空内容');
      }
      return value;
    } on MissingPluginException {
      throw const OnlineComponentUnavailable();
    } on PlatformException catch (failure) {
      throw FormatException(failure.message ?? '书源网站暂时不可用，请检查网址和网络');
    }
  }

  static Future<String> postSourceJson(
    String url, {
    required String baseUrl,
    required String body,
  }) async {
    try {
      final value = await channel.invokeMethod<String>('postSourceJson', {
        'url': url,
        'baseUrl': baseUrl,
        'body': body,
      });
      if (value == null || value.trim().isEmpty) {
        throw const FormatException('书源 API 返回了空内容');
      }
      return value;
    } on MissingPluginException {
      throw const OnlineComponentUnavailable();
    } on PlatformException catch (failure) {
      throw FormatException(failure.message ?? '书源 API 请求失败，请检查网络');
    }
  }

  static Future<String> searchLightNovel(
    String query, {
    required String baseUrl,
    required int page,
  }) async {
    try {
      final value = await channel.invokeMethod<String>('searchLightnovel', {
        'query': query,
        'baseUrl': baseUrl,
        'page': page,
      });
      if (value == null || value.trim().isEmpty) {
        throw const FormatException('轻之国度搜索结果为空');
      }
      return value;
    } on MissingPluginException {
      throw const OnlineComponentUnavailable();
    } on PlatformException catch (failure) {
      throw FormatException(failure.message ?? '轻之国度搜索失败，请先完成独立登录');
    }
  }

  static Future<Uint8List> getSourceBytes(
    String url, {
    required String baseUrl,
    List<String> imageHosts = const [],
  }) async {
    try {
      final value = await channel.invokeMethod<Uint8List>('getSourceBytes', {
        'url': url,
        'baseUrl': baseUrl,
        'imageHosts': imageHosts,
      });
      if (value == null || value.isEmpty) {
        throw const FormatException('书源图片内容为空');
      }
      return value;
    } on MissingPluginException {
      throw const OnlineComponentUnavailable();
    } on PlatformException catch (failure) {
      throw FormatException(failure.message ?? '书源图片暂时不可用');
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

  static Future<bool> openSourceLogin(
    String loginUrl, {
    required String baseUrl,
    List<String> allowedHosts = const [],
  }) async {
    try {
      return await channel.invokeMethod<bool>('openSourceLogin', {
        'loginUrl': loginUrl,
        'baseUrl': baseUrl,
        'allowedHosts': allowedHosts,
      }) ?? false;
    } on MissingPluginException {
      throw const OnlineComponentUnavailable();
    } on PlatformException catch (failure) {
      throw FormatException(failure.message ?? '无法打开该书源的登录页面');
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
  static final Map<String, ({String baseUrl, List<String> imageHosts})>
      _sourceImageOrigins = {};

  static void configureSourceImageOrigins(
    Iterable<({String baseUrl, List<String> imageHosts})> sources,
  ) {
    _sourceImageOrigins.clear();
    for (final source in sources) {
      final base = Uri.tryParse(source.baseUrl);
      if (base == null || base.host.isEmpty) continue;
      final record = (
        baseUrl: source.baseUrl,
        imageHosts: List<String>.unmodifiable(source.imageHosts),
      );
      _sourceImageOrigins[base.host.toLowerCase()] = record;
      for (final host in source.imageHosts) {
        _sourceImageOrigins[host.toLowerCase()] = record;
      }
    }
  }

  static Future<Uint8List> illustration(
    String url, {
    bool cacheForViewing = true,
  }) {
    final uri = Uri.tryParse(url);
    var source = uri == null
        ? null
        : _sourceImageOrigins[uri.host.toLowerCase()];
    if (source == null && uri != null) {
      for (final entry in _sourceImageOrigins.entries) {
        if (uri.host.toLowerCase().endsWith('.${entry.key}')) {
          source = entry.value;
          break;
        }
      }
    }
    if (source != null) {
      return getSourceBytes(
        url,
        baseUrl: source.baseUrl,
        imageHosts: source.imageHosts,
      );
    }
    return illustrationReader(url);
  }

  static Future<void> clearIllustrations() async {}
}
