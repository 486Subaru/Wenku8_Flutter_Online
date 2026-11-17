/// Exceptions at the boundary between the reader and the official website.
class OnlineComponentUnavailable implements Exception {
  const OnlineComponentUnavailable();
  static const message = '当前平台尚未接入官方网页连接，可继续使用本地导入与阅读';
  @override
  String toString() => message;
}

abstract class OnlineAccessRequired implements Exception {
  const OnlineAccessRequired();
  String get message;
  @override
  String toString() => message;
}

class OnlineAuthenticationRequired extends OnlineAccessRequired {
  const OnlineAuthenticationRequired();
  @override
  String get message => '请先登录轻小说文库账号';
}

class OnlineChallengeRequired extends OnlineAccessRequired {
  const OnlineChallengeRequired();
  @override
  String get message => '官网要求浏览器验证，请先完成官方网页登录验证后重试';
}

class OnlineRedirectBlocked extends OnlineAccessRequired {
  const OnlineRedirectBlocked({this.origin});
  final String? origin;

  @override
  String get message {
    final location = origin == null ? '' : '（$origin）';
    return '官网跳转已被拦截$location。可打开文库官网确认访问状态后重试。';
  }
}

class OnlinePageNotFound extends FormatException {
  const OnlinePageNotFound() : super('官网返回 HTTP 404');
}

class OnlineRateLimited extends FormatException {
  OnlineRateLimited(this.reason, {this.retryAfterSeconds})
    : super(_message(reason, retryAfterSeconds));

  final String reason;
  final int? retryAfterSeconds;

  static String _message(String reason, int? seconds) {
    if (seconds == null || seconds <= 0) return '$reason，请稍后重试。';
    final duration = seconds < 60 ? '$seconds 秒' : '${(seconds + 59) ~/ 60} 分钟';
    return '$reason。应用已暂停官网请求，约 $duration 后可再试。';
  }

  @override
  String toString() => message;
}

Future<T> unavailableOnline<T>() =>
    Future<T>.error(const OnlineComponentUnavailable());

class BookSourceAuthenticationRequired implements Exception {
  const BookSourceAuthenticationRequired([this.message = '请先完成该书源网站的独立登录']);
  final String message;
  @override
  String toString() => message;
}
