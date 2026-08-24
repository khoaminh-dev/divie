import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/supabase_bootstrap.dart';
import 'core/config/app_config.dart';
import 'features/auth/login_page.dart';
import 'features/chat/live_chat_pages.dart';
import 'features/health/health_capture_page.dart';
import 'features/health/health_insights_page.dart';
import 'features/reminders/notification_service.dart';
import 'features/reminders/reminders_page.dart';
import 'core/data/reminder_data_service.dart';
import 'core/data/health_measurement_data_service.dart';
import 'core/device/emergency_service.dart';
import 'core/data/device_registration_service.dart';
import 'core/data/account_profile_service.dart';
import 'core/roles/app_role.dart';
import 'features/auth/role_selection_page.dart';
import 'features/assistant/voice_assistant_page.dart';
import 'core/data/emergency_contacts_data_service.dart';
import 'core/device/android_launcher_service.dart';
import 'features/settings/emergency_contacts_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.assertSafeConfiguration();
  try {
    await SupabaseBootstrap.initialize().timeout(const Duration(seconds: 10));
  } catch (error, stackTrace) {
    debugPrint('DiVie Supabase bootstrap failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  runApp(const DivieApp());
  unawaited(_initializeNotificationsSafely());
}

Future<void> _initializeNotificationsSafely() async {
  try {
    await NotificationService.instance.initialize().timeout(
      const Duration(seconds: 10),
    );
  } catch (error, stackTrace) {
    // Notification permission/device issues must not prevent the app shell
    // from opening. Reminder records remain available in Supabase.
    debugPrint('DiVie notification bootstrap failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class DivieApp extends StatelessWidget {
  const DivieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DiVie',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: DivieColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: DivieColors.teal,
          brightness: Brightness.light,
        ),
      ),
      home: const _AppGate(),
    );
  }
}

class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    if (!SupabaseBootstrap.enabled) return const _RoleGate();

    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) => client.auth.currentSession == null
          ? const LoginPage()
          : const _RoleGate(),
    );
  }
}

class _RoleGate extends StatefulWidget {
  const _RoleGate();

  @override
  State<_RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<_RoleGate> {
  final _store = AppRoleStore();
  AppRole? _role;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (SupabaseBootstrap.enabled &&
        Supabase.instance.client.auth.currentUser != null) {
      try {
        await AccountProfileService(
          Supabase.instance.client,
        ).ensureCurrentProfile();
      } catch (_) {
        // Profile sync is best effort; it must not block the app shell.
      }
    }
    final role = await _store.load();
    if (role != null) await _syncDeviceRole(role);
    if (!mounted) return;
    setState(() {
      _role = role;
      _loading = false;
    });
  }

  Future<void> _select(AppRole role) async {
    await _store.save(role);
    await _syncDeviceRole(role);
    if (!mounted) return;
    setState(() => _role = role);
  }

  Future<void> _syncDeviceRole(AppRole role) async {
    if (!SupabaseBootstrap.enabled) return;

    try {
      if (role == AppRole.family) {
        await NotificationService.instance.cancelAll();
      }
      await DeviceRegistrationService(
        client: Supabase.instance.client,
      ).syncRole(role);
    } catch (_) {
      // Device registration is auxiliary. A temporary network/database error
      // must not prevent the user from entering the app.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: DivieColors.teal)),
      );
    }
    final role = _role;
    return role == null
        ? RoleSelectionPage(onSelected: _select)
        : DivieShell(role: role, onRoleChanged: _select);
  }
}

abstract final class DivieColors {
  static const background = Color(0xFFF1FAFA);
  static const teal = Color(0xFF12A9B5);
  static const deepTeal = Color(0xFF00646C);
  static const navy = Color(0xFF10264D);
  static const muted = Color(0xFF687582);
  static const paleBlue = Color(0xFFE7F0FF);
  static const danger = Color(0xFFFF3F45);
}

class DivieShell extends StatefulWidget {
  const DivieShell({
    super.key,
    required this.role,
    required this.onRoleChanged,
  });

