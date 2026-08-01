import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/caller_id_server.dart';
import 'caller_id_overlay.dart';

class CallerIdListener extends ConsumerStatefulWidget {
  final Widget child;

  const CallerIdListener({super.key, required this.child});

  @override
  ConsumerState<CallerIdListener> createState() => _CallerIdListenerState();
}

class _CallerIdListenerState extends ConsumerState<CallerIdListener> {
  bool _isDialogShowing = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<IncomingCall?>(incomingCallProvider, (previous, call) async {
      if (call != null && !_isDialogShowing) {
        setState(() {
          _isDialogShowing = true;
        });

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => CallerIdDialog(
            number: call.phone,
            customer: call.customer,
            onClose: () {
              Navigator.pop(ctx);
            },
            onAddCustomer: () async {
              Navigator.pop(ctx);
            },
            onOpenOrder: () async {
              Navigator.pop(ctx);
            },
          ),
        );

        if (mounted) {
          setState(() {
            _isDialogShowing = false;
          });
        }
      }
    });

    return widget.child;
  }
}