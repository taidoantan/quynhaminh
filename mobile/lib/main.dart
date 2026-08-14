import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/api.dart';

bool _isNewerVersion(String remote, String local) {
  List<int> parse(String v) =>
      v.split('+').first.split('.').map((x) => int.tryParse(x) ?? 0).toList();
  final a = parse(remote), b = parse(local);
  for (var i = 0;
      i < [a.length, b.length].reduce((x, y) => x > y ? x : y);
      i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

const blue = Color(0xff1769e0),
    bg = Color(0xfff5f8fd),
    green = Color(0xff35ad50),
    red = Color(0xfff04444);
String money(dynamic n) =>
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
        .format(num.tryParse('$n') ?? 0);
Color balanceColor(dynamic value) {
  final amount = num.tryParse('$value') ?? 0;
  if (amount < 0) return red;
  if (amount <= 1000000) return blue;
  return green;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN');
  runApp(const QuyNhaMinhApp());
}

class QuyNhaMinhApp extends StatelessWidget {
  const QuyNhaMinhApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quỹ Nhà Mình',
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: blue),
          scaffoldBackgroundColor: Colors.transparent,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: blue,
              elevation: 0,
              titleTextStyle: TextStyle(
                  color: blue, fontSize: 21, fontWeight: FontWeight.w800)),
          navigationBarTheme: NavigationBarThemeData(
              backgroundColor: Colors.white.withValues(alpha: .94),
              indicatorColor: const Color(0xffdceaff),
              labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                  color: states.contains(WidgetState.selected)
                      ? blue
                      : const Color(0xff6b7280),
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w800
                      : FontWeight.w600))),
          inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white.withValues(alpha: .92),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xffe5ebf5))),
              enabledBorder:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xffe5ebf5))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: blue, width: 1.4))),
          cardTheme: CardThemeData(elevation: 0, color: Colors.white.withValues(alpha: .94), margin: const EdgeInsets.symmetric(vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xffedf1f8))))),
      builder: (context, child) => DecoratedBox(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xffe8f3ff), Color(0xfff7faff), Color(0xfff4f7fc)])), child: child ?? const SizedBox()),
      home: const Gate());
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool? logged;
  @override
  void initState() {
    super.initState();
    Api.token().then((v) => setState(() => logged = v != null));
  }

  @override
  Widget build(BuildContext c) => logged == null
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : logged!
          ? FundGate(onLogout: () => setState(() => logged = false))
          : AuthScreen(onDone: () => setState(() => logged = true));
}

class AuthScreen extends StatefulWidget {
  final VoidCallback onDone;
  const AuthScreen({super.key, required this.onDone});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final name = TextEditingController(),
      email = TextEditingController(),
      pass = TextEditingController(),
      code = TextEditingController(),
      confirm = TextEditingController();
  bool register = false,
      reset = false,
      codeSent = false,
      busy = false,
      hide = true;
  String? error, notice;
  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      if (reset) {
        if (!codeSent) {
          await Api.forgotPassword(email.text);
          setState(() {
            codeSent = true;
            notice =
                'Nếu email đã đăng ký, mã xác nhận sẽ được gửi trong ít phút.';
          });
        } else {
          if (pass.text != confirm.text)
            throw ApiError('Mật khẩu xác nhận không khớp.', 400);
          await Api.resetPassword(email.text, code.text, pass.text);
          setState(() {
            reset = false;
            codeSent = false;
            pass.clear();
            confirm.clear();
            code.clear();
            notice = 'Đã đặt lại mật khẩu. Hãy đăng nhập.';
          });
        }
      } else {
        await Api.auth(register, name.text, email.text, pass.text);
        widget.onDone();
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void showReset() => setState(() {
        reset = true;
        register = false;
        codeSent = false;
        error = null;
        notice = null;
        pass.clear();
      });
  @override
  Widget build(BuildContext c) => Scaffold(
      body: LayoutBuilder(
          builder: (c, z) => Row(children: [
                if (z.maxWidth > 760)
                  Expanded(
                      child: Container(
                          decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [
                                Color(0xff1597f3),
                                Color(0xff145ee7)
                              ],
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft)),
                          child: const _Brand())),
                Expanded(
                    child: Center(
                        child: SingleChildScrollView(
                            padding: const EdgeInsets.all(22),
                            child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 420),
                                child: Column(children: [
                                  if (z.maxWidth <= 760)
                                    Container(
                                        height: 230,
                                        decoration: const BoxDecoration(
                                            gradient: LinearGradient(colors: [
                                              Color(0xff1597f3),
                                              Color(0xff145ee7)
                                            ]),
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(26))),
                                        child: const _Brand()),
                                  const SizedBox(height: 24),
                                  Text(
                                      reset
                                          ? (codeSent
                                              ? 'Đặt lại mật khẩu'
                                              : 'Quên mật khẩu')
                                          : (register
                                              ? 'Đăng ký'
                                              : 'Đăng nhập'),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 22)),
                                  const SizedBox(height: 10),
                                  if (reset)
                                    const Text(
                                        'Nhập email đã đăng ký để nhận mã xác nhận.',
                                        textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  if (register)
                                    TextField(
                                        controller: name,
                                        decoration: const InputDecoration(
                                            labelText: 'Họ và tên',
                                            prefixIcon:
                                                Icon(Icons.person_outline))),
                                  if (register) const SizedBox(height: 12),
                                  TextField(
                                      controller: email,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(
                                          labelText: 'Email',
                                          prefixIcon:
                                              Icon(Icons.email_outlined))),
                                  const SizedBox(height: 12),
                                  if (!reset || codeSent) ...[
                                    if (reset)
                                      TextField(
                                          controller: code,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                              labelText: 'Mã gồm 6 số',
                                              prefixIcon:
                                                  Icon(Icons.pin_outlined))),
                                    if (reset) const SizedBox(height: 12),
                                    TextField(
                                        controller: pass,
                                        obscureText: hide,
                                        decoration: InputDecoration(
                                            labelText: reset
                                                ? 'Mật khẩu mới'
                                                : 'Mật khẩu',
                                            prefixIcon:
                                                const Icon(Icons.lock_outline),
                                            suffixIcon: IconButton(
                                                onPressed: () => setState(
                                                    () => hide = !hide),
                                                icon: Icon(hide
                                                    ? Icons.visibility_outlined
                                                    : Icons
                                                        .visibility_off_outlined)))),
                                    if (reset) const SizedBox(height: 12),
                                    if (reset)
                                      TextField(
                                          controller: confirm,
                                          obscureText: hide,
                                          decoration: const InputDecoration(
                                              labelText:
                                                  'Xác nhận mật khẩu mới',
                                              prefixIcon:
                                                  Icon(Icons.lock_outline))),
                                  ],
                                  if (error != null)
                                    Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Text(error!,
                                            style:
                                                const TextStyle(color: red))),
                                  if (notice != null)
                                    Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Text(notice!,
                                            style:
                                                const TextStyle(color: green))),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: FilledButton(
                                          onPressed: busy ? null : submit,
                                          child: Text(busy
                                              ? 'Đang xử lý...'
                                              : reset
                                                  ? (codeSent
                                                      ? 'Đặt lại mật khẩu'
                                                      : 'Gửi mã qua email')
                                                  : (register
                                                      ? 'Tạo tài khoản'
                                                      : 'Đăng nhập')))),
                                  if (!reset && !register)
                                    TextButton(
                                        onPressed: showReset,
                                        child: const Text('Quên mật khẩu?')),
                                  TextButton(
                                      onPressed: () => setState(() {
                                            if (reset) {
                                              reset = false;
                                              codeSent = false;
                                            } else {
                                              register = !register;
                                            }
                                            error = null;
                                            notice = null;
                                          }),
                                      child: Text(reset
                                          ? 'Quay lại Đăng nhập'
                                          : (register
                                              ? 'Đã có tài khoản? Đăng nhập'
                                              : 'Chưa có tài khoản? Đăng ký')))
                                ])))))
              ])));
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext c) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/app_logo.png',
            height: 96,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.home_rounded, color: Colors.white, size: 90)),
        const Text('Quỹ Nhà Mình',
            style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Cùng nhau quản lý chi tiêu\nXây dựng tổ ấm hạnh phúc',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white))
      ]));
}

class FundGate extends StatefulWidget {
  final VoidCallback onLogout;
  const FundGate({super.key, required this.onLogout});
  @override
  State<FundGate> createState() => _FundGateState();
}

class _FundGateState extends State<FundGate> {
  List<dynamic> funds = [];
  bool busy = true;
  final ctl = TextEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      funds = await Api.funds();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> logout() async {
    await Api.logout();
    if (mounted) widget.onLogout();
  }

  Future<void> action(bool join) async {
    if (ctl.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      join ? await Api.joinFund(ctl.text) : await Api.createFund(ctl.text);
      ctl.clear();
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    if (busy) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (funds.isNotEmpty) return HomeShell(funds: funds);
    return Scaffold(
        appBar: AppBar(title: const Text('Bắt đầu'), actions: [
          TextButton.icon(
              onPressed: logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Đăng xuất')),
          const SizedBox(width: 6)
        ]),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.groups_rounded, size: 90, color: blue),
                      const Text('Tạo quỹ mới hoặc nhập mã mời'),
                      const SizedBox(height: 20),
                      TextField(
                          controller: ctl,
                          decoration: const InputDecoration(
                              labelText: 'Tên quỹ / mã mời')),
                      const SizedBox(height: 14),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                              onPressed: () => action(false),
                              icon: const Icon(Icons.add_home),
                              label: const Text('Tạo Quỹ Nhà Mình'))),
                      SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                              onPressed: () => action(true),
                              icon: const Icon(Icons.group_add),
                              label: const Text('Tham gia bằng mã')))
                    ])))));
  }
}

