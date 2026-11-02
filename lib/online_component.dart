/// Exceptions at the boundary between the reader and the official website.
class OnlineComponentUnavailable implements Exception {
  const OnlineComponentUnavailable();
  static const message = '当前平台尚未接入官方网页连接，可继续使用本地导入与阅读';
  @override
  String toString() => message;
}

class OnlineAuthenticationRequired implements Exception {
  const OnlineAuthenticationRequired();
  @override
  String toString() => '请先登录轻小说文库账号';
}

class OnlineChallengeRequired implements Exception {
  const OnlineChallengeRequired();
  @override
  String toString() => '官网要求浏览器验证，请先完成官方网页登录验证后重试';
}

Future<T> unavailableOnline<T>() =>
    Future<T>.error(const OnlineComponentUnavailable());

class BookSourceAuthenticationRequired implements Exception {
  const BookSourceAuthenticationRequired([this.message = '请先完成该书源网站的独立登录']);
  final String message;
  @override
  String toString() => message;
}
