import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/client.dart';
import 'features/auth/login_page.dart';
import 'features/auth/verification_page.dart';
import 'features/calendar/calendar_page.dart';
import 'features/community/community_page.dart';
import 'features/analysis/analysis_center_page.dart';
import 'features/messages/messages_page.dart';
import 'features/paper/paper_upload_page.dart';
import 'features/profile/profile_page.dart';
import 'features/shell.dart';
import 'providers/auth_provider.dart';
import 'providers/tracker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final tracker = Tracker();
  final api = ApiClient(track: tracker.track);
  final auth = AuthProvider(api, prefs, tracker.track);

  runApp(MyApp(api: api, auth: auth, tracker: tracker));
}

/// 应用根：注入全局 Provider（API client / Auth 状态 / Tracker），
/// 启动后恢复登录态，按登录情况决定进入首页或登录页。
class MyApp extends StatefulWidget {
  final ApiClient api;
  final AuthProvider auth;
  final Tracker tracker;

  const MyApp(
      {Key? key,
      required this.api,
      required this.auth,
      required this.tracker})
      : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// 启动鉴权恢复，并保证首屏一定会渲染：
  /// - [AuthProvider.init] 异常（网络/解析/失效）不会导致永久加载动画；
  /// - 任何情况下最多等待 6s 后强制进入首屏（登录页或主页）。
  Future<void> _bootstrap() async {
    await Future.any([
      widget.auth.init(),
      Future.delayed(const Duration(seconds: 6)),
    ]).catchError((_) {});
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: widget.api),
        ChangeNotifierProvider<AuthProvider>.value(value: widget.auth),
        Provider<Tracker>.value(value: widget.tracker),
      ],
      child: MaterialApp(
        title: '陪读社区',
        theme: _buildTheme(),
        home: _ready
            ? const _Root()
            : const Scaffold(
                body: Center(child: CircularProgressIndicator())),
        routes: {
          '/login': (_) => const LoginPage(),
          '/verify': (_) => const VerificationPage(),
          '/paper/upload': (_) => const PaperUploadPage(),
          '/analysis': (_) => const AnalysisCenterPage(),
          '/community': (_) => const CommunityPage(),
          '/messages': (_) => const MessagesPage(),
          '/calendar': (_) => const CalendarPage(),
          '/profile': (_) => const ProfilePage(),
        },
      ),
    );
  }
}

/// 根据登录态选择首页或登录页。
class _Root extends StatelessWidget {
  const _Root({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return auth.isLoggedIn ? const HomeShell() : const LoginPage();
  }
}

/// 全局主题：暖橙红主色（虎扑风）+ 协调的亮色 colorScheme，更现代统一。
ThemeData _buildTheme() {
  const primary = Color(0xFFE6431A);
  const secondary = Color(0xFFF24B0A);
  const background = Color(0xFFF5F5F7);
  const surface = Colors.white;

  final colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: Colors.white,
    secondary: secondary,
    onSecondary: Colors.white,
    error: const Color(0xFFD32F2F),
    onError: Colors.white,
    background: background,
    onBackground: const Color(0xFF212121),
    surface: surface,
    onSurface: const Color(0xFF212121),
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      color: surface,
      elevation: 1,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A1A),
      ),
      iconTheme: IconThemeData(color: Color(0xFF424242)),
    ),
    cardTheme: CardTheme(
      color: surface,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFEAEAEA),
      thickness: 0.8,
      space: 1,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A1A),
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Color(0xFF424242),
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: Color(0xFF616161),
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
    ),
  );
}
