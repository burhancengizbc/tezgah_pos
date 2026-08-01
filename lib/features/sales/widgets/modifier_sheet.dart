import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../data/collections/catalog_collections.dart';
import '../../../data/collections/sales_collections.dart';
import '../../shared/widgets.dart';

/// Modifier secim sonucu.
class ModifierResult {
  final double qty;
  final String note;
  final List<SelectedModifier> modifiers;
  const ModifierResult(this.qty, this.note, this.modifiers);
}

/// Urun secenekleri (porsiyon/ekstra) + adet + not secim ekrani.
class ModifierSheet extends StatefulWidget {
  final Product product;
  const ModifierSheet({super.key, required this.product});

  static Future<ModifierResult?> show(BuildContext context, Product p) {
    return showModalBottomSheet<ModifierResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ModifierSheet(product: p),
    );
  }

  @override
  State<ModifierSheet> createState() => _ModifierSheetState();
}

class _ModifierSheetState extends State<ModifierSheet> {
  late final List<Set<int>> _selected; // grup basina secili index'ler
  final _noteCtrl = TextEditingController();
  double _qty = 1;

  @override
  void initState() {
    super.initState();
    _selected = widget.product.modifierGroups.map((g) {
      // zorunlu tekli grupta ilk secenek varsayilan secili
      if (g.required && !g.multiSelect && g.options.isNotEmpty) {
        return <int>{0};
      }
      return <int>{};
    }).toList();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  int get _extraKurus {
    var sum = 0;
    final groups = widget.product.modifierGroups;
    for (var gi = 0; gi < groups.length; gi++) {
      for (final oi in _selected[gi]) {
        sum += groups[gi].options[oi].priceKurus;
      }
    }
    return sum;
  }

  int get _unitKurus => widget.product.salePriceKurus + _extraKurus;

  List<SelectedModifier> _buildMods() {
    final out = <SelectedModifier>[];
    final groups = widget.product.modifierGroups;
    for (var gi = 0; gi < groups.length; gi++) {
      for (final oi in _selected[gi]) {
        final o = groups[gi].options[oi];
        out.add(SelectedModifier()
          ..groupName = groups[gi].name
          ..optionName = o.name
          ..priceKurus = o.priceKurus);
      }
    }
    return out;
  }

  void _toggle(int gi, int oi, bool multi) {
    setState(() {
      if (multi) {
        if (_selected[gi].contains(oi)) {
          _selected[gi].remove(oi);
        } else {
          _selected[gi].add(oi);
        }
      } else {
        _selected[gi] = {oi};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final t = Theme.of(context).textTheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (context, scroll) => Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(p.name, style: t.titleLarge),
                  const SizedBox(height: AppSpacing.lg),
                  for (var gi = 0; gi < p.modifierGroups.length; gi++)
                    _group(p.modifierGroups[gi], gi),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Not (orn: acili olmasin)',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Adet', style: t.titleMedium),
                      QtyStepper(
                          value: _qty,
                          onChanged: (v) =>
                              setState(() => _qty = v <= 0 ? 1 : v)),
                    ],
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: FilledButton(
                  onPressed: _qty <= 0
                      ? null
                      : () => Navigator.pop(
                            context,
                            ModifierResult(
                                _qty, _noteCtrl.text.trim(), _buildMods()),
                          ),
                  child: Text(
                      'Ekle  •  ${Money.format((_unitKurus * _qty).round())}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _group(ModifierGroup g, int gi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(g.name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (g.required)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('*', style: TextStyle(color: AppColors.danger)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var oi = 0; oi < g.options.length; oi++)
              FilterChip(
                selected: _selected[gi].contains(oi),
                label: Text(g.options[oi].priceKurus > 0
                    ? '${g.options[oi].name} (+${Money.plain(g.options[oi].priceKurus)})'
                    : g.options[oi].name),
                onSelected: (_) => _toggle(gi, oi, g.multiSelect),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
