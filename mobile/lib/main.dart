import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'services/api.dart';
import 'models/transaction.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quỹ Nhà Mình',
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff1769e0)),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xfff5f8fd)),
      home: const Gate());
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  State<Gate> createState() => _Gate();
}

class _Gate extends State<Gate> {
  bool? ok;
  @override
  void initState() {
    super.initState();
    Api.token().then((x) => setState(() => ok = x != null));
  }

  @override
  Widget build(c) => ok == null
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : ok!
          ? const FamilyGate()
          : Auth(onDone: () => setState(() => ok = true));
}

class Auth extends StatefulWidget {
  final VoidCallback onDone;
  const Auth({super.key, required this.onDone});
  State<Auth> createState() => _Auth();
}

class _Auth extends State<Auth> {
  final name = TextEditingController(),
      email = TextEditingController(),
      pass = TextEditingController();
  bool register = false, busy = false;
  String? error;
  Future go() async {
    setState(() => busy = true);
    try {
      await Api.auth(register ? '/auth/register' : '/auth/login',
          {'name': name.text, 'email': email.text, 'password': pass.text});
      widget.onDone();
    } catch (e) {
      setState(() => error = '$e');
    } finally {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(c) => Scaffold(
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Card(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(children: [
                                Image.asset('assets/app_logo.png',
                                    height: 130,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.home_rounded,
                                        size: 80)),
                                const SizedBox(height: 12),
                                Text('QUỸ NHÀ MÌNH',
                                    style: Theme.of(c)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                const Text('Thu chi rõ ràng – Gia đình an tâm'),
                                const SizedBox(height: 20),
                                if (register)
                                  TextField(
                                      controller: name,
                                      decoration: const InputDecoration(
                                          labelText: 'Họ tên',
                                          prefixIcon: Icon(Icons.person))),
                                TextField(
                                    controller: email,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                        labelText: 'Email',
                                        prefixIcon: Icon(Icons.email))),
                                TextField(
                                    controller: pass,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Mật khẩu',
                                        prefixIcon: Icon(Icons.lock))),
                                if (error != null)
                                  Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Text(error!,
                                          style: const TextStyle(
                                              color: Colors.red))),
                                SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                        onPressed: busy ? null : go,
                                        child: Text(busy
                                            ? 'Đang xử lý...'
                                            : register
                                                ? 'Tạo tài khoản'
                                                : 'Đăng nhập'))),
                                TextButton(
                                    onPressed: () =>
                                        setState(() => register = !register),
                                    child: Text(register
                                        ? 'Đã có tài khoản? Đăng nhập'
                                        : 'Chưa có tài khoản? Đăng ký'))
                              ]))))))));
}

class FamilyGate extends StatefulWidget {
  const FamilyGate({super.key});
  State<FamilyGate> createState() => _FamilyGate();
}

class _FamilyGate extends State<FamilyGate> {
  bool busy = true;
  bool actionBusy = false;
  String? error;
  List f = [];
  final ctl = TextEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future load() async {
    f = await Api.families();
    setState(() => busy = false);
  }

  Future create() async {
    setState(() {
      actionBusy = true;
      error = null;
    });
    try {
      await Api.createFamily(ctl.text.isEmpty ? 'Gia đình của tôi' : ctl.text);
      await load();
    } catch (_) {
      setState(() => error = 'Không thể tạo quỹ. Vui lòng đăng nhập lại.');
    } finally {
      if (mounted) setState(() => actionBusy = false);
    }
  }

  Future join() async {
    setState(() {
      actionBusy = true;
      error = null;
    });
    try {
      await Api.joinFamily(ctl.text);
      await load();
    } catch (_) {
      setState(() => error = 'Mã mời không hợp lệ hoặc phiên đã hết hạn.');
    } finally {
      if (mounted) setState(() => actionBusy = false);
    }
  }

