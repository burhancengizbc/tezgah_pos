import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Tezgah ana uygulamasinin yerel ag (LAN) sunucusu.
/// Ayni WiFi/yerel agdaki companion uygulamalar (Cagri, Kurye) buna baglanir.
/// BULUT DEGIL - yalnizca yerel ag. Basit token ile korunur.
///
/// Uclar:
///   GET  /ping                 -> saglik / kesif
///   POST /callerid {number}    -> Cagri uygulamasindan gelen arama
///   POST /platform/order {...} -> platform siparisi alimi (Faz 11)
///   GET  /ws                   -> WebSocket (kurye vb. canli olaylar - Faz 10)
class LanServerService {
  HttpServer? _server;
  final Set<WebSocketChannel> _clients = {};

  bool get isRunning => _server != null;

  /// Olay yayini (kurye uygulamalarina). JSON string gonderilir.
  void broadcast(Map<String, dynamic> event) {
    final msg = jsonEncode(event);
    for (final c in _clients.toList()) {
      try {
        c.sink.add(msg);
      } catch (_) {}
    }
  }

  Future<void> start({
    required int port,
    required String token,
    required Future<void> Function(String number) onCallerId,
    Future<Map<String, dynamic>> Function(Map<String, dynamic> body)?
        onPlatformOrder,
    Future<Map<String, dynamic>> Function()? onCourierInfo,
    Future<Map<String, dynamic>> Function(String code)? onCourierJobs,
    Future<Map<String, dynamic>> Function(
            String code, int deliveryId, String status)?
        onCourierStatus,
    void Function(Map<String, dynamic> msg)? onClientMessage,
  }) async {
    await stop();

    bool authed(Request req) {
      final t = req.headers['x-tezgah-token'];
      return token.isEmpty || t == token;
    }

    Response json(Object data, {int status = 200}) => Response(
          status,
          body: jsonEncode(data),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );

    final router = Router();

    router.get('/ping', (Request req) {
      return json({'app': 'tezgah_pos', 'role': 'tezgah', 'ok': true});
    });

    router.post('/callerid', (Request req) async {
      if (!authed(req)) return json({'error': 'unauthorized'}, status: 401);
      try {
        final data = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
        final number = (data['number'] ?? '').toString().trim();
        if (number.isEmpty) return json({'error': 'number required'}, status: 400);
        await onCallerId(number);
        return json({'ok': true});
      } catch (e) {
        return json({'error': '$e'}, status: 400);
      }
    });

    router.post('/platform/order', (Request req) async {
      if (!authed(req)) return json({'error': 'unauthorized'}, status: 401);
      if (onPlatformOrder == null) {
        return json({'error': 'platform module disabled'}, status: 503);
      }
      try {
        final data = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
        final result = await onPlatformOrder(data);
        return json(result);
      } catch (e) {
        return json({'error': '$e'}, status: 400);
      }
    });

    // --- Kurye uclari ---
    router.get('/courier/info', (Request req) async {
      if (!authed(req)) return json({'error': 'unauthorized'}, status: 401);
      if (onCourierInfo == null) {
        return json({'error': 'courier module disabled'}, status: 503);
      }
      return json(await onCourierInfo());
    });

    router.get('/courier/jobs', (Request req) async {
      if (!authed(req)) return json({'error': 'unauthorized'}, status: 401);
      if (onCourierJobs == null) {
        return json({'error': 'courier module disabled'}, status: 503);
      }
      final code = (req.url.queryParameters['code'] ?? '').trim();
      if (code.isEmpty) return json({'error': 'code required'}, status: 400);
      return json(await onCourierJobs(code));
    });

    router.post('/courier/status', (Request req) async {
      if (!authed(req)) return json({'error': 'unauthorized'}, status: 401);
      if (onCourierStatus == null) {
        return json({'error': 'courier module disabled'}, status: 503);
      }
      try {
        final data = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
        final code = (data['code'] ?? '').toString().trim();
        final deliveryId = (data['deliveryId'] as num?)?.toInt() ?? 0;
        final status = (data['status'] ?? '').toString();
        if (code.isEmpty || deliveryId == 0) {
          return json({'error': 'code & deliveryId required'}, status: 400);
        }
        return json(await onCourierStatus(code, deliveryId, status));
      } catch (e) {
        return json({'error': '$e'}, status: 400);
      }
    });

    // WebSocket: companion'lar (kurye) baglanir; sunucu olay yayinlar.
    final wsHandler = webSocketHandler((WebSocketChannel socket, String? protocol) {
      _clients.add(socket);
      socket.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            onClientMessage?.call(msg);
          } catch (_) {}
        },
        onDone: () => _clients.remove(socket),
        onError: (_) => _clients.remove(socket),
        cancelOnError: true,
      );
    });

    final cascade = Cascade()
        .add((Request req) {
          // /ws yolunu WebSocket handler'a yonlendir.
          if (req.url.path == 'ws') return wsHandler(req);
          return Response.notFound('not_ws');
        })
        .add(router.call);

    final handler = Pipeline()
        .addMiddleware(_corsHeaders())
        .addHandler(cascade.handler);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    _server!.autoCompress = true;
  }

  Future<void> stop() async {
    for (final c in _clients.toList()) {
      try {
        await c.sink.close();
      } catch (_) {}
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }

  Middleware _corsHeaders() {
    return (Handler inner) {
      return (Request req) async {
        if (req.method == 'OPTIONS') {
          return Response.ok('', headers: _cors);
        }
        final res = await inner(req);
        return res.change(headers: {...res.headers, ..._cors});
      };
    };
  }

  static const _cors = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, x-tezgah-token',
  };
}