class AppState extends ChangeNotifier {
  List<dynamic> funds;
  int active = 0, tab = 0, revision = 0;
  AppState(this.funds);
  Map<String, dynamic> get fund => Map<String, dynamic>.from(funds[active]);
  String get id => '${fund['fundId'] ?? fund['id']}';
  void selectFund(int i) {
    active = i;
    revision++;
    notifyListeners();
  }

  void go(int i) {
    tab = i;
    notifyListeners();
  }

  void refresh() {
    revision++;
    notifyListeners();
  }

  Future<void> reloadFunds() async {
    funds = await Api.funds();
    if (active >= funds.length) active = 0;
    notifyListeners();
  }
}

class HomeShell extends StatefulWidget {
  final List<dynamic> funds;
  const HomeShell({super.key, required this.funds});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

const _appVersion = '2.0.12';

class _HomeShellState extends State<HomeShell> {
  late AppState s;

  Future<void> _checkForUpdate() async {
    try {
      final update = await Api.appUpdate();
      final version = '${update['version'] ?? ''}';
      if (!_isNewerVersion(version, _appVersion) || !mounted) return;
      final url = Uri.tryParse('${update['url'] ?? ''}');
      await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
                title: const Text('Có bản cập nhật mới'),
                content: Text(
                    'Phiên bản $version đã sẵn sàng.\n${update['notes'] ?? ''}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Để sau')),
                  FilledButton(
                      onPressed: url == null
                          ? null
                          : () async {
                              Navigator.pop(c);
                              await launchUrl(url,
                                  mode: LaunchMode.externalApplication);
                            },
                      child: const Text('Tải và cài đặt'))
                ],
              ));
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    s = AppState(widget.funds);
    Api.syncQueue();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
      listenable: s,
      builder: (c, _) => Scaffold(
          drawer: _Drawer(s),
          body: IndexedStack(index: s.tab, children: [
            DashboardScreen(s),
            TransactionsScreen(s),
            ReportsScreen(s),
            MoreScreen(s)
          ]),
          bottomNavigationBar: NavigationBar(
              selectedIndex: s.tab >= 2 ? s.tab + 1 : s.tab,
              onDestinationSelected: (index) {
                if (index == 2) {
                  Navigator.push(
                      c,
                      MaterialPageRoute(
                          builder: (_) => TransactionEditor(s))).then((v) {
                    if (v == true) s.refresh();
                  });
                } else {
                  s.go(index > 2 ? index - 1 : index);
                }
              },
              destinations: [
                const NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Tổng quan'),
                const NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long),
                    label: 'Giao dịch'),
                NavigationDestination(
                    icon: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                            color: blue, shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: Colors.white)),
                    label: 'Tạo'),
                const NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart),
                    label: 'Báo cáo'),
                const NavigationDestination(
                    icon: Icon(Icons.menu_outlined),
                    selectedIcon: Icon(Icons.menu),
                    label: 'Khác')
              ])));
}

class _Drawer extends StatelessWidget {
  final AppState s;
  const _Drawer(this.s);
  @override
  Widget build(BuildContext c) => Drawer(
          child: SafeArea(
              child: Column(children: [
        const ListTile(
            leading: CircleAvatar(
                backgroundColor: blue,
                child: Icon(Icons.home, color: Colors.white)),
            title: Text('Quỹ Nhà Mình',
                style: TextStyle(fontWeight: FontWeight.bold))),
        const Divider(),
        const Padding(
            padding: EdgeInsets.all(12),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text('CHUYỂN ĐỔI QUỸ',
                    style: TextStyle(fontSize: 12, color: Colors.grey)))),
        ...List.generate(
            s.funds.length,
            (i) => ListTile(
                selected: i == s.active,
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text('${s.funds[i]['name']}'),
                subtitle: Text('${s.funds[i]['role']}'),
                trailing:
                    i == s.active ? const Icon(Icons.check, color: blue) : null,
                onTap: () {
                  s.selectFund(i);
                  Navigator.pop(c);
                })),
        ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Tạo hoặc tham gia quỹ'),
            onTap: () =>
                showDialog(context: c, builder: (_) => JoinFundDialog(s))),
        const Spacer(),
        ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Đăng xuất'),
            onTap: () async {
              await Api.logout();
              if (c.mounted) {
                Navigator.pushAndRemoveUntil(
                    c,
                    MaterialPageRoute(builder: (_) => const Gate()),
                    (_) => false);
              }
            })
      ])));
}

class JoinFundDialog extends StatefulWidget {
  final AppState s;
  const JoinFundDialog(this.s, {super.key});
  @override
  State<JoinFundDialog> createState() => _JoinFundDialogState();
}

class _JoinFundDialogState extends State<JoinFundDialog> {
  final ctl = TextEditingController();
  bool join = true;
  @override
  Widget build(BuildContext c) => AlertDialog(
          title: Text(join ? 'Tham gia quỹ' : 'Tạo quỹ mới'),
          content: TextField(
              controller: ctl,
              decoration:
                  InputDecoration(labelText: join ? 'Mã mời' : 'Tên quỹ')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
            FilledButton(
                onPressed: () async {
                  join
                      ? await Api.joinFund(ctl.text)
                      : await Api.createFund(ctl.text);
                  await widget.s.reloadFunds();
                  if (c.mounted) Navigator.pop(c);
                },
                child: const Text('Xác nhận')),
            TextButton(
                onPressed: () => setState(() => join = !join),
                child: Text(join ? 'Tạo quỹ' : 'Nhập mã'))
          ]);
}

PreferredSizeWidget topBar(BuildContext c, AppState s, String title,
        {List<Widget>? actions}) =>
    AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: blue, fontWeight: FontWeight.w800, fontSize: 20)),
          Text('${s.fund['name']}',
              style: const TextStyle(fontSize: 11, color: blue))
        ]),
        actions: actions);

class DashboardScreen extends StatefulWidget {
  final AppState s;
  const DashboardScreen(this.s, {super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String dashboardChartType = 'expense';
  void changeMonth(int delta) =>
      setState(() => month = DateTime(month.year, month.month + delta));
  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: topBar(c, widget.s, 'Tổng quan', actions: [
        IconButton(
            onPressed: () => Navigator.push(c,
                MaterialPageRoute(builder: (_) => RemindersScreen(widget.s))),
            icon: const Icon(Icons.notifications_none))
      ]),
      body: FutureBuilder<dynamic>(
          key: ValueKey(
              '${widget.s.id}-${widget.s.revision}-${month.year}-${month.month}'),
          future: Api.dashboard(widget.s.id, month.year, month.month),
          builder: (c, x) {
            if (x.hasError) return ErrorView('${x.error}', widget.s.refresh);
            if (!x.hasData)
              return const Center(child: CircularProgressIndicator());
            final d = x.data;
            final allCats = List<dynamic>.from(d['categories'] ?? []);
            final cats =
                allCats.where((e) => '' == dashboardChartType).toList();
            return RefreshIndicator(
                onRefresh: () async => widget.s.refresh(),
                child: ListView(padding: const EdgeInsets.all(14), children: [
                  Card(
                      child: Row(children: [
                    IconButton(
                        onPressed: () => changeMonth(-1),
                        icon: const Icon(Icons.chevron_left_rounded)),
                    Expanded(
                        child: InkWell(
                            onTap: () async {
                              final pick = await showDatePicker(
                                  context: c,
                                  initialDate: month,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                  initialDatePickerMode: DatePickerMode.year);
                              if (pick != null)
                                setState(() =>
                                    month = DateTime(pick.year, pick.month));
                            },
                            child: Center(
                                child: Text(
                                    DateFormat('MMMM, yyyy', 'vi_VN')
                                        .format(month),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700))))),
                    IconButton(
                        onPressed: () => changeMonth(1),
                        icon: const Icon(Icons.chevron_right_rounded))
                  ])),
                  Row(children: [
                    Expanded(
                        child: MetricCard(
                            'Tổng thu', d['income'], green, Icons.south_west)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: MetricCard(
                            'Tổng chi', d['expense'], red, Icons.north_east))
                  ]),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  const Text('Số dư',
                                      style: TextStyle(color: Colors.grey)),
                                  Text(money(d['balance']),
                                      style: const TextStyle(
                                          color: blue,
                                          fontSize: 25,
                                          fontWeight: FontWeight.bold))
                                ])),
                            const SizedBox(
                                width: 120, height: 55, child: MiniChart())
                          ]))),
                  Row(children: [
                    Expanded(
                        child: SmallMetric('Chi hôm nay', d['todayExpense'])),
                    const SizedBox(width: 8),
                    Expanded(
                        child: SmallMetric('Chi tháng này', d['monthExpense']))
                  ]),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(children: [
                            CompareRow('Tổng thu so tháng trước',
                                d['incomeChangePercent'], green),
                            CompareRow('Tổng chi so tháng trước',
                                d['expenseChangePercent'], red)
                          ]))),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Biểu đồ chi tiêu theo danh mục',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            if (cats.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text('Chưa có giao dịch'))
                            else
                              SizedBox(
                                height: 190,
                                child: PieChart(PieChartData(
                                    centerSpaceRadius: 38,
                                    sections: cats
                                        .take(6)
                                        .toList()
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final value = (num.tryParse(
                                                  '${entry.value['amount']}') ??
                                              0)
                                          .toDouble();
                                      const colors = [
                                        blue,
                                        green,
                                        Colors.orange,
                                        Colors.purple,
                                        Colors.pink,
                                        Colors.teal
                                      ];
                                      return PieChartSectionData(
                                          value: value == 0 ? .01 : value,
                                          color: colors[entry.key],
                                          radius: 42,
                                          showTitle: false);
                                    }).toList())),
                              ),
                            _DashboardCategoryLegend(items: cats)
                          ]),
                    ),
                  ),
                ]));
          }));
}