  @override
  Widget build(c) {
    if (busy)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (f.isNotEmpty) return Home(family: f.first);
    return Scaffold(
        appBar: AppBar(title: const Text('Bắt đầu')),
        body: Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.groups_rounded,
                  size: 90, color: Color(0xff1769e0)),
              const Text('Tạo quỹ mới hoặc nhập mã mời'),
              TextField(
                  controller: ctl,
                  decoration:
                      const InputDecoration(labelText: 'Tên quỹ / mã mời')),
              const SizedBox(height: 16),
              if (actionBusy) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child:
                      Text(error!, style: const TextStyle(color: Colors.red)),
                ),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      onPressed: actionBusy ? null : create,
                      icon: const Icon(Icons.add_home),
                      label: const Text('Tạo Quỹ Nhà Mình'))),
              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                      onPressed: actionBusy ? null : join,
                      icon: const Icon(Icons.group_add),
                      label: const Text('Tham gia bằng mã')))
            ])));
  }
}

class Home extends StatefulWidget {
  final dynamic family;
  const Home({super.key, required this.family});
  State<Home> createState() => _Home();
}

class _Home extends State<Home> {
  int tab = 0;
  int refresh = 0;
  @override
  Widget build(c) {
    final pages = [
      Dashboard(family: widget.family, key: ValueKey(refresh)),
      Transactions(family: widget.family, key: ValueKey('t$refresh')),
      AddTransaction(
          family: widget.family,
          onSaved: () {
            setState(() {
              refresh++;
              tab = 0;
            });
          }),
      ScanReceipt(
          family: widget.family,
          onSaved: () {
            setState(() {
              refresh++;
              tab = 0;
            });
          }),
      Settings(family: widget.family)
    ];
    return Scaffold(
        body: pages[tab],
        bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (x) => setState(() => tab = x),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.dashboard), label: 'Tổng quan'),
              NavigationDestination(
                  icon: Icon(Icons.receipt_long), label: 'Giao dịch'),
              NavigationDestination(
                  icon: Icon(Icons.add_circle), label: 'Thêm'),
              NavigationDestination(
                  icon: Icon(Icons.document_scanner), label: 'Quét'),
              NavigationDestination(
                  icon: Icon(Icons.settings), label: 'Cài đặt')
            ]));
  }
}

String money(num x) =>
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
        .format(x);

class Dashboard extends StatelessWidget {
  final dynamic family;
  const Dashboard({super.key, required this.family});
  @override
  Widget build(c) => FutureBuilder(
      future: Future.wait([
        Api.summary(family['familyId']),
        Api.transactions(family['familyId'])
      ]),
      builder: (c, s) {
        if (!s.hasData)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        final sum = s.data![0] as Map<String, dynamic>;
        final tx = s.data![1] as List<MoneyTransaction>;
        Widget card(String t, num v, IconData i) => Expanded(
            child: Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(i),
                          const SizedBox(height: 10),
                          Text(t),
                          FittedBox(
                              child: Text(money(v),
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)))
                        ]))));
        return Scaffold(
            appBar: AppBar(
                title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Quỹ Nhà Mình',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(family['name'], style: const TextStyle(fontSize: 13))
                ])),
            body: RefreshIndicator(
                onRefresh: () async {},
                child: ListView(padding: const EdgeInsets.all(12), children: [
                  Row(children: [
                    card('Tổng thu', sum['income'], Icons.trending_up),
                    card('Tổng chi', sum['expense'], Icons.trending_down)
                  ]),
                  Card(
                      child: ListTile(
                          leading: const CircleAvatar(
                              child: Icon(Icons.account_balance_wallet)),
                          title: const Text('Số dư tháng này'),
                          subtitle: Text(money(sum['balance']),
                              style: const TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.bold)))),
                  const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Giao dịch gần đây',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold))),
                  ...tx.take(8).map((x) => TxTile(x))
                ])));
      });
}

