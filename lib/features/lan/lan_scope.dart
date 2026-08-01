import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_streams.dart';
import 'lan_controller.dart';

/// Ayardaki lanServerEnabled durumuna gore yerel ag sunucusunu baslatir/durdurur.
class LanScope extends ConsumerStatefulWidget {
  final Widget child;
  const LanScope({super.key, required this.child});

  @override
  ConsumerState<LanScope> createState() => _LanScopeState();
}

class _LanScopeState extends ConsumerState<LanScope> {
  bool? _active;

  Future<void> _apply(bool enabled) async {
    if (_active == enabled) return;
    _active = enabled;
    final c = ref.read(lanControllerProvider);
    if (enabled) {
      await c.start();
    } else {
      await c.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsStreamProvider, (prev, next) {
      next.whenData((s) => _apply(s.lanServerEnabled));
    });
    final s = ref.watch(settingsStreamProvider);
    s.whenData((v) {
      if (_active == null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _apply(v.lanServerEnabled));
      }
    });
    return widget.child;
  }
}