  final AppRole role;
  final ValueChanged<AppRole> onRoleChanged;

  @override
  State<DivieShell> createState() => _DivieShellState();
}

class _DivieShellState extends State<DivieShell> {
  int _selectedIndex = 0;
  RealtimeChannel? _reminderChannel;

  @override
  void initState() {
    super.initState();
    if (widget.role == AppRole.elder) {
      unawaited(_syncReminders());
    } else if (SupabaseBootstrap.enabled) {
      unawaited(NotificationService.instance.cancelAll());
    }
    _subscribeReminderSync();
  }

  void _subscribeReminderSync() {
    if (!SupabaseBootstrap.enabled) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    _reminderChannel = client
        .channel('divie-global-reminder-sync-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'medicine_reminders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'account_id',
            value: user.id,
          ),
          callback: (_) => unawaited(_syncReminders()),
        )
        .subscribe();
  }

  Future<void> _syncReminders() async {
    if (!SupabaseBootstrap.enabled) return;
    try {
      final service = ReminderDataService(client: Supabase.instance.client);
      final reminders = await service.load();
      for (final reminder in reminders) {
        await NotificationService.instance.trySchedule(reminder);
      }
    } catch (_) {
      // A temporary sync error must not block the main app shell.
    }
  }

  @override
  void didUpdateWidget(covariant DivieShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role == widget.role) return;
    if (widget.role == AppRole.elder) {
      unawaited(_syncReminders());
    } else if (SupabaseBootstrap.enabled) {
      unawaited(NotificationService.instance.cancelAll());
    }
  }

  @override
  void dispose() {
    final channel = _reminderChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }

  void _select(int index) {
    if (index == 2) {
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Đóng trợ lý',
        barrierColor: const Color(0x330B233F),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (dialogContext, _, _) => SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * .72,
                ),
                decoration: BoxDecoration(
                  color: DivieColors.background,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x330B233F),
                      blurRadius: 28,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: VoiceAssistantPage(embedded: true, onNavigate: _select),
              ),
            ),
          ),
        ),
        transitionBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, .16),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              ),
            ),
      );
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pageForIndex(_selectedIndex)),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(28, 0, 28, 16),
        child: _BottomNavigation(
          role: widget.role,
          selectedIndex: _selectedIndex,
          onSelected: _select,
        ),
      ),
    );
  }

  Widget _pageForIndex(int index) {
    switch (index) {
      case 1:
        return const _MessagesPage();
      case 3:
        return const _ContactsPage();
      case 4:
        return _SettingsPage(
          role: widget.role,
          onRoleChanged: widget.onRoleChanged,
        );
      default:
        return widget.role == AppRole.family
            ? _FamilyDashboardPage(onNavigate: _select)
            : _HomePage(role: widget.role, onNavigate: _select);
    }
  }
}

