import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// import 'package:http_cookie_store/http_cookie_store.dart';

void main() {
  runApp(const ChargeApp());
}

class ChargeApp extends StatelessWidget {
  const ChargeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PAiEV CHARGE++ | Charging',
      debugShowCheckedModeBanner: true,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2563EB),
        scaffoldBackgroundColor: const Color(0xFFFAFCFF),
      ),
      home: const ChargeScreen(
        // If you route in with ?cp=xxx on web, you can pass it here instead.
        initialCpId: null,
      ),
    );
  }
}

/* =======================
   API CLIENT (cookies + headers)
   ======================= */

class ApiClient {
  ApiClient({required this.baseUri})
    : cookieJar = CookieJar(),
      client = http.Client();

  final Uri baseUri;
  final CookieJar cookieJar;
  final http.Client client;

  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    final uri = baseUri.replace(path: path);
    final cookieList = await cookieJar.loadForRequest(uri);
    final cookieHeader = cookieList
        .map((c) => '${c.name}=${c.value}')
        .join('; ');

    final res = await client.get(
      uri,
      headers: {
        ...?headers,
        if (cookieHeader.isNotEmpty) 'cookie': cookieHeader,
      },
    );
    print('✅ HTTP Response Received:');
    print('   ➡️ Status Code: ${res.statusCode}');
    print('   ➡️ Headers: ${res.headers}');

    // เก็บ Set-Cookie กลับเข้า jar
    final setCookie = res.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      await cookieJar.saveFromResponse(uri, _parseSetCookie(setCookie));
    }
    return res;
  }

  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
  }) async {
    final uri = baseUri.replace(path: path);

    final cookieList = await cookieJar.loadForRequest(uri);
    final cookieHeader = cookieList
        .map((c) => '${c.name}=${c.value}')
        .join('; ');

    final res = await client.post(
      uri,
      headers: {
        ...?headers,
        if (cookieHeader.isNotEmpty) 'cookie': cookieHeader,
      },
    );

    final setCookie = res.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      await cookieJar.saveFromResponse(uri, _parseSetCookie(setCookie));
    }

    return res;
  }

  void dispose() => client.close();
}

/// แปลง header "set-cookie" เป็น List<Cookie>
/// หมายเหตุ: backend ส่วนใหญ่ส่ง set-cookie มาทีละ 1 cookie ต่อ response header
/// ถ้าคุณส่งหลาย cookie ใน header เดียว อาจต้อง parser ที่ซับซ้อนขึ้น
List<Cookie> _parseSetCookie(String setCookieHeader) {
  // แบบพื้นฐาน: รับ 1 cookie
  // ตัวอย่าง: "sessionid=abc; Path=/; HttpOnly"
  final parts = setCookieHeader.split(';');
  final kv = parts.first.split('=');
  if (kv.length < 2) return [];
  final name = kv[0].trim();
  final value = kv.sublist(1).join('=').trim();
  return [Cookie(name, value)];
}

/* =======================
   MODELS
   ======================= */

class UserInfo {
  UserInfo({
    required this.fullName,
    required this.profileType,
    required this.email,
    required this.phone,
    required this.id,
  });

  final String fullName;
  final String profileType;
  final String? email;
  final String? phone;
  final String? id;

  String get initial => fullName.trim().isEmpty
      ? 'U'
      : fullName.trim().characters.first.toUpperCase();

  String get typeLabel {
    if (profileType == 'REVENUE') return 'ผู้ใช้ Revenue';
    return 'ผู้ใช้ Non-Revenue';
  }

  Color get typeBg {
    if (profileType == 'REVENUE') return const Color(0xFFECFDF3);
    return const Color(0xFFE6F4FF);
  }

  Color get typeFg {
    if (profileType == 'REVENUE') return const Color(0xFF16A34A);
    return const Color(0xFF1275D4);
  }

  static UserInfo fromJson(Map<String, dynamic> raw) {
    // Your JS: const user = data.user ? data.user : data
    final user = raw['user'] is Map<String, dynamic>
        ? raw['user'] as Map<String, dynamic>
        : raw;

    final profileType = (user['profile_type'] ?? 'FREE_NON_REVENUE').toString();
    final email = user['email']?.toString();
    final fullName =
        (user['full_name'] ??
                user['name'] ??
                user['username'] ??
                (email != null ? email.split('@').first : 'ผู้ใช้'))
            .toString();

    return UserInfo(
      fullName: fullName.isEmpty ? 'ผู้ใช้' : fullName,
      profileType: profileType,
      email: email,
      phone: (user['phone'] ?? user['mobile'])?.toString(),
      id: (user['id'] ?? user['user_id'])?.toString(),
    );
  }
}

