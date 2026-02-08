/// 日志级别
enum ZiweiLogLevel {
  debug,
  info,
  warning,
  error,
}

/// 日志回调函数定义
typedef ZiweiLogCallback = void Function(ZiweiLogLevel level, String message, [Object? error, StackTrace? stackTrace]);

/// 核心日志代理类
///
/// 允许宿主 App 接管日志输出，避免库直接污染控制台。
/// 默认情况下，如果不设置 delegate，则不输出任何日志（静默模式）。
class ZiweiLogger {
  static ZiweiLogCallback? _delegate;

  /// 初始化日志代理
  ///
  /// 示例:
  /// ```dart
  /// ZiweiLogger.init((level, msg, [err, stack]) {
  ///   print("[$level] $msg");
  /// });
  /// ```
  static void init(ZiweiLogCallback delegate) {
    _delegate = delegate;
  }

  static void debug(String message) {
    _delegate?.call(ZiweiLogLevel.debug, message);
  }

  static void info(String message) {
    _delegate?.call(ZiweiLogLevel.info, message);
  }

  static void warn(String message, [Object? error, StackTrace? stackTrace]) {
    _delegate?.call(ZiweiLogLevel.warning, message, error, stackTrace);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _delegate?.call(ZiweiLogLevel.error, message, error, stackTrace);
  }
}