class _DashboardCategoryLegend extends StatelessWidget {
  final List<dynamic> items;
  const _DashboardCategoryLegend({required this.items});
  @override
  Widget build(BuildContext context) {
    const colors = [
      blue,
      green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal
    ];
    final total = items.fold<double>(
        0, (v, e) => v + (num.tryParse('${e['amount']}') ?? 0).toDouble());
    return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
            children: items.take(6).toList().asMap().entries.map((entry) {
          final amount =
              (num.tryParse('${entry.value['amount']}') ?? 0).toDouble();
          return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Icon(Icons.circle,
                    size: 10, color: colors[entry.key % colors.length]),
                const SizedBox(width: 7),
                Expanded(
                    child: Text('${entry.value['name']}',
                        style: const TextStyle(fontSize: 12))),
                Text(
                    '${money(amount)} (${total == 0 ? 0 : (amount * 100 / total).round()}%)',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700))
              ]));
        }).toList()));
  }
}

class MetricCard extends StatelessWidget {
  final String title;
  final dynamic value;
  final Color color;
  final IconData icon;
  const MetricCard(this.title, this.value, this.color, this.icon, {super.key});
  @override
  Widget build(BuildContext c) => Card(
      child: Padding(
          padding: const EdgeInsets.all(15),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color),
            Text(title, style: const TextStyle(color: Colors.grey)),
            FittedBox(
                child: Text(money(value),
                    style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)))
          ])));
}

class SmallMetric extends StatelessWidget {
  final String title;
  final dynamic value;
  const SmallMetric(this.title, this.value, {super.key});
  @override
  Widget build(BuildContext c) => Card(
      child: Padding(
          padding: const EdgeInsets.all(15),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            FittedBox(
                child: Text(money(value),
                    style: const TextStyle(fontWeight: FontWeight.bold)))
          ])));
}

class CompareRow extends StatelessWidget {
  final String title;
  final dynamic value;
  final Color color;
  const CompareRow(this.title, this.value, this.color, {super.key});
  @override
  Widget build(BuildContext c) {
    final v = num.tryParse('$value') ?? 0;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(title)),
          Icon(v >= 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              color: color),
          Text('${v.abs()}%',
              style: TextStyle(color: color, fontWeight: FontWeight.bold))
        ]));
  }
}

class CategoryProgress extends StatelessWidget {
  final String name;
  final dynamic amount, total;
  const CategoryProgress(this.name, this.amount, this.total, {super.key});
  @override
  Widget build(BuildContext c) {
    final a = num.tryParse('$amount') ?? 0,
        t = num.tryParse('$total') ?? 1,
        p = (a / t).clamp(0, 1).toDouble();
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(flex: 2, child: Text(name)),
          Expanded(
              flex: 4,
              child: LinearProgressIndicator(
                  value: p,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8))),
          const SizedBox(width: 8),
          Text('${(p * 100).round()}%')
        ]));
  }
}

class MiniChart extends StatelessWidget {
  const MiniChart({super.key});
  @override
  Widget build(BuildContext c) => CustomPaint(painter: _LinePainter());
}

class _LinePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, s.height * .7)
      ..cubicTo(s.width * .25, s.height * .8, s.width * .28, s.height * .15,
          s.width * .5, s.height * .4)
      ..cubicTo(s.width * .7, s.height * .65, s.width * .8, s.height * .1,
          s.width, s.height * .25);
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_LinePainter old) => false;
}

class TransactionsScreen extends StatefulWidget {
  final AppState s;
  const TransactionsScreen(this.s, {super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String filter = '';
  String dayLabel(DateTime date) {
    final now = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    if (day == today)
      return 'Hôm nay · ${DateFormat('dd/MM/yyyy').format(date)}';
    if (day == today.subtract(const Duration(days: 1)))
      return 'Hôm qua · ${DateFormat('dd/MM/yyyy').format(date)}';
    return DateFormat('EEEE · dd/MM/yyyy', 'vi_VN').format(date);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: topBar(context, widget.s, 'Giao dịch'),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
            child: Row(children: [
              _TransactionFilter(
                  label: 'Tất cả',
                  color: blue,
                  selected: filter.isEmpty,
                  onTap: () => setState(() => filter = '')),
              const SizedBox(width: 7),
              _TransactionFilter(
                  label: 'Thu',
                  color: green,
                  selected: filter == 'income',
                  onTap: () => setState(() => filter = 'income')),
              const SizedBox(width: 7),
              _TransactionFilter(
                  label: 'Chi',
                  color: red,
                  selected: filter == 'expense',
                  onTap: () => setState(() => filter = 'expense')),
            ])),
        Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
                key: ValueKey('${widget.s.revision}$filter'),
                future: Api.transactions(widget.s.id,
                    query: filter.isEmpty
                        ? 'pageSize=200'
                        : 'type=$filter&pageSize=200'),
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return ErrorView('${snapshot.error}', widget.s.refresh);
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final groups = <String, List<Map<String, dynamic>>>{};
                  final dates = <String, DateTime>{};
                  for (final raw
                      in List<dynamic>.from(snapshot.data!['items'] ?? [])) {
                    final item = Map<String, dynamic>.from(raw);
                    final date =
                        DateTime.tryParse('${item['transactionDate']}') ??
                            DateTime.now();
                    final key = DateFormat('yyyy-MM-dd').format(date);
                    groups.putIfAbsent(key, () => []).add(item);
                    dates[key] = date;
                  }
                  final keys = groups.keys.toList()
                    ..sort((a, b) => b.compareTo(a));
                  if (keys.isEmpty)
                    return const Center(child: Text('Chưa có giao dịch nào'));
                  final rows = <Widget>[];
                  for (final key in keys) {
                    rows.add(Padding(
                        padding: const EdgeInsets.fromLTRB(8, 12, 8, 7),
                        child: Text(dayLabel(dates[key]!),
                            style: const TextStyle(
                                color: Color(0xff657188),
                                fontSize: 12,
                                fontWeight: FontWeight.w700))));
                    for (final item in groups[key]!) {
                      rows.add(TransactionTile(item,
                          onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => TransactionEditor(
                                          widget.s,
                                          editing: item))).then((saved) {
                                if (saved == true) widget.s.refresh();
                              })));
                    }
                  }
                  return RefreshIndicator(
                      onRefresh: () async => widget.s.refresh(),
                      child: ListView(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 96),
                          children: rows));
                }))
      ]));
}

class _TransactionFilter extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _TransactionFilter(
      {required this.label,
      required this.color,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
      child: OutlinedButton(
          style: OutlinedButton.styleFrom(
              backgroundColor: selected ? color : Colors.white,
              foregroundColor: selected ? Colors.white : color,
              side: BorderSide(color: color),
              minimumSize: const Size.fromHeight(46),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          onPressed: onTap,
          child: Text(label)));
}

class TransactionTile extends StatelessWidget {
  final Map<String, dynamic> x;
  final VoidCallback? onTap;
  const TransactionTile(this.x, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) {
    final income = x['type'] == 'income';
    final color = income ? green : red;
    final date = DateTime.tryParse('${x['transactionDate']}');
    final merchant = '${x['merchant'] ?? ''}'.trim();
    final subtitle =
        '${x['categoryName'] ?? (income ? 'Thu nhập' : 'Chi tiêu')} · ${x['creatorName'] ?? ''}${date == null ? '' : ' · ${DateFormat('HH:mm').format(date.toLocal())}'}';
    return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
                child: Row(children: [
                  CircleAvatar(
                      radius: 23,
                      backgroundColor: color.withValues(alpha: .13),
                      child: Icon(
                          income
                              ? Icons.account_balance_wallet_outlined
                              : Icons.shopping_bag_outlined,
                          color: color)),
                  const SizedBox(width: 13),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            merchant.isEmpty
                                ? (income ? 'Khoản thu' : 'Khoản chi')
                                : merchant,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xff1e293b))),
                        const SizedBox(height: 3),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xff758197), fontSize: 12))
                      ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${income ? '+' : '-'}${money(x['amount'])}',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                    const SizedBox(height: 3),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xff9aa6ba), size: 21)
                  ])
                ]))));
  }
}

class _SuggestionChips extends StatelessWidget {
  final String label;
  final List<String> values;
  final ValueChanged<String> onPick;
  const _SuggestionChips(
      {required this.label, required this.values, required this.onPick});
  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
            onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (sheet) => SafeArea(
                        child: ListView(shrinkWrap: true, children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                          child: Text(label,
                              style: Theme.of(context).textTheme.titleMedium)),
                      ...values.map((v) => ListTile(
                          title: Text(v),
                          onTap: () {
                            onPick(v);
                            Navigator.pop(sheet);
                          }))
                    ]))),
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: Text(label)));
  }
}

class TransactionEditor extends StatefulWidget {
  final AppState s;
  final Map<String, dynamic>? editing;
  final Map<String, dynamic>? suggestion;
  const TransactionEditor(this.s, {super.key, this.editing, this.suggestion});
  @override
  State<TransactionEditor> createState() => _TransactionEditorState();
}