class Transactions extends StatelessWidget {
  final dynamic family;
  const Transactions({super.key, required this.family});
  @override
  Widget build(c) => Scaffold(
      appBar: AppBar(title: const Text('Lịch sử giao dịch')),
      body: FutureBuilder<List<MoneyTransaction>>(
          future: Api.transactions(family['familyId']),
          builder: (c, s) => !s.hasData
              ? const Center(child: CircularProgressIndicator())
              : ListView(children: s.data!.map((x) => TxTile(x)).toList())));
}

class TxTile extends StatelessWidget {
  final MoneyTransaction x;
  const TxTile(this.x, {super.key});
  @override
  Widget build(c) => Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: ListTile(
          leading: CircleAvatar(
              child: Icon(
                  x.type == 'income' ? Icons.south_west : Icons.north_east)),
          title: Text(x.category),
          subtitle: Text(
              '${DateFormat('dd/MM/yyyy').format(x.date)}${x.note.isEmpty ? '' : ' • ${x.note}'}'),
          trailing: Text('${x.type == 'income' ? '+' : '-'}${money(x.amount)}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: x.type == 'income' ? Colors.green : Colors.red))));
}

class AddTransaction extends StatefulWidget {
  final dynamic family;
  final VoidCallback onSaved;
  const AddTransaction(
      {super.key, required this.family, required this.onSaved});
  State<AddTransaction> createState() => _Add();
}

class _Add extends State<AddTransaction> {
  String type = 'expense', cat = '';
  List<String> cats = [];
  final amount = TextEditingController(),
      note = TextEditingController(),
      merchant = TextEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future load() async {
    cats = await Api.categories(type);
    setState(() => cat = cats.first);
  }

  Future save() async {
    await Api.add({
      'familyId': widget.family['familyId'],
      'type': type,
      'category': cat,
      'amount': double.parse(amount.text.replaceAll(',', '.')),
      'date': DateTime.now().toIso8601String(),
      'note': note.text,
      'merchant': merchant.text
    });
    widget.onSaved();
  }

  @override
  Widget build(c) => Scaffold(
      appBar: AppBar(title: const Text('Thêm giao dịch')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'expense',
                  label: Text('Phiếu chi'),
                  icon: Icon(Icons.remove)),
              ButtonSegment(
                  value: 'income',
                  label: Text('Phiếu thu'),
                  icon: Icon(Icons.add))
            ],
            selected: {
              type
            },
            onSelectionChanged: (x) {
              type = x.first;
              load();
            }),
        TextField(
            controller: amount,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            decoration:
                const InputDecoration(labelText: 'Số tiền', suffixText: '₫')),
        DropdownButtonFormField(
            value: cat,
            items: cats
                .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                .toList(),
            onChanged: (x) => setState(() => cat = x!),
            decoration: const InputDecoration(labelText: 'Danh mục')),
        TextField(
            controller: merchant,
            decoration: const InputDecoration(labelText: 'Nơi giao dịch')),
        TextField(
            controller: note,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Ghi chú')),
        const SizedBox(height: 20),
        FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save),
            label: const Text('Lưu giao dịch'))
      ]));
}

class ScanReceipt extends StatefulWidget {
  final dynamic family;
  final VoidCallback onSaved;
  const ScanReceipt({super.key, required this.family, required this.onSaved});
  State<ScanReceipt> createState() => _Scan();
}

class _Scan extends State<ScanReceipt> {
  bool busy = false;
  Map<String, dynamic>? data;
  String? image;
  Future pick(ImageSource src) async {
    final x = await ImagePicker()
        .pickImage(source: src, imageQuality: 75, maxWidth: 1800);
    if (x == null) return;
    final b = await File(x.path).readAsBytes();
    image = 'data:image/jpeg;base64,${base64Encode(b)}';
    setState(() => busy = true);
    try {
      data = await Api.scan(image!);
    } finally {
      setState(() => busy = false);
    }
  }

