# ZTO Mobile App - Implementation Process (Phase 1)

เอกสารนี้ครอบคลุมเฉพาะ **Phase 1: Foundation & Member (Customer App)** ตามเงื่อนไขที่กำหนด

## Tech Decisions (Phase 1)

- Architecture: Feature-first
- State Management: Riverpod (ใช้มาตรฐานเดียว)
- Routing: go_router
- Responsive: flutter_screenutil
- Localization: easy_localization (EN / ZH / LO)

---

## 1) Foundation Setup

### 1.1 pubspec.yaml

วางไฟล์ที่: `pubspec.yaml`

```yaml
name: zto_mobile_app
description: ZTO Mobile App - Phase 1 Foundation & Member
publish_to: "none"

version: 1.0.0+1

environment:
  sdk: ">=3.3.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^2.6.1
  go_router: ^14.8.1
  easy_localization: ^3.0.7+1
  flutter_screenutil: ^5.9.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true

  assets:
    - assets/translations/
```

### 1.2 Folder Tree (Feature-first)

```text
lib/
  core/
    router/
      app_router.dart
    theme/
      app_theme.dart
  features/
    auth/
      application/
        auth_provider.dart
      presentation/
        screens/
          login_screen.dart
          register_screen.dart
    home/
      presentation/
        screens/
          home_screen.dart
    history/
      presentation/
        screens/
          history_screen.dart
    profile/
      presentation/
        screens/
          profile_screen.dart
    main_layout/
      presentation/
        screens/
          main_layout_screen.dart
  shared/
    widgets/
      custom_text_field.dart
      primary_button.dart
      language_toggle_button.dart
  main.dart

assets/
  translations/
    en.json
    zh.json
    lo.json
```

---

## 2) Localization (EN / ZH / LO)

### 2.1 main.dart setup with easy_localization + Riverpod + ScreenUtil

วางไฟล์ที่: `lib/main.dart`

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [
          Locale('en'),
          Locale('zh'),
          Locale('lo'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: const ZtoApp(),
      ),
    ),
  );
}