class _TransactionEditorState extends State<TransactionEditor> {
  String type = 'expense';
  final amount = TextEditingController(),
      merchant = TextEditingController(),
      note = TextEditingController();
  List<dynamic> cats = [], accounts = [], history = [], members = [];
  String? cat, account, member;
  DateTime date = DateTime.now();
  bool busy = true;
  Color get accent => type == 'income' ? green : red;
  @override
  void initState() {
    super.initState();
    final e = widget.editing ?? widget.suggestion;
    if (e != null) {
      type = '${e['type'] ?? 'expense'}';
      amount.text = '${e['amount'] ?? ''}';
      merchant.text = '${e['merchant'] ?? ''}';
      note.text = '${e['note'] ?? ''}';
      if (e['transactionDate'] != null || e['date'] != null) {
        date =
            DateTime.tryParse('${e['transactionDate'] ?? e['date']}') ?? date;
      }
    }
    load();
  }

  Future<void> load() async {
    cats = await Api.list(widget.s.id, 'categories', query: 'type=$type');
    accounts = (await Api.list(widget.s.id, 'accounts')).fold<List<dynamic>>([],
        (all, item) {
      if (!all.any((x) => '${x['id']}' == '${item['id']}')) all.add(item);
      return all;
    });
    members = (await Api.list(widget.s.id, 'members')).fold<List<dynamic>>([],
        (all, item) {
      if (!all.any((x) => '${x['userId']}' == '${item['userId']}'))
        all.add(item);
      return all;
    });
    final previous = await Api.transactions(widget.s.id, query: 'pageSize=100');
    history = List<dynamic>.from(previous['items'] ?? []);
    final editingCategory = widget.editing?['categoryId']?.toString();
    final suggestedCategory = cats.cast<dynamic>().firstWhere(
        (e) =>
            widget.suggestion != null &&
            e['name'] == widget.suggestion!['category'],
        orElse: () => cats.isEmpty ? null : cats.first);
    cat = cats.any((e) => '${e['id']}' == editingCategory)
        ? editingCategory
        : suggestedCategory?['id']?.toString();
    member = widget.editing?['createdBy']?.toString();
    account = widget.editing?['accountId']?.toString() ??
        (accounts.isEmpty ? null : '${accounts.first['id']}');
    if (mounted) setState(() => busy = false);
  }

  Future<void> save() async {
    if (cat == null ||
        account == null ||
        num.tryParse(amount.text.replaceAll('.', '').replaceAll(',', '.')) ==
            null) {
      return;
    }
    setState(() => busy = true);
    try {
      await Api.save(
          widget.s.id,
          'transactions',
          {
            'fundId': widget.s.id,
            'categoryId': cat,
            'accountId': account,
            'type': type,
            'memberId': member,
            'amount':
                num.parse(amount.text.replaceAll('.', '').replaceAll(',', '.')),
            'transactionDate': date.toUtc().toIso8601String(),
            'note': note.text,
            'merchant': merchant.text,
            'receiptUrl': widget.suggestion?['imageUrl']
          },
          id: widget.editing?['id']?.toString());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(
          title: Text(
              widget.editing == null ? 'Thêm giao dịch' : 'Sửa giao dịch')),
      bottomNavigationBar: busy
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      textStyle: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  onPressed: save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Lưu giao dịch'))),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
              children: [
                  Row(children: [
                    Expanded(
                        child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor:
                                    type == 'income' ? green : Colors.white,
                                foregroundColor:
                                    type == 'income' ? Colors.white : green,
                                side: const BorderSide(color: green),
                                minimumSize: const Size.fromHeight(52),
                                textStyle: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w800)),
                            onPressed: () {
                              if (type != 'income') {
                                setState(() {
                                  type = 'income';
                                  cat = null;
                                  cats = [];
                                });
                                load();
                              }
                            },
                            icon: const Icon(Icons.south_west_rounded),
                            label: const Text('Thu'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor:
                                    type == 'expense' ? red : Colors.white,
                                foregroundColor:
                                    type == 'expense' ? Colors.white : red,
                                side: const BorderSide(color: red),
                                minimumSize: const Size.fromHeight(52),
                                textStyle: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w800)),
                            onPressed: () {
                              if (type != 'expense') {
                                setState(() {
                                  type = 'expense';
                                  cat = null;
                                  cats = [];
                                });
                                load();
                              }
                            },
                            icon: const Icon(Icons.north_east_rounded),
                            label: const Text('Chi')))
                  ]),
                  const SizedBox(height: 18),
                  TextField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: accent),
                      decoration: InputDecoration(
                          labelText: 'Số tiền',
                          suffixText: '₫',
                          suffixStyle: TextStyle(
                              color: accent, fontWeight: FontWeight.w800),
                          labelStyle: TextStyle(color: accent))),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                      initialValue: cat,
                      decoration: const InputDecoration(labelText: 'Danh mục'),
                      items: cats
                          .map((e) => DropdownMenuItem(
                              value: '${e['id']}',
                              child: Row(children: [
                                CircleAvatar(
                                    radius: 15,
                                    backgroundColor: _categoryColor(
                                            '${e['color'] ?? '#1769E0'}')
                                        .withValues(alpha: .14),
                                    child: Icon(
                                        _categoryIcon(
                                            '${e['icon'] ?? ''}', type),
                                        size: 17,
                                        color: _categoryColor(
                                            '${e['color'] ?? '#1769E0'}'))),
                                const SizedBox(width: 10),
                                Text('${e['name']}')
                              ])))
                          .toList(),
                      onChanged: (v) => setState(() => cat = v)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                      initialValue: account,
                      decoration:
                          const InputDecoration(labelText: 'Tài khoản tiền'),
                      items: accounts
                          .map((e) => DropdownMenuItem(
                              value: '${e['id']}',
                              child: Text(
                                  '${e['name']} • ${money(e['balance'])}')))
                          .toList(),
                      onChanged: (v) => setState(() => account = v)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                      initialValue: member,
                      decoration:
                          const InputDecoration(labelText: 'Thành viên'),
                      hint: const Text('Người nhập giao dịch'),
                      items: members
                          .map((e) => DropdownMenuItem(
                              value: '${e['userId']}',
                              child: Text('${e['displayName']}')))
                          .toList(),
                      onChanged: (v) => setState(() => member = v)),
                  const SizedBox(height: 12),
                  ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: const BorderSide(color: Color(0xffdddddd))),
                      leading: const Icon(Icons.calendar_month),
                      title: Text(DateFormat('dd/MM/yyyy').format(date)),
                      onTap: () async {
                        final d = await showDatePicker(
                            context: c,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDate: date);
                        if (d != null)
                          setState(() => date = DateTime(
                              d.year, d.month, d.day, date.hour, date.minute));
                      }),
                  const SizedBox(height: 8),
                  ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xffe5ebf5))),
                      leading: const Icon(Icons.access_time_rounded),
                      title: Text(DateFormat('HH:mm').format(date)),
                      onTap: () async {
                        final t = await showTimePicker(
                            context: c,
                            initialTime: TimeOfDay.fromDateTime(date));
                        if (t != null)
                          setState(() => date = DateTime(date.year, date.month,
                              date.day, t.hour, t.minute));
                      }),
                  const SizedBox(height: 12),
                  TextField(
                      controller: merchant,
                      decoration: const InputDecoration(
                          labelText: 'Cửa hàng / nguồn thu')),
                  _SuggestionChips(
                      label: 'Chọn cửa hàng đã nhập',
                      values: history
                          .map((e) => '${e['merchant'] ?? ''}'.trim())
                          .where((v) => v.isNotEmpty)
                          .toSet()
                          .take(8)
                          .toList(),
                      onPick: (v) => setState(() => merchant.text = v)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: note,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Mô tả (không bắt buộc)')),
                  _SuggestionChips(
                      label: 'Chọn mô tả đã dùng',
                      values: history
                          .map((e) => '${e['note'] ?? ''}'.trim())
                          .where((v) => v.isNotEmpty)
                          .toSet()
                          .take(8)
                          .toList(),
                      onPick: (v) => setState(() => note.text = v)),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                              c,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ReceiptScanScreen(widget.s))).then((v) {
                            if (v is Map && c.mounted) {
                              Navigator.pushReplacement(
                                  c,
                                  MaterialPageRoute(
                                      builder: (_) => TransactionEditor(
                                          widget.s,
                                          suggestion:
                                              Map<String, dynamic>.from(v))));
                            }
                          }),
                      icon: const Icon(Icons.document_scanner),
                      label: const Text('Đính kèm / quét hóa đơn')),
                  if (widget.editing != null)
                    TextButton.icon(
                        onPressed: () async {
                          await Api.remove(widget.s.id, 'transactions',
                              '${widget.editing!['id']}');
                          if (c.mounted) Navigator.pop(c, true);
                        },
                        icon: const Icon(Icons.delete_outline, color: red),
                        label: const Text('Chuyển vào thùng rác',
                            style: TextStyle(color: red)))
                ]));
}