class ConnectorStatus {
  ConnectorStatus({required this.status});
  final String? status;

  static ConnectorStatus fromJson(Map<String, dynamic> json) {
    // data.connectors.find(c => c.connector_id == 1)
    final connectors = (json['connectors'] as List?) ?? const [];
    Map<String, dynamic>? c1;
    for (final c in connectors) {
      if (c is Map && c['connector_id']?.toString() == '1') {
        c1 = c.cast<String, dynamic>();
        break;
      }
    }
    return ConnectorStatus(status: c1?['status']?.toString());
  }
}

class CurrentSessionKwh {
  CurrentSessionKwh({
    required this.active,
    required this.meterLatest,
    required this.power,
    required this.socPercent,
    required this.timestampStart,
  });

  final bool active;
  final double meterLatest;
  final double power;
  final double socPercent;
  final DateTime? timestampStart;

  static CurrentSessionKwh fromJson(Map<String, dynamic> json) {
    return CurrentSessionKwh(
      active: json['active'] == true,
      meterLatest: (json['meter_latest'] is num)
          ? (json['meter_latest'] as num).toDouble()
          : 0.0,
      power: (json['power'] is num) ? (json['power'] as num).toDouble() : 0.0,
      socPercent: (json['soc_percent'] is num)
          ? (json['soc_percent'] as num).toDouble()
          : 0.0,
      timestampStart: json['timestamp_start'] != null
          ? DateTime.tryParse(json['timestamp_start'].toString())
          : null,
    );
  }
}

class HistoryItem {
  HistoryItem({
    required this.cpId,
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.kwh,
    required this.duration,
  });

  final String cpId;
  final String status;
  final DateTime? startTime;
  final DateTime? endTime;
  final double kwh;
  final String duration;

  static HistoryItem fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      cpId: (json['cp_id'] ?? '-').toString(),
      status: (json['status'] ?? '-').toString(),
      startTime: json['start_time'] != null
          ? DateTime.tryParse(json['start_time'].toString())
          : null,
      endTime: json['end_time'] != null
          ? DateTime.tryParse(json['end_time'].toString())
          : null,
      kwh: (json['kwh'] is num) ? (json['kwh'] as num).toDouble() : 0.0,
      duration: (json['duration'] ?? '-').toString(),
    );
  }
}

class EnergyDay {
  EnergyDay({required this.dayLabel, required this.totalKwh});
  final String dayLabel; // e.g. "12-17"
  final double totalKwh;

  static List<EnergyDay> parseHistoryPerCp(Map<String, dynamic> json) {
    final data = (json['data'] as List?) ?? const [];
    return data.map((e) {
      final m = (e as Map).cast<String, dynamic>();
      final day = (m['day'] ?? m['date'] ?? '').toString();
      final label = day.length >= 10
          ? day.substring(5)
          : day; // like your JS MM-DD
      final v = (m['total_kwh'] is num)
          ? (m['total_kwh'] as num).toDouble()
          : 0.0;
      return EnergyDay(dayLabel: label, totalKwh: v);
    }).toList();
  }
}

/* =======================
   SCREEN
   ======================= */

enum AppTab { current, history, wallet }

class ChargeScreen extends StatefulWidget {
  const ChargeScreen({super.key, required this.initialCpId});
  final String? initialCpId;

  @override
  State<ChargeScreen> createState() => _ChargeScreenState();
}

class _ChargeScreenState extends State<ChargeScreen> {
  // NOTE: Set this to your backend origin.
  // - Android emulator: http://210.246.202.47:9000
  // - iOS sim: http://localhost:8000
  // - production: https://your-domain
  late final ApiClient api;

  AppTab tab = AppTab.current;

  String? cpId;
  String? idTag;

  UserInfo? user;

  bool isCharging = false;
  String? lastConnectorStatus;
  int historyPage = 1;
  static const int historyPageSize = 10;
  int historyTotal = 0;