class ZtoApp extends ConsumerWidget {
  const ZtoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, __) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'ZTO Mobile App',
          theme: AppTheme.lightTheme,
          routerConfig: router,
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
        );
      },
    );
  }
}
```

### 2.2 Translation JSON structure

วางไฟล์ที่: `assets/translations/en.json`

```json
{
  "app_name": "ZTO Mobile App",
  "login": "Login",
  "register": "Register",
  "username": "Username",
  "password": "Password",
  "confirm_password": "Confirm Password",
  "switch_language": "Switch Language",
  "already_have_account": "Already have an account? Login",
  "dont_have_account": "Don't have an account? Register",
  "welcome_back": "Welcome back",
  "create_account": "Create account",
  "member_portal": "Member Portal",
  "notification": "Notification",
  "home": "Home",
  "history": "History",
  "profile": "Profile",
  "required_field": "This field is required",
  "password_too_short": "Password must be at least 6 characters",
  "password_not_match": "Passwords do not match",
  "login_success": "Login success",
  "register_success": "Register success"
}
```

วางไฟล์ที่: `assets/translations/zh.json`

```json
{
  "app_name": "ZTO移动应用",
  "login": "登录",
  "register": "注册",
  "username": "用户名",
  "password": "密码",
  "confirm_password": "确认密码",
  "switch_language": "切换语言",
  "already_have_account": "已有账号？去登录",
  "dont_have_account": "没有账号？去注册",
  "welcome_back": "欢迎回来",
  "create_account": "创建账号",
  "member_portal": "会员入口",
  "notification": "通知",
  "home": "首页",
  "history": "历史",
  "profile": "我的",
  "required_field": "此字段必填",
  "password_too_short": "密码至少6位",
  "password_not_match": "两次密码不一致",
  "login_success": "登录成功",
  "register_success": "注册成功"
}
```

วางไฟล์ที่: `assets/translations/lo.json`

```json
{
  "app_name": "ແອັບ ZTO Mobile",
  "login": "ເຂົ້າລະບົບ",
  "register": "ລົງທະບຽນ",
  "username": "ຊື່ຜູ້ໃຊ້",
  "password": "ລະຫັດຜ່ານ",
  "confirm_password": "ຢືນຢັນລະຫັດຜ່ານ",
  "switch_language": "ປ່ຽນພາສາ",
  "already_have_account": "ມີບັນຊີແລ້ວ? ເຂົ້າລະບົບ",
  "dont_have_account": "ຍັງບໍ່ມີບັນຊີ? ລົງທະບຽນ",
  "welcome_back": "ຍິນດີຕ້ອນຮັບກັບ",
  "create_account": "ສ້າງບັນຊີ",
  "member_portal": "ສ່ວນສະມາຊິກ",
  "notification": "ແຈ້ງເຕືອນ",
  "home": "ໜ້າຫຼັກ",
  "history": "ປະຫວັດ",
  "profile": "ໂປຣໄຟລ໌",
  "required_field": "ຈໍາເປັນຕ້ອງກອກຂໍ້ມູນ",
  "password_too_short": "ລະຫັດຜ່ານຕ້ອງມີຢ່າງໜ້ອຍ 6 ຕົວ",
  "password_not_match": "ລະຫັດຜ່ານບໍ່ຕົງກັນ",
  "login_success": "ເຂົ້າລະບົບສໍາເລັດ",
  "register_success": "ລົງທະບຽນສໍາເລັດ"
}
```

---

## 3) Authentication UI (Login/Register) + Validation + Language Toggle

### 3.1 Router

วางไฟล์ที่: `lib/core/router/app_router.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/main_layout/presentation/screens/main_layout_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: LoginScreen.routePath,
    routes: [
      GoRoute(
        path: LoginScreen.routePath,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RegisterScreen.routePath,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: MainLayoutScreen.routePath,
        builder: (context, state) => const MainLayoutScreen(),
      ),
    ],
  );
});
```

### 3.2 Theme

วางไฟล์ที่: `lib/core/theme/app_theme.dart`

```dart
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primaryOrange = Color(0xFFE66A1F);
  static const Color darkText = Color(0xFF1C1C1C);
  static const Color lightBackground = Color(0xFFF7F7F9);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryOrange,
        primary: primaryOrange,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryOrange),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: darkText,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: darkText),
      ),
    );
  }
}
```

### 3.3 Shared Widgets

วางไฟล์ที่: `lib/shared/widgets/custom_text_field.dart`

```dart
import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
      ),
    );
  }
}
```

วางไฟล์ที่: `lib/shared/widgets/primary_button.dart`

```dart
import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}
```

วางไฟล์ที่: `lib/shared/widgets/language_toggle_button.dart`

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Locale>(
      icon: const Icon(Icons.language),
      tooltip: 'switch_language'.tr(),
      onSelected: context.setLocale,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: Locale('en'),
          child: Text('English'),
        ),
        PopupMenuItem(
          value: Locale('zh'),
          child: Text('中文'),
        ),
        PopupMenuItem(
          value: Locale('lo'),
          child: Text('ລາວ'),
        ),
      ],
    );
  }
}
```

### 3.4 Auth Provider (Business Logic)

