import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// "Tezgah Kurye" companion uygulamasi.
/// Tezgah ana uygulamaya (yerel ag) baglanir, kuryeye atanan teslimatlari gosterir.
class KuryeApp extends StatelessWidget {
  const KuryeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tezgah Kurye',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFFFB300),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const _KuryeHome(),
    );
  }
}

class _KuryeHome extends StatefulWidget {
  const _KuryeHome();
  @override
  State<_KuryeHome> createState() => _KuryeHomeState();
}

class _KuryeHomeState extends State<_KuryeHome> {
  final _ip = TextEditingController();
  final _port = TextEditingController(text: '8787');
  final _token = TextEditingController();
  final _code = TextEditingController();

  bool _connected = false;
  bool _setupOpen = true;
  String _courierName = '';
  int _totalDeliveries = 0;
  String _businessName = '';
  String _businessAddress = '';
  String _businessPhone = '';
  List<Map<String, dynamic>> _jobs = [];
  String _status = '';

  Timer? _poll;
  WebSocketChannel? _ws;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _ws?.sink.close();
    _ip.dispose();
    _port.dispose();
    _token.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _ip.text = p.getString('kurye_ip') ?? '';
    _port.text = p.getString('kurye_port') ?? '8787';
    _token.text = p.getString('kurye_token') ?? '';
    _code.text = p.getString('kurye_code') ?? '';
    setState(() => _setupOpen = _ip.text.isEmpty || _code.text.isEmpty);
    if (!_setupOpen) _connect();
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('kurye_ip', _ip.text.trim());
    await p.setString('kurye_port', _port.text.trim());
    await p.setString('kurye_token', _token.text.trim());
    await p.setString('kurye_code', _code.text.trim().toUpperCase());
  }

  String get _base => 'http://${_ip.text.trim()}:${_port.text.trim()}';
  Map<String, String> get _headers =>
      {'content-type': 'application/json', 'x-tezgah-token': _token.text.trim()};

  Future<void> _connect() async {
    await _savePrefs();
    await _fetchInfo();
    await _refresh();
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 12), (_) => _refresh());
    _openWs();
  }

  void _openWs() {
    try {
      _ws?.sink.close();
      _ws = WebSocketChannel.connect(
          Uri.parse('ws://${_ip.text.trim()}:${_port.text.trim()}/ws'));
      _ws!.stream.listen(
        (_) => _refresh(),
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {/* poll yedek */}
  }

  Future<void> _fetchInfo() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/courier/info'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final b = (data['business'] as Map?)?.cast<String, dynamic>() ?? {};
      setState(() {
        _businessName = (b['name'] ?? '').toString();
        _businessAddress = (b['address'] ?? '').toString();
        _businessPhone = (b['phone'] ?? '').toString();
      });
    } catch (_) {}
  }

  Future<void> _refresh() async {
    try {
      final res = await http
          .get(
            Uri.parse(
                '$_base/courier/jobs?code=${Uri.encodeQueryComponent(_code.text.trim())}'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] == true) {
        final courier = (data['courier'] as Map?)?.cast<String, dynamic>() ?? {};
        setState(() {
          _connected = true;
          _setupOpen = false;
          _courierName = (courier['name'] ?? '').toString();
          _totalDeliveries = (courier['totalDeliveries'] as num?)?.toInt() ?? 0;
          _jobs = ((data['jobs'] as List?) ?? const [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList();
          _status = '';
        });
      } else {
        setState(() {
          _connected = false;
          _status = (data['error'] ?? 'Baglanti hatasi').toString();
        });
      }
    } catch (e) {
      setState(() {
        _connected = false;
        _status = 'Baglanti yok';
      });
    }
  }

  Future<void> _setStatus(int deliveryId, String status) async {
    try {
      await http
          .post(Uri.parse('$_base/courier/status'),
              headers: _headers,
              body: jsonEncode({
                'code': _code.text.trim(),
                'deliveryId': deliveryId,
                'status': status,
              }))
          .timeout(const Duration(seconds: 6));
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _openMaps(String address) async {
    if (address.trim().isEmpty) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _call(String phone) async {
    if (phone.trim().isEmpty) return;
    await launchUrl(Uri.parse('tel:$phone'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_connected ? 'Kurye • $_courierName' : 'Tezgah Kurye'),
        actions: [
          if (!_setupOpen)
            IconButton(
                icon: const Icon(Icons.refresh_rounded), onPressed: _refresh),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => setState(() => _setupOpen = !_setupOpen),
          ),
        ],
      ),
      body: _setupOpen ? _setup() : _jobsView(),
    );
  }

  Widget _setup() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Tezgah baglanti bilgileri',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextField(
            controller: _ip,
            decoration: const InputDecoration(
                labelText: 'Tezgah IP', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(
            controller: _port,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Port', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(
            controller: _token,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
                labelText: 'Eslesme kodu (sunucu)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
                labelText: 'Kurye kodu', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _connect,
          icon: const Icon(Icons.link_rounded),
          label: const Text('Baglan'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_status, style: const TextStyle(color: Colors.redAccent)),
        ],
      ],
    );
  }

  Widget _jobsView() {
    return Column(
      children: [
        Material(
          color: const Color(0xFF2A2A2E),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_businessName.isEmpty ? 'Restoran' : _businessName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('Toplam teslimat: $_totalDeliveries',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openMaps(_businessAddress),
                  icon: const Icon(Icons.storefront_rounded, size: 18),
                  label: const Text('Restorana Git'),
                ),
              ],
            ),
          ),
        ),
        if (!_connected)
          Container(
            width: double.infinity,
            color: Colors.red.withValues(alpha: 0.15),
            padding: const EdgeInsets.all(8),
            child: Text(_status.isEmpty ? 'Baglanti yok' : _status,
                textAlign: TextAlign.center),
          ),
        Expanded(
          child: _jobs.isEmpty
              ? const Center(child: Text('Aktif teslimat yok.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _jobs.length,
                  itemBuilder: (_, i) => _jobCard(_jobs[i]),
                ),
        ),
      ],
    );
  }

  Widget _jobCard(Map<String, dynamic> j) {
    final id = (j['id'] as num).toInt();
    final status = (j['status'] ?? '').toString();
    final total = (j['totalKurus'] as num?)?.toInt() ?? 0;
    final tl = (total / 100).toStringAsFixed(2).replaceAll('.', ',');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (j['customerName'] ?? '').toString().isEmpty
                        ? '(isimsiz)'
                        : j['customerName'].toString(),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Text('Fis #${j['receiptNo']}',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            if ((j['address'] ?? '').toString().isNotEmpty)
              Text(j['address'].toString()),
            if ((j['note'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Not: ${j['note']}',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$tl TL',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Color(0xFFFFB300))),
                Text(status, style: const TextStyle(fontSize: 12)),
              ],
            ),
            const Divider(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _call((j['phone'] ?? '').toString()),
                  icon: const Icon(Icons.phone_rounded, size: 18),
                  label: const Text('Ara'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openMaps((j['address'] ?? '').toString()),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('Adrese Git'),
                ),
                if (status != 'onTheWay')
                  FilledButton.icon(
                    onPressed: () => _setStatus(id, 'onTheWay'),
                    icon: const Icon(Icons.directions_run_rounded, size: 18),
                    label: const Text('Yola Ciktim'),
                  ),
                FilledButton.icon(
                  onPressed: () => _setStatus(id, 'delivered'),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Teslim Ettim'),
                  style:
                      FilledButton.styleFrom(backgroundColor: Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
