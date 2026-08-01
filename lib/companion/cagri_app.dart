import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/caller_id_service.dart';

/// "Tezgah Cagri" companion uygulamasi.
/// Telefona gelen aramayi yakalar (Android) ve ayni yerel agdaki Tezgah ana
/// uygulamasina iletir. Baska hicbir sey yapmaz (tek isi budur).
class CagriApp extends StatelessWidget {
  const CagriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tezgah Cagri',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFFFB300),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const _CagriHome(),
    );
  }
}

class _CagriHome extends StatefulWidget {
  const _CagriHome();
  @override
  State<_CagriHome> createState() => _CagriHomeState();
}

class _CagriHomeState extends State<_CagriHome> {
  final _service = CallerIdService();
  final _ip = TextEditingController();
  final _port = TextEditingController(text: '8787');
  final _token = TextEditingController();

  bool _listening = false;
  String _status = 'Hazir degil';
  String _lastNumber = '-';
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.stop();
    _ip.dispose();
    _port.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _ip.text = p.getString('cagri_ip') ?? '';
    _port.text = p.getString('cagri_port') ?? '8787';
    _token.text = p.getString('cagri_token') ?? '';
    setState(() {});
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('cagri_ip', _ip.text.trim());
    await p.setString('cagri_port', _port.text.trim());
    await p.setString('cagri_token', _token.text.trim());
  }

  String get _baseUrl => 'http://${_ip.text.trim()}:${_port.text.trim()}';

  void _addLog(String m) {
    final t = TimeOfDay.now();
    _log.insert(0,
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}  $m');
    if (_log.length > 30) _log.removeLast();
  }

  Future<void> _testConnection() async {
    await _savePrefs();
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/ping'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.body.contains('tezgah')) {
        setState(() {
          _status = 'Tezgah bulundu';
          _addLog('Baglanti basarili (/ping)');
        });
      } else {
        setState(() {
          _status = 'Yanit beklenmedik (${res.statusCode})';
          _addLog('Ping yaniti: ${res.statusCode}');
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Baglanti yok';
        _addLog('Ping hatasi: $e');
      });
    }
  }

  Future<bool> _send(String number) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/callerid'),
            headers: {
              'content-type': 'application/json',
              'x-tezgah-token': _token.text.trim(),
            },
            body: jsonEncode({'number': number}),
          )
          .timeout(const Duration(seconds: 5));
      final ok = res.statusCode == 200;
      setState(() {
        _lastNumber = number;
        _addLog(ok ? 'Gonderildi: $number' : 'Hata ${res.statusCode}: $number');
      });
      return ok;
    } catch (e) {
      setState(() => _addLog('Gonderim hatasi: $e'));
      return false;
    }
  }

  Future<void> _startListening() async {
    if (!_service.isSupported) {
      setState(() => _status = 'Bu cihaz desteklemiyor (yalnizca Android)');
      return;
    }
    final granted = await _service.requestPermission();
    if (!granted) {
      setState(() => _status = 'Telefon izni verilmedi');
      return;
    }
    await _savePrefs();
    await _service.start((number) => _send(number));
    setState(() {
      _listening = true;
      _status = 'Dinleniyor (gelen aramalar aktarilacak)';
      _addLog('Dinleme basladi');
    });
  }

  Future<void> _stopListening() async {
    await _service.stop();
    setState(() {
      _listening = false;
      _status = 'Durduruldu';
      _addLog('Dinleme durduruldu');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tezgah Cagri')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _listening
                            ? Icons.podcasts_rounded
                            : Icons.podcasts_outlined,
                        color: _listening ? const Color(0xFFFFB300) : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_status,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Son numara: $_lastNumber'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ip,
            decoration: const InputDecoration(
              labelText: 'Tezgah IP adresi',
              hintText: 'orn. 192.168.1.20',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _port,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Port', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
                labelText: 'Eslesme kodu', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testConnection,
                  icon: const Icon(Icons.wifi_find_rounded),
                  label: const Text('Baglantiyi Test Et'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _send('05551234567'),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Test Numara'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _listening ? _stopListening : _startListening,
            icon: Icon(_listening ? Icons.stop_rounded : Icons.play_arrow_rounded),
            label: Text(_listening ? 'Durdur' : 'Dinlemeyi Baslat'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 16),
          const Text('Kayit', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final l in _log)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(l, style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