class ReportsScreen extends StatefulWidget {
  final AppState s;
  const ReportsScreen(this.s, {super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int period = 1;
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String? memberId, categoryId;
  String reportChartType = 'expense';
  late Future<List<dynamic>> members;
  late Future<List<dynamic>> categories;
  @override
  void initState() {
    super.initState();
    members = Api.list(widget.s.id, 'members');
    categories = Api.list(widget.s.id, 'categories');
  }

  String get query {
    final n = selectedMonth;
    final from = period == 0
        ? DateTime(n.year, n.month, n.day)
        : period == 2
            ? DateTime(n.year, 1)
            : DateTime(n.year, n.month, 1);
    final to = period == 0
        ? DateTime(n.year, n.month, n.day + 1)
        : period == 2
            ? DateTime(n.year + 1, 1)
            : DateTime(n.year, n.month + 1, 1);
    return 'from=${Uri.encodeComponent(from.toUtc().toIso8601String())}&to=${Uri.encodeComponent(to.toUtc().toIso8601String())}${memberId == null ? '' : '&memberId=$memberId'}${categoryId == null ? '' : '&categoryId=$categoryId'}';
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: topBar(c, widget.s, 'Báo cáo'),
        body: FutureBuilder<List<dynamic>>(
            future: Future.wait([members, categories]),
            builder: (c, m) {
              if (!m.hasData)
                return const Center(child: CircularProgressIndicator());
              return FutureBuilder<dynamic>(
                  key: ValueKey(query),
                  future: Api.request(
                      'GET', '/api/funds/${widget.s.id}/reports?$query'),
                  builder: (c, x) {
                    if (x.hasError)
                      return ErrorView('${x.error}', () => setState(() {}));
                    if (!x.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final d = x.data,
                        cats = List<dynamic>.from(d['byCategory'] ?? []),
                        days = List<dynamic>.from(d['byDay'] ?? []);
                    return ListView(
                        padding: const EdgeInsets.all(14),
                        children: [
                          SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(value: 0, label: Text('Ngày')),
                                ButtonSegment(value: 1, label: Text('Tháng')),
                                ButtonSegment(value: 2, label: Text('Năm'))
                              ],
                              selected: {
                                period
                              },
                              onSelectionChanged: (v) =>
                                  setState(() => period = v.first)),
                          if (period == 1)
                            Card(
                                child: Row(children: [
                              IconButton(
                                  onPressed: () => setState(() =>
                                      selectedMonth = DateTime(
                                          selectedMonth.year,
                                          selectedMonth.month - 1)),
                                  icon: const Icon(Icons.chevron_left_rounded)),
                              Expanded(
                                  child: InkWell(
                                      onTap: () async {
                                        final d = await showDatePicker(
                                            context: c,
                                            initialDate: selectedMonth,
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2100),
                                            initialDatePickerMode:
                                                DatePickerMode.year);
                                        if (d != null)
                                          setState(() => selectedMonth =
                                              DateTime(d.year, d.month));
                                      },
                                      child: Center(
                                          child: Text(
                                              DateFormat('MMMM, yyyy', 'vi_VN')
                                                  .format(selectedMonth),
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold))))),
                              IconButton(
                                  onPressed: () => setState(() =>
                                      selectedMonth = DateTime(
                                          selectedMonth.year,
                                          selectedMonth.month + 1)),
                                  icon: const Icon(Icons.chevron_right_rounded))
                            ])),
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(children: [
                                    DropdownButtonFormField<String?>(
                                        initialValue: memberId,
                                        decoration: const InputDecoration(
                                            labelText: 'Thành viên',
                                            border: InputBorder.none),
                                        items: [
                                          const DropdownMenuItem(
                                              value: null,
                                              child: Text('Tất cả thành viên')),
                                          ...m.data![0].map((e) =>
                                              DropdownMenuItem(
                                                  value: '${e['userId']}',
                                                  child: Text(
                                                      '${e['displayName']}')))
                                        ],
                                        onChanged: (v) =>
                                            setState(() => memberId = v)),
                                    DropdownButtonFormField<String?>(
                                        initialValue: categoryId,
                                        decoration: const InputDecoration(
                                            labelText: 'Danh mục',
                                            border: InputBorder.none),
                                        items: [
                                          const DropdownMenuItem(
                                              value: null,
                                              child: Text('Tất cả danh mục')),
                                          ...m.data![1].map((e) =>
                                              DropdownMenuItem(
                                                  value: '${e['id']}',
                                                  child: Text('${e['name']}')))
                                        ],
                                        onChanged: (v) =>
                                            setState(() => categoryId = v)),
                                  ]))),
                          Row(children: [
                            Expanded(
                                child: MetricCard('Tổng thu', d['income'],
                                    green, Icons.arrow_downward)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: MetricCard('Tổng chi', d['expense'], red,
                                    Icons.arrow_upward))
                          ]),
                          _ReportCharts(
                              categories: cats,
                              days: days,
                              balance: d['balance'],
                              totalExpense: d['expense']),
                          Row(children: [
                            Expanded(
                                child: OutlinedButton.icon(
                                    onPressed: () => _showDownload(
                                        c,
                                        'Excel',
                                        Api.downloadUrl(
                                            widget.s.id, 'export/excel',
                                            query: query)),
                                    icon: const Icon(Icons.table_chart),
                                    label: const Text('Xuất Excel'))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: OutlinedButton.icon(
                                    onPressed: () => _showDownload(
                                        c,
                                        'PDF',
                                        Api.downloadUrl(
                                            widget.s.id, 'export/pdf',
                                            query: query)),
                                    icon: const Icon(Icons.picture_as_pdf),
                                    label: const Text('Xuất PDF')))
                          ]),
                        ]);
                  });
            }),
      );
}

class _ReportCharts extends StatelessWidget {
  final List<dynamic> categories, days;
  final dynamic balance, totalExpense;
  const _ReportCharts(
      {required this.categories,
      required this.days,
      required this.balance,
      required this.totalExpense});
  @override
  Widget build(BuildContext context) {
    const colors = [
      blue,
      green,
      Colors.orange,
      Colors.purple,
      red,
      Colors.teal
    ];
    final cats = categories.take(6).toList();
    final rows = days.take(12).toList();
    final total = (num.tryParse('$totalExpense') ?? 0).toDouble();
    return Column(children: [
      Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Số dư ${money(balance)}',
                        style: TextStyle(
                            color: balanceColor(balance),
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    const Text('Biến động thu chi theo ngày',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: blue)),
                    SizedBox(
                        height: 180,
                        child: BarChart(BarChartData(
                            titlesData: const FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            barTouchData: BarTouchData(enabled: false),
                            barGroups: rows
                                .asMap()
                                .entries
                                .map((x) => BarChartGroupData(
                                        x: x.key,
                                        barsSpace: 3,
                                        barRods: [
                                          BarChartRodData(
                                              toY: (num.tryParse(
                                                          '${x.value['income']}') ??
                                                      0)
                                                  .toDouble(),
                                              color: green,
                                              width: 7),
                                          BarChartRodData(
                                              toY: (num.tryParse(
                                                          '${x.value['expense']}') ??
                                                      0)
                                                  .toDouble(),
                                              color: red,
                                              width: 7)
                                        ]))
                                .toList()))),
                    const Row(children: [
                      Icon(Icons.circle, color: green, size: 10),
                      Text(' Thu  '),
                      Icon(Icons.circle, color: red, size: 10),
                      Text(' Chi')
                    ])
                  ]))),
      Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chi tiêu theo danh mục',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: blue)),
                    const SizedBox(height: 10),
                    if (cats.isEmpty)
                      const Text('Chưa có chi tiêu trong kỳ.')
                    else
                      Row(children: [
                        SizedBox(
                            width: 135,
                            height: 135,
                            child: PieChart(PieChartData(
                                centerSpaceRadius: 32,
                                sections: cats
                                    .asMap()
                                    .entries
                                    .map((x) => PieChartSectionData(
                                        value: ((num.tryParse(
                                                        '${x.value['amount']}') ??
                                                    0)
                                                .toDouble())
                                            .clamp(.01, double.infinity),
                                        color: colors[x.key % colors.length],
                                        radius: 38,
                                        showTitle: false))
                                    .toList()))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                children: cats.asMap().entries.map((x) {
                          final amount =
                              (num.tryParse('${x.value['amount']}') ?? 0)
                                  .toDouble();
                          return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(children: [
                                Icon(Icons.circle,
                                    size: 10,
                                    color: colors[x.key % colors.length]),
                                const SizedBox(width: 5),
                                Expanded(
                                    child: Text('${x.value['name']}',
                                        style: const TextStyle(fontSize: 12))),
                                Text(
                                    '${money(amount)} (${total == 0 ? 0 : (amount * 100 / total).round()}%)',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700))
                              ]));
                        }).toList()))
                      ])
                  ]))),
    ]);
  }
}

void _showDownload(BuildContext c, String kind, String url) => showDialog(
    context: c,
    builder: (_) => AlertDialog(
            title: Text('Xuất $kind'),
            content: SelectableText(
                'Đường dẫn tải bảo mật:\n$url\n\nTệp yêu cầu phiên đăng nhập hiện tại.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c), child: const Text('Đóng'))
            ]));

class ReceivedInvitationsScreen extends StatefulWidget {
  final AppState s;
  const ReceivedInvitationsScreen(this.s, {super.key});
  @override
  State<ReceivedInvitationsScreen> createState() =>
      _ReceivedInvitationsScreenState();
}

class _ReceivedInvitationsScreenState extends State<ReceivedInvitationsScreen> {
  late Future<List<dynamic>> items;
  @override
  void initState() {
    super.initState();
    items = Api.directInvitations();
  }

