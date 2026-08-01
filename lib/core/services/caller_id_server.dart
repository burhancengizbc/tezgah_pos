import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/repository_providers.dart';
import '../../data/collections/people_collections.dart';

class IncomingCall {
  final String phone;
  final Customer? customer;
  IncomingCall({required this.phone, this.customer});
}

final incomingCallProvider = StateProvider<IncomingCall?>((ref) => null);

final callerIdServerProvider = Provider<CallerIdServer>((ref) {
  return CallerIdServer(ref);
});

class CallerIdServer {
  final Ref _ref;
  ServerSocket? _server;

  CallerIdServer(this._ref);

  Future<void> start() async {
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, 8888);
      _server!.listen((client) {
        client.listen((data) async {
          final phone = String.fromCharCodes(data).trim();
          if (phone.isNotEmpty) {
            final customer = await _ref.read(customerRepositoryProvider).findByPhone(phone);
            _ref.read(incomingCallProvider.notifier).state = IncomingCall(phone: phone, customer: customer);
          }
        });
      });
    } catch (_) {}
  }

  void stop() {
    _server?.close();
  }
}