  Future save() async {
    final d = data!;
    await Api.add({
      'familyId': widget.family['familyId'],
      'type': d['type'],
      'category': d['category'],
      'amount': d['amount'],
      'date': d['date'] ?? DateTime.now().toIso8601String(),
      'note': d['note'],
      'merchant': d['merchant'],
      'receiptImageBase64': image
    });
    widget.onSaved();
  }

  @override
  Widget build(c) => Scaffold(
      appBar: AppBar(title: const Text('Quét hóa đơn AI')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Icon(Icons.document_scanner, size: 90, color: Color(0xff1769e0)),
        const Text(
            'Chụp hoặc chọn hóa đơn. AI sẽ đề xuất phiếu thu/chi để bạn kiểm tra.',
            textAlign: TextAlign.center),
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
                  icon: const Icon(Icons.photo),
                  label: const Text('Thư viện')))
        ]),
        if (busy)
          const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator())),
        if (data != null)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            data!['type'] == 'income'
                                ? 'PHIẾU THU'
                                : 'PHIẾU CHI',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 20)),
                        Text(money(data!['amount']),
                            style: const TextStyle(
                                fontSize: 30, fontWeight: FontWeight.bold)),
                        Text('Danh mục: ${data!['category']}'),
                        Text('Nơi giao dịch: ${data!['merchant'] ?? ''}'),
                        Text('Ngày: ${data!['date'] ?? ''}'),
                        Text('Ghi chú: ${data!['note']}'),
                        const SizedBox(height: 12),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                                onPressed: save,
                                icon: const Icon(Icons.save),
                                label: const Text('Xác nhận và lưu')))
                      ])))
      ]));
}

class Settings extends StatefulWidget {
  final dynamic family;
  const Settings({super.key, required this.family});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final inviteCode = TextEditingController();
  bool joining = false;
  String? message;
  bool success = false;

  Future<void> joinFamily() async {
    final code = inviteCode.text.trim();
    if (code.isEmpty) {
      setState(() {
        success = false;
        message = 'Vui lòng nhập mã mời.';
      });
      return;
    }
    setState(() {
      joining = true;
      message = null;
    });
    try {
      final joined = await Api.joinFamily(code);
      if (!mounted) return;
      setState(() {
        success = true;
        message = 'Đã tham gia quỹ ${joined['name']} thành công.';
        inviteCode.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        success = false;
        message = 'Mã mời không đúng hoặc bạn đã hết phiên đăng nhập.';
      });
    } finally {
      if (mounted) setState(() => joining = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
            child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.home)),
                title: Text(widget.family['name']),
                subtitle:
                    Text('Mã mời của quỹ: ${widget.family['inviteCode']}'),
                trailing: IconButton(
                    tooltip: 'Sao chép mã mời',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Hãy chia sẻ mã mời này cho thành viên gia đình.')));
                    },
                    icon: const Icon(Icons.share)))),
        const SizedBox(height: 12),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tham gia quỹ khác',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text(
                          'Nhập mã mời gồm 6 số do quản trị viên quỹ cung cấp.'),
                      const SizedBox(height: 12),
                      TextField(
                          controller: inviteCode,
                          enabled: !joining,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                              labelText: 'Mã mời',
                              hintText: 'Ví dụ: 123456',
                              prefixIcon: Icon(Icons.group_add),
                              border: OutlineInputBorder())),
                      if (joining) const LinearProgressIndicator(),
                      if (message != null)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(message!,
                                style: TextStyle(
                                    color:
                                        success ? Colors.green : Colors.red))),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                              onPressed: joining ? null : joinFamily,
                              icon: const Icon(Icons.login),
                              label: const Text('Tham gia bằng mã mời')))
                    ]))),
        const SizedBox(height: 12),
        Card(
            child: ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: const Text('AI quét hóa đơn'),
                subtitle: const Text('Google Gemini'))),
        Card(
            child: ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Đăng xuất'),
                onTap: () async {
                  await Api.clear();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const Gate()),
                        (_) => false);
                  }
                }))
      ]));
}