  Future<void> reply(Map item, bool accept) async {
    try {
      await Api.respondToInvitation('${item['id']}', accept);
      if (accept) await widget.s.reloadFunds();
      if (mounted) {
        setState(() => items = Api.directInvitations());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(accept ? 'Bạn đã tham gia quỹ.' : 'Đã từ chối lời mời.')));
      }
    } on ApiError catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Lời mời nhận được')),
      body: FutureBuilder<List<dynamic>>(
          future: items,
          builder: (_, snap) {
            if (!snap.hasData)
              return const Center(child: CircularProgressIndicator());
            if (snap.data!.isEmpty)
              return const Center(child: Text('Bạn chưa có lời mời nào.'));
            return ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: snap.data!.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final item = Map<String, dynamic>.from(snap.data![index]);
                  return Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.group_add_rounded,
                                    color: blue),
                                const SizedBox(height: 8),
                                Text('${item['fundName']}',
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                Row(children: [
                                  Expanded(
                                      child: OutlinedButton(
                                          onPressed: () => reply(item, false),
                                          child: const Text('Từ chối'))),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: FilledButton(
                                          onPressed: () => reply(item, true),
                                          child: const Text('Tham gia')))
                                ])
                              ])));
                });
          }));
}

class FundInfoDialog extends StatelessWidget {
  final AppState s;
  const FundInfoDialog(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final f = s.fund;
    final code = '${f['inviteCode'] ?? f['code'] ?? 'Chưa có mã mời'}';
    return AlertDialog(
      title: const Text('Thông tin quỹ'),
      content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${f['name'] ?? 'Quỹ Nhà Mình'}',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: blue)),
            const SizedBox(height: 12),
            Text('Mã mời: $code'),
            const SizedBox(height: 6),
            const Text('Bạn đang là thành viên của quỹ này.')
          ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Đóng'))
      ],
    );
  }
}

class MoreScreen extends StatelessWidget {
  final AppState s;
  const MoreScreen(this.s, {super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: topBar(c, s, 'Cài đặt'),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Section('Quản lý quỹ', [
          Menu(Icons.info_outline, 'Thông tin quỹ',
              () => showDialog(context: c, builder: (_) => FundInfoDialog(s))),
          Menu(
              Icons.people_outline,
              'Thành viên và phân quyền',
              () => Navigator.push(
                  c, MaterialPageRoute(builder: (_) => MembersScreen(s)))),
          Menu(
              Icons.qr_code,
              'Mã mời quỹ',
              () => Navigator.push(
                  c, MaterialPageRoute(builder: (_) => InviteScreen(s)))),
          Menu(
              Icons.mail_outline_rounded,
              'Lời mời nhận được',
              () => Navigator.push(
                  c,
                  MaterialPageRoute(
                      builder: (_) => ReceivedInvitationsScreen(s)))),
          Menu(
              Icons.account_balance_wallet_outlined,
              'Tài khoản tiền',
              () => Navigator.push(
                  c,
                  MaterialPageRoute(
                      builder: (_) => SimpleResourceScreen(
                          s, 'Tài khoản tiền', 'accounts')))),
          Menu(
              Icons.pie_chart_outline,
              'Ngân sách',
              () => Navigator.push(
                  c, MaterialPageRoute(builder: (_) => BudgetScreen(s)))),
          Menu(
              Icons.task_alt,
              'Nhắc việc',
              () => Navigator.push(
                  c, MaterialPageRoute(builder: (_) => RemindersScreen(s))))
        ]),
        Section('Cài đặt chung', [
          Menu(
              Icons.manage_accounts_outlined,
              'Quản lý tài khoản',
              () => Navigator.push(
                  c, MaterialPageRoute(builder: (_) => const AccountScreen()))),
          Menu(
              Icons.category_outlined,
              'Danh mục thu chi',
              () => Navigator.push(
                  c, MaterialPageRoute(builder: (_) => CategoriesScreen(s)))),
          Menu(
              Icons.document_scanner_outlined,
              'Quét hóa đơn (Gemini AI)',
              () => Navigator.push(
                  c, MaterialPageRoute(builder: (_) => ReceiptScanScreen(s)))),
          Menu(Icons.sync, 'Đồng bộ dữ liệu', () async {
            final n = await Api.syncQueue();
            if (c.mounted) {
              ScaffoldMessenger.of(c)
                  .showSnackBar(SnackBar(content: Text('Đã đồng bộ $n mục')));
            }
          }),
          Menu(
              Icons.backup_outlined,
              'Sao lưu và khôi phục',
              () => Navigator.push(
                  c, MaterialPageRoute(builder: (_) => BackupScreen(s)))),
          Menu(
              Icons.delete_outline,
              'Thùng rác',
              () => Navigator.push(
                  c, MaterialPageRoute(builder: (_) => TrashScreen(s)))),
          Menu(
              Icons.security,
              'Bảo mật',
              () => showAboutDialog(
                      context: c,
                      applicationName: 'Quỹ Nhà Mình',
                      applicationVersion: '2.0.0',
                      children: [
                        const Text(
                            'JWT, phân quyền theo quỹ; khóa Gemini chỉ nằm trên máy chủ.')
                      ])),
          Menu(Icons.info_outline, 'Giới thiệu ứng dụng', () {
            showAboutDialog(
                context: c,
                applicationName: 'Quỹ Nhà Mình',
                applicationVersion: _appVersion,
                children: const [
                  Text(
                      'Quỹ Nhà Mình là ứng dụng quản lý thu chi gia đình, giúp mọi thành viên ghi chép minh bạch, cùng theo dõi ngân sách và xây dựng tổ ấm an tâm.\n\nPhần mềm thuộc PTSoft. PTSoft phát triển các giải pháp phần mềm thân thiện, bảo mật và thiết thực cho cá nhân, gia đình và doanh nghiệp.')
                ]);
          }),
          Menu(Icons.logout, 'Đăng xuất', () async {
            final ok = await showDialog<bool>(
                context: c,
                builder: (d) => AlertDialog(
                      title: const Text('Đăng xuất?'),
                      content: const Text(
                          'Bạn sẽ cần đăng nhập lại để dùng ứng dụng.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(d, false),
                            child: const Text('Hủy')),
                        FilledButton(
                            onPressed: () => Navigator.pop(d, true),
                            child: const Text('Đăng xuất'))
                      ],
                    ));
            if (ok == true) {
              await Api.logout();
              if (c.mounted)
                Navigator.pushAndRemoveUntil(
                    c,
                    MaterialPageRoute(builder: (_) => const Gate()),
                    (_) => false);
            }
          })
        ])
      ]));
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<Map<String, dynamic>> profile;
  @override
  void initState() {
    super.initState();
    profile = Api.me();
  }

  Future<void> _edit(Map<String, dynamic> me) async {
    final controller =
        TextEditingController(text: '${me['displayName'] ?? ''}');
    final name = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
                title: const Text('Sửa tên hiển thị'),
                content: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration:
                        const InputDecoration(labelText: 'Tên hiển thị')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(d),
                      child: const Text('Hủy')),
                  FilledButton(
                      onPressed: () => Navigator.pop(d, controller.text),
                      child: const Text('Lưu'))
                ]));
    if (name == null || name.trim().isEmpty) return;
    try {
      await Api.updateProfile(name.trim());
      if (mounted) setState(() => profile = Api.me());
    } on ApiError catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Quản lý tài khoản')),
      body: FutureBuilder<Map<String, dynamic>>(
          future: profile,
          builder: (_, snap) {
            if (!snap.hasData)
              return const Center(child: CircularProgressIndicator());
            final me = snap.data!;
            return ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        CircleAvatar(
                            radius: 32,
                            backgroundColor: blue.withValues(alpha: .12),
                            child: Text(
                                '${me['displayName'] ?? 'U'}'[0].toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 24, color: blue))),
                        const SizedBox(height: 12),
                        Text('${me['displayName']}',
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.bold)),
                        Text('${me['email']}',
                            style: const TextStyle(color: Colors.grey))
                      ]))),
              const SizedBox(height: 10),
              Card(
                  child: Column(children: [
                ListTile(
                    leading: const Icon(Icons.edit_outlined, color: blue),
                    title: const Text('Sửa tên hiển thị'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _edit(me)),
                const Divider(height: 1),
                ListTile(
                    leading: const Icon(Icons.lock_reset_outlined, color: blue),
                    title: const Text('Đổi mật khẩu'),
                    subtitle: const Text('Dùng mã xác nhận gửi qua email'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Vào màn hình Đăng nhập và chọn Quên mật khẩu để đổi mật khẩu.'))))
              ]))
            ]);
          }));
}

class Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const Section(this.title, this.children, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.all(8),
            child: Text(title,
                style: const TextStyle(color: Colors.grey, fontSize: 12))),
        Card(child: Column(children: children))
      ]));
}

class Menu extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const Menu(this.icon, this.title, this.onTap, {super.key});
  @override
  Widget build(BuildContext c) => ListTile(
      leading: Icon(icon, color: blue),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap);
}

Future<void> _editDisplayName(BuildContext context) async {
  try {
    final me = await Api.me();
    final controller =
        TextEditingController(text: '${me['displayName'] ?? ''}');
    if (!context.mounted) return;
    final name = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
                title: const Text('Sửa tên hiển thị'),
                content: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration:
                        const InputDecoration(labelText: 'Tên hiển thị')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(d),
                      child: const Text('Hủy')),
                  FilledButton(
                      onPressed: () => Navigator.pop(d, controller.text),
                      child: const Text('Lưu'))
                ]));
    if (name == null || name.trim().isEmpty) return;
    await Api.updateProfile(name.trim());
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật tên hiển thị.')));
  } on ApiError catch (e) {
    if (context.mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
  }
}

