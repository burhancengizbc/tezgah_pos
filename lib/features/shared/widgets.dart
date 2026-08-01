import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';

/// Para gosterimi.
class MoneyText extends StatelessWidget {
  final int kurus;
  final TextStyle? style;
  final Color? color;
  const MoneyText(this.kurus, {super.key, this.style, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(Money.format(kurus),
        style: (style ?? const TextStyle()).copyWith(
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ));
  }
}

/// Adet artir/azalt.
class QtyStepper extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double step;
  const QtyStepper(
      {super.key,
      required this.value,
      required this.onChanged,
      this.step = 1});

  String get _label =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(context, Icons.remove, () {
          final next = value - step;
          onChanged(next < 0 ? 0 : next);
        }),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(_label,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        _btn(context, Icons.add, () => onChanged(value + step)),
      ],
    );
  }

  Widget _btn(BuildContext c, IconData i, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(c).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.rSm),
        ),
        child: Icon(i, size: 20),
      ),
    );
  }
}

/// Bos durum.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;
  const EmptyState(
      {super.key, required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.dTextDim),
          const SizedBox(height: AppSpacing.md),
          Text(message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Basit numerik PIN girisi.
class PinPad extends StatefulWidget {
  final String title;
  final String? subtitle;
  final int length;
  final Future<bool> Function(String pin) onSubmit;
  const PinPad({
    super.key,
    required this.title,
    this.subtitle,
    this.length = 4,
    required this.onSubmit,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  bool _error = false;
  bool _busy = false;

  Future<void> _press(String d) async {
    if (_busy || _pin.length >= widget.length) return;
    setState(() {
      _pin += d;
      _error = false;
    });
    if (_pin.length == widget.length) {
      setState(() => _busy = true);
      final ok = await widget.onSubmit(_pin);
      if (mounted) {
        setState(() {
          _error = !ok;
          _pin = '';
          _busy = false;
        });
      }
    }
  }

  void _back() => setState(() {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
        _error = false;
      });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: t.titleLarge),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(widget.subtitle!, style: t.bodySmall),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (i) {
            final filled = i < _pin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? AppColors.amber : Colors.transparent,
                border: Border.all(
                    color: _error ? AppColors.danger : AppColors.amber,
                    width: 2),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: 280,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (var n = 1; n <= 9; n++) _key('$n'),
              const SizedBox(width: 72, height: 72),
              _key('0'),
              _keyIcon(Icons.backspace_outlined, _back),
            ],
          ),
        ),
      ],
    );
  }

  Widget _key(String d) => SizedBox(
        width: 72,
        height: 72,
        child: OutlinedButton(
          onPressed: () => _press(d),
          style: OutlinedButton.styleFrom(shape: const CircleBorder()),
          child: Text(d, style: const TextStyle(fontSize: 24)),
        ),
      );

  Widget _keyIcon(IconData i, VoidCallback onTap) => SizedBox(
        width: 72,
        height: 72,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(shape: const CircleBorder()),
          child: Icon(i),
        ),
      );
}