class _FamilyDashboardPage extends StatefulWidget {
  const _FamilyDashboardPage({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<_FamilyDashboardPage> createState() => _FamilyDashboardPageState();
}

class _FamilyDashboardPageState extends State<_FamilyDashboardPage> {
  _FamilyCareSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = SupabaseBootstrap.enabled
          ? Supabase.instance.client
          : null;
      final reminderService = ReminderDataService(client: client);
      final healthService = HealthMeasurementDataService(client: client);
      final reminders = await reminderService.load();
      final statuses = await reminderService.loadStatuses(DateTime.now());
      final measurements = await healthService.load(limit: 1);
      if (!mounted) return;
      final activeReminders = reminders.where((item) => item.enabled).toList();
      setState(() {
        _summary = _FamilyCareSummary(
          activeReminders: activeReminders.length,
          takenToday: activeReminders
              .where((item) => statuses[item.id] == 'taken')
              .length,
          skippedToday: activeReminders
              .where((item) => statuses[item.id] == 'skipped')
              .length,
          latestMeasurement: measurements.isEmpty ? null : measurements.first,
        );
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('DiVie family dashboard load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openHealth() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const HealthInsightsPage()));
  }

  void _openReminders() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RemindersPage(role: AppRole.family),
      ),
    );
  }

  void _openCareMessages() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LiveMessagesPage()));
  }

  void _openContacts() => widget.onNavigate(3);

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 34),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Góc người thân',
                      style: TextStyle(
                        color: DivieColors.navy,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Theo dõi sức khỏe và lịch thuốc trong tài khoản này',
                      style: TextStyle(
                        color: DivieColors.muted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Làm mới',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
                color: DivieColors.teal,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _FamilyTodayBand(
            summary: summary,
            loading: _loading,
            onTap: _openHealth,
          ),
          const SizedBox(height: 22),
          const Text(
            'Việc cần làm',
            style: TextStyle(
              color: DivieColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.22,
            children: [
              _FamilyActionTile(
                icon: Icons.monitor_heart_outlined,
                title: 'Theo dõi sức khỏe',
                subtitle: 'Chỉ số và xu hướng',
                color: DivieColors.teal,
                onTap: _openHealth,
              ),
              _FamilyActionTile(
                icon: Icons.medication_outlined,
                title: 'Quản lý thuốc',
                subtitle: 'Lịch và xác nhận',
                color: const Color(0xFF3777C8),
                onTap: _openReminders,
              ),
              _FamilyActionTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Tin nhắn',
                subtitle: 'Trao đổi với danh bạ',
                color: const Color(0xFF8B5EAF),
                onTap: _openCareMessages,
              ),
              _FamilyActionTile(
                icon: Icons.contact_phone_outlined,
                title: 'Danh bạ',
                subtitle: 'Gọi và nhắn tin',
                color: const Color(0xFFB45D3B),
                onTap: _openContacts,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Cần chú ý',
            style: TextStyle(
              color: DivieColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _FamilyAttention(
            summary: summary,
            loading: _loading,
            onOpenHealth: _openHealth,
            onOpenReminders: _openReminders,
          ),
        ],
      ),
    );
  }
}

class _FamilyCareSummary {
  const _FamilyCareSummary({
    required this.activeReminders,
    required this.takenToday,
    required this.skippedToday,
    required this.latestMeasurement,
  });

  final int activeReminders;
  final int takenToday;
  final int skippedToday;
  final HealthMeasurementHistoryItem? latestMeasurement;
}

class _FamilyTodayBand extends StatelessWidget {
  const _FamilyTodayBand({
    required this.summary,
    required this.loading,
    required this.onTap,
  });

  final _FamilyCareSummary? summary;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 134,
        child: Center(
          child: CircularProgressIndicator(color: DivieColors.teal),
        ),
      );
    }
    final data = summary;
    final measurement = data?.latestMeasurement;
    final pressure =
        measurement?.systolic != null && measurement?.diastolic != null
        ? '${measurement!.systolic}/${measurement.diastolic}'
        : 'Chưa có số đo';
    final measuredAt = measurement == null
        ? 'Chưa ghi nhận lần đo gần đây'
        : 'Cập nhật ${_shortDateTime(measurement.measuredAt)}';
    return Material(
      color: DivieColors.navy,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(
                Icons.favorite_rounded,
                color: Color(0xFF7FE2E3),
                size: 34,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tình hình hôm nay',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$pressure mmHg',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      measuredAt,
                      style: const TextStyle(
                        color: Color(0xFFC9DBE7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Thuốc',
                    style: TextStyle(color: Color(0xFFC9DBE7), fontSize: 13),
                  ),
                  Text(
                    '${data?.takenToday ?? 0}/${data?.activeReminders ?? 0}',
                    style: const TextStyle(
                      color: Color(0xFF7FE2E3),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'đã xác nhận',
                    style: TextStyle(color: Color(0xFFC9DBE7), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyActionTile extends StatelessWidget {
  const _FamilyActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 27),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: DivieColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: DivieColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FamilyAttention extends StatelessWidget {
  const _FamilyAttention({
    required this.summary,
    required this.loading,
    required this.onOpenHealth,
    required this.onOpenReminders,
  });

  final _FamilyCareSummary? summary;
  final bool loading;
  final VoidCallback onOpenHealth;
  final VoidCallback onOpenReminders;

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox.shrink();
    final data = summary;
    final measurement = data?.latestMeasurement;
    final high =
        (measurement?.systolic ?? 0) >= 140 ||
        (measurement?.diastolic ?? 0) >= 90;
    final low =
        (measurement?.systolic != null && measurement!.systolic! < 90) ||
        (measurement?.diastolic != null && measurement!.diastolic! < 60);
    final items =
        <
          ({
            IconData icon,
            Color color,
            String title,
            String text,
            VoidCallback onTap,
          })
        >[];
    if (high || low) {
      items.add((
        icon: Icons.monitor_heart_outlined,
        color: high ? const Color(0xFFD97706) : const Color(0xFF3777C8),
        title: 'Chỉ số cần theo dõi lại',
        text:
            'Lần đo gần nhất là ${measurement!.systolic}/${measurement.diastolic} mmHg. Nên đo lại khi đã nghỉ ngơi.',
        onTap: onOpenHealth,
      ));
    }
    if ((data?.skippedToday ?? 0) > 0) {
      items.add((
        icon: Icons.medication_outlined,
        color: const Color(0xFFB45D3B),
        title: '${data!.skippedToday} lịch thuốc đã bỏ qua',
        text: 'Mở Quản lý thuốc để xem lại và hỗ trợ người thân.',
        onTap: onOpenReminders,
      ));
    }
    if (items.isEmpty) {
      items.add((
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF198754),
        title: 'Chưa có việc cần chú ý',
        text:
            'DiVie sẽ hiển thị ở đây khi có chỉ số hoặc lịch thuốc cần theo dõi.',
        onTap: onOpenHealth,
      ));
    }
    return Column(
      children: [
        for (final item in items) ...[
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border(left: BorderSide(color: item.color, width: 4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.icon, color: item.color, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: DivieColors.navy,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.text,
                            style: const TextStyle(
                              color: DivieColors.muted,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

String _shortDateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class _HomePage extends StatelessWidget {
  const _HomePage({required this.role, required this.onNavigate});

  final AppRole role;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = _clamp(constraints.maxWidth * .052, 20, 30);
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HomeTopBar(role: role, onNavigate: onNavigate),
              SizedBox(height: _clamp(constraints.maxWidth * .07, 26, 42)),
              _HealthHubCard(role: role, onNavigate: onNavigate),
              const SizedBox(height: 12),
              _HealthChartButton(),
              SizedBox(height: _clamp(constraints.maxWidth * .085, 28, 48)),
              _FeatureGrid(role: role, onNavigate: onNavigate),
              const SizedBox(height: 36),
            ],
          ),
        );
      },
    );
  }
}

class _HealthChartButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      foregroundColor: DivieColors.teal,
      side: const BorderSide(color: Color(0x6618AAB3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    onPressed: () => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const HealthInsightsPage())),
    icon: const Icon(Icons.monitor_heart_outlined),
    label: const Text(
      'Biểu đồ sức khỏe',
      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
    ),
  );
}

double _clamp(double value, double min, double max) =>
    value.clamp(min, max).toDouble();

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({required this.role, required this.onNavigate});

  final AppRole role;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _CircleButton(
              icon: Icons.notifications_none_rounded,
              onPressed: () => _showNotifications(context),
            ),
            FutureBuilder<AccountProfile?>(
              future: SupabaseBootstrap.enabled
                  ? AccountProfileService(
                      Supabase.instance.client,
                    ).loadCurrent()
                  : null,
              builder: (context, snapshot) {
                final authUser = SupabaseBootstrap.enabled
                    ? Supabase.instance.client.auth.currentUser
                    : null;
                final email = authUser?.email?.trim();
                final emailName = email == null || email.isEmpty
                    ? null
                    : email.split('@').first.trim();
                final profileName = snapshot.data?.name.trim();
                final name =
                    _usableAccountName(profileName) ??
                    _usableAccountName(emailName) ??
                    role.label;
                return InkWell(
                  onTap: () => onNavigate(4),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    height: 52,
                    padding: EdgeInsets.only(left: compact ? 12 : 20, right: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [_SoftShadow()],
                    ),
                    child: Row(
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: compact ? 92 : 150,
                          ),
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: DivieColors.teal,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 8),
                          Text(
                            role.label,
                            style: const TextStyle(
                              color: DivieColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(width: 10),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF0F1F1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFF777777),
                            size: 27,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thông báo',
                style: TextStyle(
                  color: DivieColors.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Chưa có thông báo mới.',
                style: TextStyle(color: DivieColors.muted, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      shadowColor: const Color(0x220E7680),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Icon(icon, color: DivieColors.teal, size: 29),
        ),
      ),
    );
  }
}

class _HealthHubCard extends StatelessWidget {
  const _HealthHubCard({required this.role, required this.onNavigate});

  final AppRole role;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.12,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(32),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HealthCapturePage()),
          ),
          borderRadius: BorderRadius.circular(32),
          child: Container(
            padding: const EdgeInsets.fromLTRB(34, 26, 28, 26),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2BBBC3), Color(0xFF087B83)],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3210A8B4),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final titleSize = _clamp(constraints.maxWidth * .10, 28, 42);
                final detailSize = _clamp(constraints.maxWidth * .04, 14, 18);
                return Stack(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        role == AppRole.family
                            ? 'Sức khỏe\người thân'
                            : 'Sức khỏe\nhôm nay',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          height: 1.02,
                        ),
                      ),
                    ),
                    Align(
                      alignment: const Alignment(.72, -.48),
                      child: Icon(
                        Icons.favorite_rounded,
                        color: Colors.white.withValues(alpha: .92),
                        size: _clamp(constraints.maxWidth * .22, 60, 98),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        role == AppRole.family
                            ? 'Xem chỉ số và lịch sử đo'
                            : 'Đọc chỉ số từ ảnh máy đo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: detailSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.role, required this.onNavigate});

  final AppRole role;
  final ValueChanged<int> onNavigate;

  List<_Feature> get features => [
    const _Feature(Icons.chat_bubble_rounded, 'Tin nhắn', action: 'messages'),
    const _Feature(Icons.contacts_rounded, 'Danh bạ', action: 'contacts'),
    const _Feature(Icons.settings_rounded, 'Cài đặt', action: 'settings'),
    _Feature(
      Icons.favorite_rounded,
      role == AppRole.family ? 'Sức khỏe người thân' : 'Sức khỏe',
      action: 'health',
    ),
    _Feature(
      Icons.medication_rounded,
      role == AppRole.family ? 'Quản lý thuốc' : 'Nhắc thuốc',
      action: 'medicine',
    ),
    const _Feature(
      Icons.emergency_rounded,
      'Khẩn cấp',
      danger: true,
      action: 'emergency',
    ),
  ];

  void _open(BuildContext context, _Feature feature) {
    switch (feature.action) {
      case 'messages':
        onNavigate(1);
        return;
      case 'contacts':
        onNavigate(3);
        return;
      case 'settings':
        onNavigate(4);
        return;
      case 'health':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HealthCapturePage()),
        );
        return;
      case 'medicine':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RemindersPage(role: role)),
        );
        return;
      case 'emergency':
        _confirmEmergency(context);
        return;
    }
  }

  Future<void> _confirmEmergency(BuildContext context) async {
    final shouldCall = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gọi khẩn cấp?'),
        content: const Text(
          'DiVie sẽ mở cuộc gọi khẩn cấp. Chỉ tiếp tục nếu bạn thực sự cần hỗ trợ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gọi ngay'),
          ),
        ],
      ),
    );
    if (shouldCall != true || !context.mounted) return;
    try {
      final contacts = await EmergencyContactsDataService(
        client: SupabaseBootstrap.enabled ? Supabase.instance.client : null,
      ).load();
      if (contacts.isEmpty) {
        if (!context.mounted) return;
        final openSettings = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Chưa có số liên hệ khẩn cấp'),
            content: const Text(
              'Hãy thêm ít nhất một số người thân để DiVie có thể mở cuộc gọi khi cần.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Để sau'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Cài liên hệ'),
              ),
            ],
          ),
        );
        if (openSettings == true && context.mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EmergencyContactsPage()),
          );
        }
        return;
      }
      final first = contacts.first;
      await EmergencyService.callNumber(first);
      if (!context.mounted || contacts.length < 2) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Số liên hệ khẩn cấp tiếp theo',
                  style: TextStyle(
                    color: DivieColors.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                for (var index = 1; index < contacts.length; index++)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFFE6E3),
                      child: Text('${index + 1}'),
                    ),
                    title: Text(contacts[index]),
                    trailing: const Icon(Icons.phone_forwarded_rounded),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      try {
                        await EmergencyService.callNumber(contacts[index]);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Không thể mở cuộc gọi. Hãy kiểm tra quyền gọi điện rồi thử lại.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể mở cuộc gọi. Hãy kiểm tra quyền gọi điện rồi thử lại.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: features.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 24,
        mainAxisSpacing: 20,
        childAspectRatio: .88,
      ),
      itemBuilder: (context, index) {
        final feature = features[index];
        return Column(
          children: [
            Expanded(
              child: Material(
                color: feature.danger ? DivieColors.danger : Colors.white,
                borderRadius: BorderRadius.circular(25),
                elevation: 1,
                shadowColor: const Color(0x220E7680),
                child: InkWell(
                  onTap: () => _open(context, feature),
                  borderRadius: BorderRadius.circular(25),
                  child: Center(
                    child: Icon(
                      feature.icon,
                      size: 34,
                      color: feature.danger ? Colors.white : DivieColors.teal,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              feature.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: DivieColors.deepTeal,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Feature {
  const _Feature(this.icon, this.label, {this.danger = false, this.action});

  final IconData icon;
  final String label;
  final bool danger;
  final String? action;
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.role,
    required this.selectedIndex,
    required this.onSelected,
  });

  final AppRole role;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(42),
        boxShadow: [_NavShadow()],
      ),
      child: Row(
        children: [
          _NavItem(
            role == AppRole.family
                ? Icons.space_dashboard_rounded
                : Icons.home_rounded,
            0,
            selectedIndex,
            onSelected,
          ),
          _NavItem(Icons.chat_bubble_rounded, 1, selectedIndex, onSelected),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () => onSelected(2),
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: DivieColors.teal,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x4D10A8B4),
                        blurRadius: 15,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
          _NavItem(
            role == AppRole.family
                ? Icons.groups_rounded
                : Icons.contacts_rounded,
            3,
            selectedIndex,
            onSelected,
          ),
          _NavItem(
            role == AppRole.family
                ? Icons.tune_rounded
                : Icons.settings_rounded,
            4,
            selectedIndex,
            onSelected,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(this.icon, this.index, this.selectedIndex, this.onSelected);

  final IconData icon;
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: IconButton(
        onPressed: () => onSelected(index),
        icon: Icon(
          icon,
          size: 30,
          color: selectedIndex == index
              ? DivieColors.teal
              : const Color(0xFFB8B8B8),
        ),
      ),
    );
  }
}

class _MessagesPage extends StatelessWidget {
  const _MessagesPage();

  @override
  Widget build(BuildContext context) {
    if (SupabaseBootstrap.enabled) {
      return const LiveMessagesPage();
    }
    if (SupabaseBootstrap.initializationError != null) {
      return const _ConnectionRequiredPage(
        feature: 'tin nhắn',
        icon: Icons.chat_bubble_outline_rounded,
        error:
            'Không thể khởi tạo kết nối Supabase. Kiểm tra lại URL và khóa public.',
      );
    }
    return const _ConnectionRequiredPage(
      feature: 'tin nhắn',
      icon: Icons.chat_bubble_outline_rounded,
    );
  }
}

class _ContactsPage extends StatelessWidget {
  const _ContactsPage();

  @override
  Widget build(BuildContext context) {
    if (SupabaseBootstrap.enabled) {
      return const LiveContactsPage();
    }
    return const _ConnectionRequiredPage(
      feature: 'danh bạ',
      icon: Icons.contacts_outlined,
    );
  }
}

class _ConnectionRequiredPage extends StatelessWidget {
  const _ConnectionRequiredPage({
    required this.feature,
    required this.icon,
    this.error,
  });

  final String feature;
  final IconData icon;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return _SimplePage(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: DivieColors.teal, size: 52),
              const SizedBox(height: 16),
              Text(
                'Chưa kết nối $feature',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: DivieColors.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error ??
                    'Màn hình này chỉ hiển thị dữ liệu thật sau khi app kết nối Supabase. Không dùng dữ liệu mẫu.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DivieColors.muted, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.role, required this.onRoleChanged});

  final AppRole role;
  final ValueChanged<AppRole> onRoleChanged;

  Future<void> _signOut(BuildContext context) async {
    try {
      if (SupabaseBootstrap.enabled) {
        await Supabase.instance.client.auth.signOut();
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bản xem trước chưa kết nối tài khoản thật.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa thể đăng xuất. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SimplePage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cài đặt',
            style: TextStyle(
              color: DivieColors.navy,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tài khoản, trợ lý AI và thiết bị',
            style: TextStyle(
              color: DivieColors.muted,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 28),
          _AccountCard(role: role),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Đăng xuất tài khoản'),
              style: OutlinedButton.styleFrom(
                foregroundColor: DivieColors.danger,
                side: const BorderSide(color: DivieColors.danger),
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _RoleSettingTile(role: role, onRoleChanged: onRoleChanged),
          const SizedBox(height: 22),
          const _PremiumCard(),
          const SizedBox(height: 30),
          const _SettingsSection(
            title: 'An toàn',
            children: [
              _SettingsTile(
                icon: Icons.emergency_rounded,
                title: 'Liên hệ khẩn cấp',
                subtitle: 'Cài đặt tối đa 5 số gọi tự động khi khẩn cấp',
                iconBackground: Color(0xFFFFE6E3),
                iconColor: DivieColors.danger,
              ),
            ],
          ),
          const SizedBox(height: 26),
          const _SettingsSection(
            title: 'Trợ lý và thiết bị',
            children: [
              _SettingsTile(
                icon: Icons.record_voice_over_rounded,
                title: 'Giọng nói trợ lý',
                subtitle: 'Chọn bộ máy AI, model và giọng đọc',
                iconBackground: Color(0xFFDDF8F8),
                iconColor: DivieColors.teal,
              ),
              Divider(height: 1, indent: 74),
              _SettingsTile(
                icon: Icons.home_work_rounded,
                title: 'Màn hình chính DiVie',
                subtitle: 'Chế độ launcher/kiosk cho thiết bị Android',
                iconBackground: Color(0xFFDDF8F8),
                iconColor: DivieColors.teal,
                trailing: Switch.adaptive(value: false, onChanged: null),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const _SettingsSection(
            title: 'Tài khoản',
            children: [
              _SettingsTile(
                icon: Icons.workspace_premium_outlined,
                title: 'Gói sử dụng',
                subtitle: 'Miễn phí - còn giới hạn lượt dùng AI hằng ngày',
                iconBackground: Color(0xFFF0F1F1),
                iconColor: DivieColors.muted,
                trailing: Text(
                  'Free',
                  style: TextStyle(
                    color: DivieColors.muted,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _RoleSettingTile extends StatelessWidget {
  const _RoleSettingTile({required this.role, required this.onRoleChanged});

  final AppRole role;
  final ValueChanged<AppRole> onRoleChanged;

  Future<void> _change(BuildContext context) async {
    final selected = await showModalBottomSheet<AppRole>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppRole.values
              .map(
                (value) => ListTile(
                  leading: Icon(
                    value == AppRole.family
                        ? Icons.family_restroom_rounded
                        : Icons.elderly_rounded,
                    color: DivieColors.teal,
                  ),
                  title: Text(value.label),
                  subtitle: Text(value.description),
                  trailing: value == role
                      ? const Icon(Icons.check_circle, color: DivieColors.teal)
                      : null,
                  onTap: () => Navigator.pop(context, value),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected != null && selected != role) onRoleChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFDDF8F8),
            child: Icon(Icons.swap_horiz_rounded, color: DivieColors.teal),
          ),
          title: const Text(
            'Vai trò của thiết bị',
            style: TextStyle(
              color: DivieColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(role.label),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _change(context),
        ),
      ),
    );
  }
}

class _SimplePage extends StatelessWidget {
  const _SimplePage({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
            child: body,
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.role});

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AccountProfile?>(
      future: SupabaseBootstrap.enabled
          ? AccountProfileService(Supabase.instance.client).loadCurrent()
          : null,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final authUser = SupabaseBootstrap.enabled
            ? Supabase.instance.client.auth.currentUser
            : null;
        final authEmail = authUser?.email?.trim();
        final emailName = authEmail == null || authEmail.isEmpty
            ? null
            : authEmail.split('@').first.trim();
        final name =
            _usableAccountName(profile?.name) ??
            _usableAccountName(emailName) ??
            role.label;
        final email = profile?.email ?? authEmail ?? 'Chưa có email';
        return _SettingsCard(
          child: Row(
            children: [
              const CircleAvatar(
                radius: 39,
                backgroundColor: DivieColors.paleBlue,
                child: Icon(Icons.person, color: DivieColors.teal, size: 40),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: DivieColors.navy,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      email,
                      style: TextStyle(
                        color: DivieColors.muted,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: DivieColors.muted,
                size: 34,
              ),
            ],
          ),
        );
      },
    );
  }
}

String? _usableAccountName(String? value) {
  final cleaned = value?.trim();
  if (cleaned == null || cleaned.isEmpty) return null;
  if (cleaned.toLowerCase() == 'tài khoản') return null;
  return cleaned;
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFCE55), Color(0xFFFFA927)],
        ),
        borderRadius: BorderRadius.circular(34),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.black, size: 39),
          SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nâng cấp Premium',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Mở khóa trợ lý AI không giới hạn',
                  style: TextStyle(
                    color: Color(0xFF604619),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.black, size: 34),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: DivieColors.navy,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 13),
        _SettingsCard(child: Column(children: children)),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(30),
      ),
      child: child,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconBackground,
    required this.iconColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBackground;
  final Color iconColor;
  final Widget? trailing;

  VoidCallback? _defaultAction(BuildContext context) {
    if (icon == Icons.emergency_rounded) {
      return () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const EmergencyContactsPage()));
    }
    if (icon == Icons.record_voice_over_rounded) {
      return () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const VoiceAssistantPage()));
    }
    if (icon == Icons.home_work_rounded) {
      return () async {
        final enabled = await AndroidLauncherService.isHomeRoleHeld();
        if (!enabled) await AndroidLauncherService.requestHomeRole();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã mở phần chọn màn hình chính của Android.'),
            ),
          );
        }
      };
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: _defaultAction(context),
        borderRadius: BorderRadius.circular(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: iconColor, size: 29),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: DivieColors.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: DivieColors.muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: DivieColors.muted,
                  size: 32,
                ),
          ],
        ),
      ),
    );
  }
}

class _SoftShadow extends BoxShadow {
  const _SoftShadow()
    : super(
        color: const Color(0x120E7680),
        blurRadius: 14,
        offset: const Offset(0, 6),
      );
}

class _NavShadow extends BoxShadow {
  const _NavShadow()
    : super(
        color: const Color(0x1A0E7680),
        blurRadius: 20,
        offset: const Offset(0, 8),
      );
}