class MembersScreen extends StatelessWidget {
  final AppState s;
  const MembersScreen(this.s, {super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('Thành viên'), actions: [
        IconButton(
            tooltip: 'Sửa tên hiển thị',
            onPressed: () => _editDisplayName(c),
            icon: const Icon(Icons.edit_outlined))
      ]),
      body: FutureBuilder<List<dynamic>>(
          future: Api.list(s.id, 'members'),
          builder: (c, x) {
            if (!x.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
                padding: const EdgeInsets.all(14),
                children: x.data!
                    .map((m) => Card(
                        child: ListTile(
                            leading: CircleAvatar(
                                child: Text('${m['displayName']}'[0])),
                            title: Text('${m['displayName']}'),
                            subtitle: Text('${m['email']}'),
                            trailing: DropdownButton<String>(
                                value: '${m['role']}',
                                items: const [
                                  DropdownMenuItem(
                                      value: 'owner', child: Text('Chủ quỹ')),
                                  DropdownMenuItem(
                                      value: 'admin', child: Text('Quản trị')),
                                  DropdownMenuItem(
                                      value: 'member',
                                      child: Text('Thành viên')),
                                  DropdownMenuItem(
                                      value: 'viewer', child: Text('Chỉ xem'))
                                ],
                                onChanged: m['role'] == 'owner'
                                    ? null
                                    : (v) => Api.request('PUT',
                                        '/api/funds/${s.id}/members/${m['id']}/role',
                                        body: {'role': v})))))
                    .toList());
          }));
}

class InviteScreen extends StatelessWidget {
  final AppState s;
  const InviteScreen(this.s, {super.key});

  String get _code => '${s.fund['inviteCode']}';
  String get _message =>
      'Mời bạn tham gia quỹ "${s.fund['name']}" trên ứng dụng Quỹ Nhà Mình.\n\nMã mời: $_code\n\nMở ứng dụng, vào Cài đặt → Mã mời quỹ → Nhập mã mời để tham gia.';

  Future<void> _share(BuildContext context) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: _message, subject: 'Lời mời tham gia Quỹ Nhà Mình'),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Chưa thể mở danh sách ứng dụng để chia sẻ.')),
        );
      }
    }
  }

  Future<void> _sendInApp(BuildContext context) async {
    final recipient = TextEditingController();
    final value = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
                title: const Text('Gửi trong ứng dụng'),
                content: TextField(
                    controller: recipient,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'Email hoặc tên hiển thị')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(d),
                      child: const Text('Hủy')),
                  FilledButton(
                      onPressed: () => Navigator.pop(d, recipient.text),
                      child: const Text('Gửi lời mời'))
                ]));
    // The dialog owns the TextField lifecycle; disposing here can race its closing animation.
    if (value == null || value.trim().isEmpty) return;
    try {
      await Api.sendDirectInvitation(s.id, value.trim());
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã gửi lời mời trong ứng dụng.')));
    } on ApiError catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _code));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã sao chép mã mời.')),
      );
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('Mời thành viên')),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(children: [
                              const Icon(Icons.group_add_rounded,
                                  size: 48, color: blue),
                              const SizedBox(height: 16),
                              const Text('Mã mời của quỹ',
                                  style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 10),
                              SelectableText(_code,
                                  style: const TextStyle(
                                      color: blue,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              const Text(
                                  'Gửi lời mời cho người thân. Họ chỉ cần mở ứng dụng và nhập mã này để tham gia quỹ.',
                                  textAlign: TextAlign.center)
                            ]))),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                        onPressed: () => _share(c),
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Gửi lời mời')),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                        onPressed: () => _sendInApp(c),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Gửi trong ứng dụng')),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                        onPressed: () => _copy(c),
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Sao chép mã mời')),
                    const SizedBox(height: 24),
                    const Text('Tham gia quỹ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Menu(
                        Icons.group_add,
                        'Nhập mã mời để tham gia quỹ khác',
                        () => showDialog(
                            context: c, builder: (_) => JoinFundDialog(s)))
                  ])))));
}

IconData _categoryIcon(String icon, String type) {
  const icons = <String, IconData>{
    'restaurant': Icons.restaurant_rounded,
    'utensils': Icons.restaurant_rounded,
    'water_drop': Icons.water_drop_rounded,
    'favorite': Icons.favorite_rounded,
    'sports_esports': Icons.sports_esports_rounded,
    'more_horiz': Icons.more_horiz_rounded,
    'category': Icons.category_rounded,
    'local_dining': Icons.restaurant_rounded,
    'directions_car': Icons.directions_car_rounded,
    'home': Icons.home_rounded,
    'bolt': Icons.bolt_rounded,
    'school': Icons.school_rounded,
    'medical_services': Icons.medical_services_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'movie': Icons.movie_rounded,
    'payments': Icons.payments_rounded,
    'volunteer_activism': Icons.volunteer_activism_rounded,
    'workspace_premium': Icons.workspace_premium_rounded,
  };
  return icons[icon] ??
      (type == 'income' ? Icons.savings_rounded : Icons.more_horiz_rounded);
}

Color _categoryColor(String value) {
  try {
    return Color(int.parse(value.replaceFirst('#', '0xff')));
  } catch (_) {
    return blue;
  }
}

class CategoriesScreen extends StatefulWidget {
  final AppState s;
  const CategoriesScreen(this.s, {super.key});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String search = '';
  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('Danh mục chi tiêu')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _newCategory(c),
          icon: const Icon(Icons.add),
          label: const Text('Thêm danh mục')),
      body: SafeArea(
          top: false,
          child: FutureBuilder<List<dynamic>>(
              future:
                  Api.list(widget.s.id, 'categories', query: 'type=expense'),
              builder: (c, snap) {
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());
                final items = snap.data!;
                return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisExtent: 100,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final e = items[i];
                      final color =
                          _categoryColor('${e['color'] ?? '#1769E0'}');
                      return Card(
                          child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {},
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                        radius: 22,
                                        backgroundColor:
                                            color.withValues(alpha: .14),
                                        child: Icon(
                                            _categoryIcon('${e['icon'] ?? ''}',
                                                'expense'),
                                            color: color)),
                                    const SizedBox(height: 8),
                                    Text('${e['name']}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600))
                                  ])));
                    });
              })));
  Future<void> _search(BuildContext c) async {
    final controller = TextEditingController(text: search);
    final value = await showDialog<String>(
        context: c,
        builder: (d) => AlertDialog(
                title: const Text('Tìm danh mục'),
                content: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        labelText: 'Tên danh mục')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(d),
                      child: const Text('Hủy')),
                  FilledButton(
                      onPressed: () => Navigator.pop(d, controller.text),
                      child: const Text('Tìm'))
                ]));
    if (value != null) setState(() => search = value);
  }

  void _newCategory(BuildContext c) {
    final t = TextEditingController();
    showDialog(
        context: c,
        builder: (_) => AlertDialog(
                title: const Text('Thêm danh mục chi tiêu'),
                content: TextField(
                    controller: t,
                    decoration:
                        const InputDecoration(labelText: 'Tên danh mục')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Hủy')),
                  FilledButton(
                      onPressed: () async {
                        await Api.save(widget.s.id, 'categories', {
                          'name': t.text,
                          'type': 'expense',
                          'icon': 'category',
                          'color': '#1769E0'
                        });
                        if (c.mounted) Navigator.pop(c);
                        setState(() {});
                      },
                      child: const Text('Lưu'))
                ]));
  }
}

class SimpleResourceScreen extends StatefulWidget {
  final AppState s;
  final String title, resource;
  const SimpleResourceScreen(this.s, this.title, this.resource, {super.key});
  @override
  State<SimpleResourceScreen> createState() => _SimpleResourceScreenState();
}

class _SimpleResourceScreenState extends State<SimpleResourceScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _addAccount,
          icon: const Icon(Icons.add),
          label: const Text('Thêm tài khoản')),
      body: FutureBuilder<List<dynamic>>(
          future: Api.list(widget.s.id, widget.resource),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
                padding: const EdgeInsets.all(14),
                children: snapshot.data!
                    .map((item) => Card(
                        child: ListTile(
                            leading: const CircleAvatar(
                                child: Icon(Icons.account_balance_wallet)),
                            title: Text('${item['name']}'),
                            subtitle: Text('${item['type']}'),
                            trailing:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(money(item['balance']),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              IconButton(
                                tooltip: 'Xóa tài khoản',
                                icon: const Icon(Icons.delete_outline,
                                    color: red),
                                onPressed: () => _deleteAccount(item),
                              ),
                            ]))))
                    .toList());
          }));

  Future<void> _deleteAccount(dynamic item) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('Xóa tài khoản?'),
              content: Text(
                  'Xóa tài khoản đã chọn? Tài khoản đã có giao dịch không thể xóa để bảo toàn lịch sử.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Hủy')),
                FilledButton.tonal(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Xóa')),
              ],
            ));
    if (confirmed != true || !mounted) return;
    try {
      await Api.remove(widget.s.id, 'accounts', '${item['id']}');
      if (mounted) setState(() {});
    } on ApiError catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _addAccount() async {
    final name = TextEditingController();
    final balance = TextEditingController(text: '0');
    String type = 'cash';
    final saved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setLocal) => AlertDialog(
                    title: const Text('Thêm tài khoản tiền'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: name,
                          decoration: const InputDecoration(
                              labelText: 'Tên tài khoản')),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                          initialValue: type,
                          decoration: const InputDecoration(
                              labelText: 'Loại tài khoản'),
                          items: const [
                            DropdownMenuItem(
                                value: 'cash', child: Text('Tiền mặt')),
                            DropdownMenuItem(
                                value: 'bank', child: Text('Ngân hàng')),
                            DropdownMenuItem(
                                value: 'ewallet', child: Text('Ví điện tử'))
                          ],
                          onChanged: (value) => setLocal(() => type = value!)),
                      const SizedBox(height: 10),
                      TextField(
                          controller: balance,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Số dư ban đầu', suffixText: '₫'))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Hủy')),
                      FilledButton(
                          onPressed: () async {
                            if (name.text.trim().isEmpty) return;
                            await Api.save(widget.s.id, 'accounts', {
                              'name': name.text.trim(),
                              'type': type,
                              'initialBalance': num.tryParse(balance.text
                                      .replaceAll('.', '')
                                      .replaceAll(',', '.')) ??
                                  0,
                              'currency': 'VND'
                            });
                            if (context.mounted) Navigator.pop(context, true);
                          },
                          child: const Text('Lưu'))
                    ])));
    if (saved == true && mounted) setState(() {});
  }
}