  double walletBalance = 0.0;

  // UI values
  String statusLabel = 'พร้อมเริ่มชาร์จ';
  Color statusColor = const Color(0xFF222222);

  String connectorText = '• กรุณาดึงหัวชาร์จออก';
  Color connectorTextColor = const Color(0xFFB91C1C); // red-ish

  Duration elapsed = Duration.zero;
  Timer? connectorTimer;
  Timer? kwhTimer;

  double energyKwh = 0.0;
  double powerKw = 0.0;
  double socPercent = 0.0;

  // suspended logic (same intent as your JS)
  Timer? suspendedTimer;
  static const int suspendedTimeoutMs = 60 * 1000;
  static const int suspendedFullTimeoutMs = 2 * 60 * 1000;
  int? suspendedFromChargingStartEpochMs;

  @override
  void initState() {
    super.initState();
    api = ApiClient(
      baseUri: Uri.parse('http://210.246.202.47:9000'),
    ); // change me
    cpId = widget.initialCpId;
    _bootstrap();
  }

  @override
  void dispose() {
    connectorTimer?.cancel();
    kwhTimer?.cancel();
    suspendedTimer?.cancel();
    api.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadUserInfo();

    // If cpId not provided, try my_active_session (like your JS)
    if (cpId == null) {
      await _loadActiveSessionCp();
    }

    if (mounted) setState(() {});
    _startPolling();
  }

  Future<void> _loadUserInfo() async {
    try {
      final res = await api.get('/api/auth/me');
      log('API GET /api/auth/me => $res');
      if (res.statusCode == 401 || res.statusCode == 403) {
        // In Flutter you'd navigate to login screen; placeholder:
        return;
      }
      if (res.statusCode < 200 || res.statusCode >= 300) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      user = UserInfo.fromJson(data);
      setState(() {});
    } catch (_) {}
  }

