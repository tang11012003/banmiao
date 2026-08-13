import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/client.dart';
import '../models/auth.dart';
import '../models/user.dart';

/// 鉴权与全局用户状态。
///
/// 负责：登录态、token 持久化（shared_preferences）、当前用户与认证角色、
/// 短信验证码流程（开发态直接用后端返回的 dev_code）。
class AuthProvider with ChangeNotifier {
  final ApiClient api;
  final SharedPreferences prefs;
  final void Function(String, [Map<String, dynamic>?]) track;

  static const String _kToken = 'auth_token';
  static const String _kUserId = 'auth_user_id';
  static const String _kPhone = 'auth_phone';

  String? _token;
  User? _user;
  AuthVerification? _verification;
  bool _loading = false;
  String? _error;

  AuthProvider(this.api, this.prefs, this.track) {
    api.setToken(_token);
  }

  String? get token => _token;
  User? get user => _user;
  AuthVerification? get verification => _verification;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _token != null && _user != null;
  bool get isVerified => _user?.isVerified ?? false;

  /// 启动时从本地恢复登录态。
  ///
  /// 健壮性要求：无论网络是否可达、token 是否有效、响应能否解析，[init] 都必须
  /// 正常结束（不允许向外抛异常），否则调用方的首屏加载动画会永久挂起。
  Future<void> init() async {
    try {
      _token = prefs.getString(_kToken);
      final phone = prefs.getString(_kPhone);
      if (_token != null && phone != null) {
        api.setToken(_token);
        try {
          _user = await api.getProfile();
        } catch (_) {
          // token 失效 / 网络错误 / 解析失败，均视为未登录，清除本地态。
          await _clearLocal();
          _token = null;
        }
        try {
          await _refreshVerification();
        } catch (_) {
          _verification = null;
        }
      }
    } catch (_) {
      // 读取本地存储失败也不阻塞启动。
    } finally {
      notifyListeners();
    }
  }

  /// 发送短信验证码（开发态后端会返回 dev_code）。
  Future<String> sendSms(String phone) async {
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      final code = await api.sendSms(phone);
      return code;
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 验证码登录。
  Future<void> login(String phone, String code) async {
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      final res = await api.login(phone, code);
      _token = res.token;
      _user = res.user;
      await prefs.setString(_kToken, _token!);
      await prefs.setString(_kPhone, phone);
      api.setToken(_token);
      await _refreshVerification();
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 提交家长认证。
  Future<AuthVerification> submitVerification({
    required String method,
    String? materialImage,
    String? inviteCode,
  }) async {
    final av = await api.submitVerification(
      method: method,
      materialImage: materialImage,
      inviteCode: inviteCode,
    );
    _verification = av;
    notifyListeners();
    return av;
  }

  /// 使用邀请码完成认证。
  Future<AuthVerification> useInvite(String code) async {
    final av = await api.useInvite(code);
    _verification = av;
    // 邀请码认证会直接把用户升级为 parent，刷新资料。
    _user = await api.getProfile();
    notifyListeners();
    return av;
  }

  /// 拉取最新认证状态。
  Future<void> refreshVerification() => _refreshVerification();

  Future<void> _refreshVerification() async {
    try {
      _verification = await api.getVerificationStatus();
      // 若已通过，确保角色同步。
      if (_verification?.isApproved == true && _user != null) {
        _user = await api.getProfile();
      }
    } on ApiException {
      _verification = null;
    }
    notifyListeners();
  }

  /// 刷新用户资料。
  Future<void> refreshProfile() async {
    if (_token == null) return;
    _user = await api.getProfile();
    notifyListeners();
  }

  /// 退出登录。
  Future<void> logout() async {
    await _clearLocal();
    _token = null;
    _user = null;
    _verification = null;
    api.setToken(null);
    notifyListeners();
  }

  Future<void> _clearLocal() async {
    await prefs.remove(_kToken);
    await prefs.remove(_kPhone);
    await prefs.remove(_kUserId);
  }
}
