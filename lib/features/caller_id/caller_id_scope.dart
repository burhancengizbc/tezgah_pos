import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_streams.dart';
import 'caller_id_controller.dart';

/// Ayarlardaki callerIdEnabled durumuna gore Caller ID dinlemeyi baslatir/durdurur.
/// Uygulama agacinin ust kismina yerlestirilir.
class CallerIdScope extends ConsumerStatefulWidget {
  final Widget child;
  const CallerIdScope({super.key, required this.child});

  @override
  ConsumerState<CallerIdScope> createState() => _CallerIdScopeState();
}

class _CallerIdScopeState extends ConsumerState<CallerIdScope> {
  bool? _active;

  Future<void> _apply(bool enabled) async {
    if (_active == enabled) return;
    _active = enabled;
    final c = ref.read(callerIdControllerProvider);
    if (enabled) {
      await c.enable();
    } else {
      await c.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsStreamProvider, (prev, next) {
      next.whenData((s) => _apply(s.callerIdEnabled));
    });
    // Ilk deger
    final s = ref.watch(settingsStreamProvider);
    s.whenData((v) {
      if (_active == null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _apply(v.callerIdEnabled));
      }
    });
    return widget.child;
  }
}
