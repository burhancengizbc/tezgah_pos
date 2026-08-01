import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/people_collections.dart';

/// Gelen arama bildirimi. Kayitli musteri varsa bilgisini gosterir ve
/// hizli paket siparisi acmayi saglar.
class CallerIdDialog extends StatelessWidget {
  final String number;
  final Customer? customer;
  final Future<void> Function() onOpenOrder;
  final Future<void> Function() onAddCustomer;
  final VoidCallback onClose;

  const CallerIdDialog({
    super.key,
    required this.number,
    required this.customer,
    required this.onOpenOrder,
    required this.onAddCustomer,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final known = customer != null;
    return AlertDialog(
      icon: const Icon(Icons.phone_in_talk_rounded,
          color: AppColors.amber, size: 36),
      title: const Text('Gelen Arama'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(number,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          if (known) ...[
            Text(customer!.fullName.isEmpty ? '(isimsiz musteri)' : customer!.fullName,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${customer!.totalOrders} siparis • ${Money.format(customer!.totalSpendKurus)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (customer!.address.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(customer!.address,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ] else
            const Text('Kayitli musteri degil',
                style: TextStyle(color: AppColors.dTextDim)),
        ],
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        TextButton(onPressed: onClose, child: const Text('Kapat')),
        if (!known)
          OutlinedButton.icon(
            onPressed: onAddCustomer,
            icon: const Icon(Icons.person_add_alt_rounded, size: 18),
            label: const Text('Musteri Ekle'),
          ),
        FilledButton.icon(
          onPressed: onOpenOrder,
          icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
          label: const Text('Paket Siparisi Ac'),
        ),
      ],
    );
  }
}