วางไฟล์ที่: `lib/features/auth/application/auth_provider.dart`

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.message,
  });

  final bool isLoading;
  final String? message;

  AuthState copyWith({
    bool? isLoading,
    String? message,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      message: message,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    if (username.isEmpty || password.isEmpty) {
      state = state.copyWith(message: 'required_field');
      return false;
    }

    if (password.length < 6) {
      state = state.copyWith(message: 'password_too_short');
      return false;
    }

    state = state.copyWith(isLoading: true, message: null);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    state = state.copyWith(isLoading: false, message: 'login_success');
    return true;
  }

  Future<bool> register({
    required String username,
    required String password,
    required String confirmPassword,
  }) async {
    if (username.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      state = state.copyWith(message: 'required_field');
      return false;
    }

    if (password.length < 6) {
      state = state.copyWith(message: 'password_too_short');
      return false;
    }

    if (password != confirmPassword) {
      state = state.copyWith(message: 'password_not_match');
      return false;
    }

    state = state.copyWith(isLoading: true, message: null);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    state = state.copyWith(isLoading: false, message: 'register_success');
    return true;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
```

### 3.5 Login Screen

วางไฟล์ที่: `lib/features/auth/presentation/screens/login_screen.dart`

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/language_toggle_button.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../application/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const String routePath = '/login';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final notifier = ref.read(authProvider.notifier);
    final success = await notifier.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (success) {
      context.go('/main');
    } else {
      final messageKey = ref.read(authProvider).message;
      if (messageKey != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageKey.tr())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              color: AppTheme.primaryOrange,
              child: Row(
                children: [
                  Text(
                    'member_portal'.tr(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const LanguageToggleButton(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 12.h),
                      Text(
                        'welcome_back'.tr(),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontSize: 28.sp,
                            ),
                      ),
                      SizedBox(height: 24.h),
                      CustomTextField(
                        label: 'username'.tr(),
                        controller: _usernameController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'required_field'.tr();
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 14.h),
                      CustomTextField(
                        label: 'password'.tr(),
                        controller: _passwordController,
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'required_field'.tr();
                          }
                          if (value.trim().length < 6) {
                            return 'password_too_short'.tr();
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 24.h),
                      PrimaryButton(
                        label: 'login'.tr(),
                        onPressed: _handleLogin,
                        isLoading: authState.isLoading,
                      ),
                      SizedBox(height: 12.h),
                      Align(
                        child: TextButton(
                          onPressed: () => context.push(RegisterScreen.routePath),
                          child: Text('dont_have_account'.tr()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 3.6 Register Screen

วางไฟล์ที่: `lib/features/auth/presentation/screens/register_screen.dart`

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/language_toggle_button.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../application/auth_provider.dart';
import 'login_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  static const String routePath = '/register';

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final notifier = ref.read(authProvider.notifier);
    final success = await notifier.register(
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      confirmPassword: _confirmPasswordController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    final messageKey = ref.read(authProvider).message;
    if (messageKey != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageKey.tr())),
      );
    }

    if (success) {
      context.go(LoginScreen.routePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              color: AppTheme.primaryOrange,
              child: Row(
                children: [
                  Text(
                    'member_portal'.tr(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const LanguageToggleButton(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 12.h),
                      Text(
                        'create_account'.tr(),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontSize: 28.sp,
                            ),
                      ),
                      SizedBox(height: 24.h),
                      CustomTextField(
                        label: 'username'.tr(),
                        controller: _usernameController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'required_field'.tr();
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 14.h),
                      CustomTextField(
                        label: 'password'.tr(),
                        controller: _passwordController,
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'required_field'.tr();
                          }
                          if (value.trim().length < 6) {
                            return 'password_too_short'.tr();
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 14.h),
                      CustomTextField(
                        label: 'confirm_password'.tr(),
                        controller: _confirmPasswordController,
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'required_field'.tr();
                          }
                          if (value.trim() != _passwordController.text.trim()) {
                            return 'password_not_match'.tr();
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 24.h),
                      PrimaryButton(
                        label: 'register'.tr(),
                        onPressed: _handleRegister,
                        isLoading: authState.isLoading,
                      ),
                      SizedBox(height: 12.h),
                      Align(
                        child: TextButton(
                          onPressed: () => context.pop(),
                          child: Text('already_have_account'.tr()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 4) Core Layout & Main Screen

### 4.1 Main Layout with BottomNavigationBar

วางไฟล์ที่: `lib/features/main_layout/presentation/screens/main_layout_screen.dart`

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../history/presentation/screens/history_screen.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  static const String routePath = '/main';

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    HomeScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home_rounded),
            label: 'home'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history_outlined),
            activeIcon: const Icon(Icons.history_rounded),
            label: 'history'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline_rounded),
            activeIcon: const Icon(Icons.person_rounded),
            label: 'profile'.tr(),
          ),
        ],
      ),
    );
  }
}
```

### 4.2 Home Tab with Notification Bell (Top Right)

วางไฟล์ที่: `lib/features/home/presentation/screens/home_screen.dart`

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppTheme.primaryOrange,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
          ),
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Text(
                  'app_name'.tr(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    color: AppTheme.primaryOrange,
                    tooltip: 'notification'.tr(),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'member_portal'.tr(),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

### 4.3 Placeholder Tabs

วางไฟล์ที่: `lib/features/history/presentation/screens/history_screen.dart`

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'history'.tr(),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}
```

วางไฟล์ที่: `lib/features/profile/presentation/screens/profile_screen.dart`

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'profile'.tr(),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}
```

---

## 5) Validation Rules Included

- Username: required
- Password: required + minimum 6 chars
- Confirm password: required + must match password
- Error feedback: show localized validator message + snackbar from provider state

---

## 6) How to Run (after Flutter SDK is installed)

```bash
flutter pub get
flutter run
```

> อัปเดตสถานะ (May 2026): ติดตั้ง Flutter SDK แล้ว, `flutter analyze` ผ่าน และรันแอปได้บน Chrome แล้ว
> หากต้องการรันบน Windows Desktop ให้เปิด Developer Mode ก่อน (เพื่อรองรับ symlink สำหรับ plugin)