  Future<void> _loadActiveSessionCp() async {
    try {
      final res = await api.get('/api/charging/my_active_session');
      if (res.statusCode < 200 || res.statusCode >= 300) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['active'] == true && data['cp_id'] != null) {
        cpId = data['cp_id'].toString();
      }
    } catch (_) {}
  }

  void _startPolling() {
    connectorTimer?.cancel();
    kwhTimer?.cancel();

    _updateConnectorStatus();
    connectorTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _updateConnectorStatus(),
    );

    _updateKwh();
    kwhTimer = Timer.periodic(const Duration(seconds: 3), (_) => _updateKwh());
  }

  /* =======================
     BUSINESS LOGIC (match your JS)
     ======================= */

  void _setStatusLabel(String text, Color color) {
    setState(() {
      statusLabel = text;
      statusColor = color;
    });
  }

  Future<void> _updateConnectorStatus() async {
    if (cpId == null) return;

    try {
      final res = await api.get(
        '/api/charging/connector/status?cp_id=${Uri.encodeComponent(cpId!)}',
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final connector = ConnectorStatus.fromJson(data);
      final rawStatus = connector.status;
      final prevStatus = lastConnectorStatus;
      lastConnectorStatus = rawStatus;

      // ignore: unused_local_variable
      bool animating = false;
      // ignore: unused_local_variable
      bool blinking = false;

      if (!isCharging) {
        if (rawStatus == 'Preparing') {
          if (prevStatus == 'Available' ||
              prevStatus == 'Finishing' ||
              prevStatus == null) {
            energyKwh = 0;
            powerKw = 0;
            elapsed = Duration.zero;
            socPercent = 0;
          }
          _setStatusLabel('พร้อมเริ่มชาร์จ', const Color(0xFF19B44A));
          _setConnectorText('หัวชาร์จเสียบอยู่', const Color(0xFFB91C1C));
        } else if (rawStatus == 'Available') {
          _setStatusLabel('ไม่พร้อมชาร์จ', const Color(0xFFD1D5DB));
          _setConnectorText('กรุณาเสียบหัวชาร์จ', const Color(0xFFB91C1C));
        } else if (rawStatus == 'Finishing') {
          _setStatusLabel('ชาร์จเสร็จแล้ว', const Color(0xFFEAB308));
          _setConnectorText('กรุณาดึงหัวชาร์จออก', const Color(0xFFB91C1C));
        } else if (rawStatus == 'SuspendedEV') {
          _setStatusLabel('หยุดชั่วคราวจากรถ', const Color(0xFFEAB308));
          _setConnectorText('รถหยุดดึงไฟชั่วคราว', const Color(0xFFB91C1C));
        } else {
          _setStatusLabel('ไม่พร้อมชาร์จ', const Color(0xFFD1D5DB));
          _setConnectorText('ไม่พร้อมชาร์จ', const Color(0xFFB91C1C));
        }

        suspendedFromChargingStartEpochMs = null;
        suspendedTimer?.cancel();
        suspendedTimer = null;
      } else {
        if (rawStatus == 'Charging') {
          _setStatusLabel('กำลังชาร์จ', const Color(0xFF19B44A));
          _setConnectorText('กำลังชาร์จ', const Color(0xFFB91C1C));
          animating = true;
          blinking = true;
          suspendedFromChargingStartEpochMs = null;
        } else if (rawStatus == 'Preparing') {
          _setStatusLabel('กำลังชาร์จ', const Color(0xFF19B44A));
          _setConnectorText('หัวชาร์จเสียบอยู่', const Color(0xFFB91C1C));
          animating = true;
        } else if (rawStatus == 'Finishing') {
          _setStatusLabel('ชาร์จเสร็จแล้ว', const Color(0xFFEAB308));
          _setConnectorText('กรุณาดึงหัวชาร์จออก', const Color(0xFFB91C1C));

          suspendedTimer ??= Timer(
            const Duration(milliseconds: suspendedTimeoutMs),
            () async {
              _showFullAlert();
              await _stopCharging(isAuto: true);
              suspendedTimer = null;
            },
          );
        } else if (rawStatus == 'SuspendedEV') {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          if (prevStatus == 'Charging' &&
              suspendedFromChargingStartEpochMs == null) {
            suspendedFromChargingStartEpochMs = nowMs;
          } else if (suspendedFromChargingStartEpochMs != null &&
              (nowMs - suspendedFromChargingStartEpochMs!) >=
                  suspendedFullTimeoutMs) {
            suspendedFromChargingStartEpochMs = null;
            _showFullAlert();
            await _stopCharging(isAuto: true);
            return;
          }

          _setStatusLabel('หยุดชั่วคราวจากรถ', const Color(0xFFEAB308));
          _setConnectorText('รถหยุดดึงไฟชั่วคราว', const Color(0xFFB91C1C));
        } else {
          _setStatusLabel('ไม่พร้อมชาร์จ', const Color(0xFFD1D5DB));
          _setConnectorText('ไม่พร้อมชาร์จ', const Color(0xFFB91C1C));
        }
      }

      // animating/blinking can be used to drive animations; kept minimal here.
      // You can hook them into an AnimationController if desired.
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _setConnectorText(String text, Color color) {
    setState(() {
      connectorText = '• $text';
      connectorTextColor = color;
    });
  }

  Future<void> _updateKwh() async {
    if (cpId == null) return;

    try {
      final res = await api.get(
        '/api/charging/current_session_kwh?cp_id=${Uri.encodeComponent(cpId!)}',
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final session = CurrentSessionKwh.fromJson(data);

      if (!session.active) {
        setState(() => isCharging = false);
        return;
      }

      isCharging = true;
      energyKwh = session.meterLatest;
      powerKw = session.power;
      socPercent = session.socPercent.clamp(0, 100);

      if (session.timestampStart != null) {
        final diff = DateTime.now().difference(session.timestampStart!);
        elapsed = diff.isNegative ? Duration.zero : diff;
      }

      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _startCharging() async {
    if (cpId == null) return;

    try {
      // mimic your IDTAG random
      idTag = 'IDTAG-${DateTime.now().millisecondsSinceEpoch % 1000000}';

      _setStatusLabel('กำลังเริ่มชาร์จ...', const Color(0xFF222222));

      final res = await api.post(
        '/api/charging/start_charging?cp_id=${Uri.encodeComponent(cpId!)}&id_tag=${Uri.encodeComponent(idTag!)}',
        // headers: api.buildUserHeaders(user),
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        String msg = 'สั่งเริ่มชาร์จไม่สำเร็จ';
        try {
          final err = jsonDecode(res.body);
          if (err is Map && err['detail'] != null)
            msg = err['detail'].toString();
        } catch (_) {}
        _showSnack(msg);
        _setStatusLabel('ไม่สามารถเริ่มชาร์จได้', const Color(0xFFE11D48));
        setState(() => isCharging = false);
        return;
      }

      _setStatusLabel('กำลังชาร์จ', const Color(0xFF19B44A));
      setState(() => isCharging = true);
    } catch (_) {
      _showSnack('สั่งเริ่มชาร์จไม่สำเร็จ (connection error)');
      _setStatusLabel('พร้อมเริ่มชาร์จ', const Color(0xFF222222));
    }
  }

  Future<void> _stopCharging({required bool isAuto}) async {
    if (cpId == null) return;

    try {
      await api.post(
        '/api/charging/stop_charging?cp_id=${Uri.encodeComponent(cpId!)}',
      );
      setState(() {
        isCharging = false;
      });
      _setConnectorText('กรุณาดึงหัวชาร์จออก', const Color(0xFFB91C1C));
      _setStatusLabel(
        isAuto ? 'ชาร์จเต็มแล้ว' : 'หยุดชาร์จแล้ว',
        isAuto ? const Color(0xFF199550) : const Color(0xFF222222),
      );
    } catch (_) {
      _showSnack('หยุดการชาร์จไม่สำเร็จ');
    }
  }

  void _showFullAlert() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('แจ้งเตือน'),
        content: const Text('แบตเตอรี่ชาร์จเต็ม 100% กรุณาดึงหัวชาร์จออกจากรถ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60);
    final s = (d.inSeconds % 60);
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  bool get canStartCharging {
    // Your HTML enables start when connector status == Preparing
    return !isCharging && (lastConnectorStatus == 'Preparing');
  }

  /* =======================
     UI
     ======================= */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    _HeaderCard(user: user),
                    const SizedBox(height: 12),
                    _TabPills(
                      tab: tab,
                      onChange: (t) async {
                        setState(() => tab = t);
                        if (t == AppTab.history) {
                          historyPage = 1;
                          await _loadHistory();
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    if (tab == AppTab.current) _buildCurrentTab(),
                    if (tab == AppTab.history)
                      _HistoryTab(
                        cpId: cpId,
                        page: historyPage,
                        pageSize: historyPageSize,
                        total: historyTotal,
                        load: _loadHistory,
                        onPrev: () async {
                          if (historyPage <= 1) return;
                          setState(() => historyPage -= 1);
                          await _loadHistory();
                        },
                        onNext: () async {
                          final maxPage = (historyTotal / historyPageSize)
                              .ceil()
                              .clamp(1, 1 << 30);
                          if (historyPage >= maxPage) return;
                          setState(() => historyPage += 1);
                          await _loadHistory();
                        },
                        api: api,
                        user: user,
                        setTotal: (t) => setState(() => historyTotal = t),
                      ),
                    if (tab == AppTab.wallet)
                      _WalletTab(
                        walletBalance: walletBalance,
                        onMockTopup: (amount) {
                          if (amount <= 0) {
                            _showSnack(
                              'กรุณาระบุจำนวนเงินที่ต้องการเติม (mock)',
                            );
                            return;
                          }
                          _showSnack(
                            'นี่คือ mockup: ปกติจะเปิด QR Omise สำหรับ ${amount.toStringAsFixed(2)} บาท',
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Stack(
        children: [
          // Graph (bottom-left)
          Positioned(
            left: 18,
            bottom: 18,
            child: FloatingActionButton.small(
              heroTag: 'graph',
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                builder: (_) => _EnergyGraphSheet(api: api, cpId: cpId),
              ),
              backgroundColor: Colors.white,
              child: const Icon(Icons.bar_chart, color: Color(0xFF2563EB)),
            ),
          ),
          // Home (bottom-right) -> in Flutter, navigate back
          Positioned(
            right: 18,
            bottom: 18,
            child: FloatingActionButton.small(
              heroTag: 'home',
              onPressed: () {
                // Replace with Navigator push to login or pop to previous page
                Navigator.maybePop(context);
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.home, color: Color(0xFF2563EB)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    return Column(
      children: [
        const SizedBox(height: 6),
        _BatteryRing(
          socPercent: socPercent,
          statusLabel: statusLabel,
          statusColor: statusColor,
          blinking: isCharging,
        ),
        const SizedBox(height: 12),

        // Orange bar (cp name + connector status)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.09),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  cpId ?? '-',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                connectorText,
                style: TextStyle(
                  color: connectorTextColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),

        // White bar (timer)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.09),
                blurRadius: 22,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7FBEA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.access_time,
                  color: Color(0xFF19B44A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'ระยะเวลาการชาร์จ',
                style: TextStyle(
                  color: Color(0xFF202020),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _formatElapsed(elapsed),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Energy / Power cards
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Energy',
                value: '${energyKwh.toStringAsFixed(2)} kWh',
                icon: Icons.bolt,
                iconColor: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Power',
                value: '${powerKw.toStringAsFixed(2)} kW',
                icon: Icons.flash_on,
                iconColor: const Color(0xFF19B44A),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Start/Stop button
        SizedBox(
          width: 260,
          height: 52,
          child: ElevatedButton(
            onPressed: isCharging
                ? () => _stopCharging(isAuto: false)
                : (canStartCharging ? _startCharging : null),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCharging
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF93C5FD),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 6,
            ),
            child: Text(
              isCharging ? 'Stop Charging' : 'Start Charging',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ),

        const SizedBox(height: 90),
      ],
    );
  }

  Future<void> _loadHistory() async {
    // handled by _HistoryTab using api calls; this is just a trigger placeholder
    setState(() {});
  }
}

/* =======================
   WIDGETS
   ======================= */

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.user});
  final UserInfo? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Center(
            child: Image.asset(
              'assets/pai-logo.png',
              height: 88,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 88,
                child: Center(child: Text('assets/pai-logo.png')),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (user != null)
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0EA5E9), Color(0xFF06C5B8)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    user!.initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    user!.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'เครดิต 0.00 ฿',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: user!.typeBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    user!.typeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: user!.typeFg,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TabPills extends StatelessWidget {
  const _TabPills({required this.tab, required this.onChange});
  final AppTab tab;
  final void Function(AppTab) onChange;

  @override
  Widget build(BuildContext context) {
    Widget pill(String label, AppTab t) {
      final active = tab == t;
      return Expanded(
        child: InkWell(
          onTap: () => onChange(t),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: active
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          pill('การชาร์จปัจจุบัน', AppTab.current),
          pill('ประวัติของฉัน', AppTab.history),
          pill('กระเป๋าเงิน', AppTab.wallet),
        ],
      ),
    );
  }
}

class _BatteryRing extends StatelessWidget {
  const _BatteryRing({
    required this.socPercent,
    required this.statusLabel,
    required this.statusColor,
    required this.blinking,
  });

  final double socPercent;
  final String statusLabel;
  final Color statusColor;
  final bool blinking;

  @override
  Widget build(BuildContext context) {
    final p = (socPercent / 100).clamp(0.0, 1.0);

    return SizedBox(
      height: 220,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: CircularProgressIndicator(
                value: p,
                strokeWidth: 16,
                backgroundColor: const Color(0xFFE5E8EF),
                color: const Color(0xFF19B44A),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, size: 34, color: Color(0xFF19B44A)),
                const SizedBox(height: 6),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: blinking ? 1.0 : 1.0,
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'แบตเตอรี่',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/* =======================
   HISTORY TAB (API wired)
   ======================= */

class _HistoryTab extends StatefulWidget {
  const _HistoryTab({
    required this.api,
    required this.user,
    required this.cpId,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.load,
    required this.onPrev,
    required this.onNext,
    required this.setTotal,
  });

  final ApiClient api;
  final UserInfo? user;
  final String? cpId;

  final int page;
  final int pageSize;
  final int total;

  final Future<void> Function() load;
  final Future<void> Function() onPrev;
  final Future<void> Function() onNext;
  final void Function(int) setTotal;

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  String scope = 'all';
  int days = 7;

  bool loading = true;
  String summary = 'กำลังโหลดประวัติ...';
  List<HistoryItem> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      summary = 'กำลังโหลดประวัติ...';
      items = [];
    });

    if (widget.user?.email == null || widget.user!.email!.isEmpty) {
      setState(() {
        loading = false;
        summary = 'ไม่พบข้อมูลผู้ใช้ (กรุณาเข้าสู่ระบบใหม่)';
      });
      return;
    }

    var url =
        '/api/charging/my_sessions?days=${Uri.encodeComponent(days.toString())}'
        '&page=${widget.page}&page_size=${widget.pageSize}';
    if (scope == 'current' && widget.cpId != null) {
      url += '&cp_id=${Uri.encodeComponent(widget.cpId!)}';
    }

    try {
      final res = await widget.api.get(
        url,
        // headers: widget.api.buildUserHeaders(widget.user),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        setState(() {
          loading = false;
          summary = 'ไม่สามารถโหลดประวัติได้';
        });
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final sessions = (data['sessions'] as List?) ?? const [];
      final total = (data['total'] is num) ? (data['total'] as num).toInt() : 0;
      widget.setTotal(total);

      final parsed = sessions
          .whereType<Map>()
          .map((e) => HistoryItem.fromJson(e.cast<String, dynamic>()))
          .toList();

      setState(() {
        loading = false;
        items = parsed;
        summary = parsed.isEmpty
            ? 'ยังไม่มีประวัติการชาร์จในช่วงเวลาที่เลือก'
            : 'พบ $total รายการ';
      });
    } catch (_) {
      setState(() {
        loading = false;
        summary = 'เกิดข้อผิดพลาดในการโหลดประวัติ';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxPage = (widget.total / widget.pageSize).ceil().clamp(1, 1 << 30);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ดูประวัติ',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: scope,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('ทุกตู้ PAiEV ของฉัน'),
                        ),
                        DropdownMenuItem(
                          value: 'current',
                          child: Text('เฉพาะตู้ปัจจุบัน'),
                        ),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() => scope = v);
                        await _load();
                      },
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ช่วงเวลา',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: days,
                      items: const [
                        DropdownMenuItem(value: 7, child: Text('7 วัน')),
                        DropdownMenuItem(value: 30, child: Text('30 วัน')),
                        DropdownMenuItem(value: 90, child: Text('90 วัน')),
                        DropdownMenuItem(value: 0, child: Text('ทั้งหมด')),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() => days = v);
                        await _load();
                      },
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 10),

          SizedBox(
            height: 280,
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final it = items[i];
                      final start = it.startTime?.toLocal().toString() ?? '-';
                      final end = it.endTime?.toLocal().toString() ?? '-';
                      final statusColor = it.status == 'completed'
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF6B7280);

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFF3F4F6)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    it.cpId,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  it.status,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    'เริ่ม: $start\nจบ: $end',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${it.kwh.toStringAsFixed(2)} kWh',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      it.duration,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: widget.page <= 1 ? null : widget.onPrev,
                child: const Text('ก่อนหน้า', style: TextStyle(fontSize: 12)),
              ),
              Text(
                'หน้า ${widget.page} / $maxPage',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              OutlinedButton(
                onPressed: widget.page >= maxPage ? null : widget.onNext,
                child: const Text('ถัดไป', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* =======================
   WALLET TAB (mock)
   ======================= */

class _WalletTab extends StatefulWidget {
  const _WalletTab({required this.walletBalance, required this.onMockTopup});
  final double walletBalance;
  final void Function(double amount) onMockTopup;

  @override
  State<_WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<_WalletTab> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void preset(double v) =>
      setState(() => controller.text = v.toStringAsFixed(0));

  @override
  Widget build(BuildContext context) {
    final formatted = '${widget.walletBalance.toStringAsFixed(2)} ฿';

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF4F46E5)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Wallet Balance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Mockup',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  formatted,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'เครดิตที่ใช้สำหรับชำระค่าชาร์จ PAiEV',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: const [
              Expanded(
                child: Text(
                  'เติมเงินเข้า Wallet',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                'ผ่าน QR ของ Omise (ยังเป็น Mockup)',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _AmountBtn(label: '100฿', onTap: () => preset(100)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AmountBtn(label: '200฿', onTap: () => preset(200)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AmountBtn(label: '300฿', onTap: () => preset(300)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AmountBtn(label: '500฿', onTap: () => preset(500)),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Text(
            'จำนวนอื่นๆ (บาท)',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'เช่น 150',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final v = double.tryParse(controller.text.trim()) ?? 0;
                widget.onMockTopup(v);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 6,
              ),
              child: const Text(
                'สร้าง QR เพื่อเติมเงิน (Mock)',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '* หน้านี้ยังเป็น mockup สำหรับออกแบบหน้าจอเท่านั้น ยังไม่เชื่อมต่อ Omise จริง',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _AmountBtn extends StatelessWidget {
  const _AmountBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF374151),
        ),
      ),
    );
  }
}

/* =======================
   GRAPH SHEET (history_per_cp)
   ======================= */

class _EnergyGraphSheet extends StatefulWidget {
  const _EnergyGraphSheet({required this.api, required this.cpId});
  final ApiClient api;
  final String? cpId;

  @override
  State<_EnergyGraphSheet> createState() => _EnergyGraphSheetState();
}

class _EnergyGraphSheetState extends State<_EnergyGraphSheet> {
  int rangeDays = 7;

  bool loading = true;
  List<EnergyDay> days = [];
  double lastMeter = 0;
  double totalMeter = 0;
  double? lastCost; // your HTML sets lastCost = lastMeter * 0 (currently 0)

  @override
  void initState() {
    super.initState();
    _load(rangeDays);
  }

  Future<void> _load(int r) async {
    setState(() {
      rangeDays = r;
      loading = true;
    });

    final cpId = widget.cpId;
    if (cpId == null || cpId.isEmpty) {
      setState(() {
        loading = false;
        days = [];
        lastMeter = 0;
        totalMeter = 0;
        lastCost = null;
      });
      return;
    }

    try {
      final res = await widget.api.get(
        '/api/charging/history_per_cp?cp_id=${Uri.encodeComponent(cpId)}&days=${Uri.encodeComponent(r.toString())}',
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final parsed = EnergyDay.parseHistoryPerCp(data);

        final vals = parsed.map((e) => e.totalKwh).toList();
        final lm = vals.isNotEmpty ? vals.last : 0.0;
        final tm = vals.fold<double>(0.0, (a, b) => a + b);

        setState(() {
          loading = false;
          days = parsed;
          lastMeter = lm;
          totalMeter = tm;
          lastCost =
              lm * 0; // match your current HTML (0). Change to rate if needed.
        });
      } else {
        setState(() {
          loading = false;
          days = List.generate(r, (i) => EnergyDay(dayLabel: '', totalKwh: 0));
          lastMeter = 0;
          totalMeter = 0;
          lastCost = null;
        });
      }
    } catch (_) {
      setState(() {
        loading = false;
        days = List.generate(r, (i) => EnergyDay(dayLabel: '', totalKwh: 0));
        lastMeter = 0;
        totalMeter = 0;
        lastCost = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxY = days.isEmpty
        ? 1.0
        : (days.map((e) => e.totalKwh).reduce((a, b) => a > b ? a : b) * 1.2)
              .clamp(1.0, 1e9);

    return Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total kWh (ย้อนหลัง)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _RangeBtn(
                active: rangeDays == 7,
                label: '7 วัน',
                onTap: () => _load(7),
              ),
              const SizedBox(width: 10),
              _RangeBtn(
                active: rangeDays == 30,
                label: '30 วัน',
                onTap: () => _load(30),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 240,
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : BarChart(
                    BarChartData(
                      maxY: maxY,
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: (v, meta) {
                              return Text(
                                v.toStringAsFixed(0),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF6B7280),
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: (days.length <= 7) ? 1 : 3,
                            getTitlesWidget: (v, meta) {
                              final idx = v.toInt();
                              if (idx < 0 || idx >= days.length)
                                return const SizedBox.shrink();
                              return Text(
                                days[idx].dayLabel,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF6B7280),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(days.length, (i) {
                        final y = days[i].totalKwh;
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: y,
                              width: 10,
                              borderRadius: BorderRadius.circular(6),
                              color: const Color(0xFF2563EB).withOpacity(0.7),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'ค่าไฟล่าสุด (บาท)',
                  value: lastCost == null
                      ? 'N/A'
                      : lastCost!.toStringAsFixed(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: 'Last Meter (kWh)',
                  value: lastMeter.toStringAsFixed(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: 'Total Meter (kWh)',
                  value: totalMeter.toStringAsFixed(2),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _RangeBtn extends StatelessWidget {
  const _RangeBtn({
    required this.active,
    required this.label,
    required this.onTap,
  });
  final bool active;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: active ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
        ),
        foregroundColor: active
            ? const Color(0xFF2563EB)
            : const Color(0xFF6B7280),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: active ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