class BudgetScreen extends StatefulWidget {
  final AppState s;
  const BudgetScreen(this.s, {super.key});
  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  DateTime get now => DateTime.now();
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Ngân sách')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _addBudget,
          icon: const Icon(Icons.add),
          label: const Text('Đặt ngân sách')),
      body: FutureBuilder<List<dynamic>>(
          future: Api.list(widget.s.id, 'budgets',
              query: 'year=${now.year}&month=${now.month}'),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const Center(
                  child: Text('Chưa đặt ngân sách trong tháng này.'));
            }
            return ListView(
                padding: const EdgeInsets.all(14),
                children: snapshot.data!.map((item) {
                  final limit = num.tryParse('${item['limitAmount']}') ?? 1;
                  final spent = num.tryParse('${item['spent']}') ?? 0;
                  final ratio = (spent / limit).clamp(0, 1).toDouble();
                  return Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                      child: Text('${item['category']}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  Text('${(ratio * 100).round()}%')
                                ]),
                                Text('${money(spent)} / ${money(limit)}'),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 8,
                                    color: ratio >= .8 ? red : blue)
                              ])));
                }).toList());
          }));

  Future<void> _addBudget() async {
    final categories =
        await Api.list(widget.s.id, 'categories', query: 'type=expense');
    if (!mounted || categories.isEmpty) return;
    String categoryId = '${categories.first['id']}';
    final amount = TextEditingController();
    final saved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setLocal) => AlertDialog(
                    title: Text('Ngân sách tháng ${now.month}/${now.year}'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<String>(
                          initialValue: categoryId,
                          decoration:
                              const InputDecoration(labelText: 'Danh mục chi'),
                          items: categories
                              .map((item) => DropdownMenuItem(
                                  value: '${item['id']}',
                                  child: Text('${item['name']}')))
                              .toList(),
                          onChanged: (value) =>
                              setLocal(() => categoryId = value!)),
                      const SizedBox(height: 10),
                      TextField(
                          controller: amount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Giới hạn', suffixText: '₫'))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Hủy')),
                      FilledButton(
                          onPressed: () async {
                            final value = num.tryParse(amount.text
                                .replaceAll('.', '')
                                .replaceAll(',', '.'));
                            if (value == null || value <= 0) return;
                            await Api.save(widget.s.id, 'budgets', {
                              'categoryId': categoryId,
                              'year': now.year,
                              'month': now.month,
                              'limitAmount': value,
                              'warningPercent': 80
                            });
                            if (context.mounted) Navigator.pop(context, true);
                          },
                          child: const Text('Lưu'))
                    ])));
    if (saved == true && mounted) setState(() {});
  }
}

class RemindersScreen extends StatelessWidget {
  final AppState s;
  const RemindersScreen(this.s, {super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('Nhắc việc')),
      body: FutureBuilder<List<dynamic>>(
          future: Api.list(s.id, 'reminders'),
          builder: (c, x) {
            if (!x.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(padding: const EdgeInsets.all(14), children: [
              ...x.data!.map((e) => Card(
                  child: ListTile(
                      leading:
                          const Icon(Icons.notifications_active, color: blue),
                      title: Text('${e['title']}'),
                      subtitle: Text('${e['nextDueAt']} • ${e['recurrence']}'),
                      trailing: Switch(
                          value: e['isEnabled'] ?? true,
                          onChanged: (_) => {})))),
              OutlinedButton.icon(
                  onPressed: () => _newReminder(c),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm nhắc việc'))
            ]);
          }));
  void _newReminder(BuildContext c) {
    final t = TextEditingController();
    showDialog(
        context: c,
        builder: (_) => AlertDialog(
                title: const Text('Nhắc việc mới'),
                content: TextField(
                    controller: t,
                    decoration: const InputDecoration(labelText: 'Nội dung')),
                actions: [
                  FilledButton(
                      onPressed: () async {
                        await Api.save(s.id, 'reminders', {
                          'title': t.text,
                          'expectedAmount': null,
                          'nextDueAt': DateTime.now()
                              .add(const Duration(days: 1))
                              .toUtc()
                              .toIso8601String(),
                          'recurrence': 'none',
                          'isEnabled': true
                        });
                        if (c.mounted) Navigator.pop(c);
                      },
                      child: const Text('Lưu'))
                ]));
  }
}

class ReceiptScanScreen extends StatefulWidget {
  final AppState s;
  const ReceiptScanScreen(this.s, {super.key});
  @override
  State<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends State<ReceiptScanScreen> {
  bool busy = false;
  String? error;
  Map<String, dynamic>? result;
  Future<void> pick(ImageSource source) async {
    final x = await ImagePicker()
        .pickImage(source: source, maxWidth: 1800, imageQuality: 80);
    if (x == null) return;
    setState(() => busy = true);
    try {
      Uint8List bytes = await x.readAsBytes();
      if (!kIsWeb) {
        bytes = await FlutterImageCompress.compressWithFile(x.path,
                quality: 72, minWidth: 1200) ??
            bytes;
      }
      final data = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      result = Map<String, dynamic>.from(await Api.analyze(widget.s.id, data));
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('Quét hóa đơn (AI)')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Card(
            child: Container(
                height: 280,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.blue.shade100, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(14)),
                child: busy
                    ? const CircularProgressIndicator()
                    : const Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.photo_camera_outlined,
                            size: 75, color: blue),
                        Text('Chụp hoặc chọn ảnh hóa đơn')
                      ]))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: FilledButton.icon(
                  onPressed: busy ? null : () => pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Chụp ảnh'))),
          const SizedBox(width: 8),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: busy ? null : () => pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Chọn ảnh')))
        ]),
        if (error != null)
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text(error!, style: const TextStyle(color: red))),
        if (result != null)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Kết quả Gemini AI',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('Cửa hàng: ${result!['merchant'] ?? 'Không rõ'}'),
                        Text('Ngày: ${result!['date'] ?? 'Không rõ'}'),
                        Text('Số tiền: ${money(result!['amount'])}',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        Text('Danh mục đề xuất: ${result!['category']}'),
                        Text(
                            'Độ tin cậy: ${((num.tryParse('${result!['confidence']}') ?? 0) * 100).round()}%'),
                        ...List<dynamic>.from(result!['warnings'] ?? []).map(
                            (e) => Text('• $e',
                                style: const TextStyle(color: Colors.orange))),
                        const SizedBox(height: 12),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                                onPressed: () => Navigator.pop(c, result),
                                child: const Text('Kiểm tra và tạo giao dịch')))
                      ])))
      ]));
}

class BackupScreen extends StatelessWidget {
  final AppState s;
  const BackupScreen(this.s, {super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('Sao lưu và đồng bộ')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Icon(Icons.cloud_done, color: blue, size: 80),
        const Text(
            'Dữ liệu được đồng bộ qua máy chủ và có thể dùng trên nhiều điện thoại.',
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Card(
            child: ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('Tạo bản sao lưu JSON'),
                subtitle: const Text('Tải toàn bộ dữ liệu quỹ'),
                onTap: () => _showDownload(
                    c, 'bản sao lưu', Api.downloadUrl(s.id, 'backup')))),
        Card(
            child: ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Đồng bộ dữ liệu đang chờ'),
                onTap: () async {
                  final n = await Api.syncQueue();
                  if (c.mounted) {
                    ScaffoldMessenger.of(c).showSnackBar(
                        SnackBar(content: Text('Đã đồng bộ $n mục')));
                  }
                })),
        const Card(
            child: ListTile(
                leading: Icon(Icons.phone_android),
                title: Text('Khôi phục khi đổi máy'),
                subtitle:
                    Text('Đăng nhập cùng tài khoản để tự đồng bộ các quỹ.')))
      ]));
}

class TrashScreen extends StatefulWidget {
  final AppState s;
  const TrashScreen(this.s, {super.key});
  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('Thùng rác')),
      body: FutureBuilder<List<dynamic>>(
          future: Api.list(widget.s.id, 'trash'),
          builder: (c, x) {
            if (!x.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (x.data!.isEmpty) {
              return const Center(child: Text('Thùng rác trống'));
            }
            return ListView(
                padding: const EdgeInsets.all(14),
                children: x.data!
                    .map((e) => Card(
                        child: ListTile(
                            title: Text(money(e['amount'])),
                            subtitle: Text('${e['merchant']}'),
                            trailing: TextButton(
                                onPressed: () async {
                                  await Api.request('POST',
                                      '/api/funds/${widget.s.id}/trash/restore',
                                      body: {
                                        'ids': [e['id']]
                                      });
                                  setState(() {});
                                },
                                child: const Text('Khôi phục')))))
                    .toList());
          }));
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback retry;
  const ErrorView(this.message, this.retry, {super.key});
  @override
  Widget build(BuildContext c) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 60, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            FilledButton.tonalIcon(
                onPressed: retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'))
          ])));
}

