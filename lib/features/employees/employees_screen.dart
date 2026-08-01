import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_streams.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/collections/people_collections.dart';
import '../../data/enums/app_enums.dart';
import '../shared/widgets.dart';

const _roleLabels = <EmployeeRole, String>{
  EmployeeRole.waiter: 'Garson',
  EmployeeRole.cashier: 'Kasiyer',
  EmployeeRole.manager: 'Yönetici',
};

class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(activeEmployeesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personel Yönetimi'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(context, ref, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Personel Ekle'),
      ),
      body: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.badge_outlined,
              message: 'Henüz personel eklenmedi.',
              action: FilledButton.icon(
                onPressed: () => _showEditor(context, ref, null),
                icon: const Icon(Icons.add),
                label: const Text('Personel Ekle'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final emp = list[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(emp.avatarColorValue),
                  child: Text(
                    emp.firstName.isNotEmpty ? emp.firstName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Color(0xFF1A1300), fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(emp.fullName),
                subtitle: Text('${_roleLabels[emp.role] ?? emp.role.name} • ${emp.phone.isEmpty ? "Tel yok" : emp.phone}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (emp.canVoid)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Chip(label: Text('İptal Yetkisi', style: TextStyle(fontSize: 10)), backgroundColor: Colors.redAccent),
                      ),
                    if (emp.canDiscount)
                      const Chip(label: Text('İndirim Yetkisi', style: TextStyle(fontSize: 10)), backgroundColor: Colors.orangeAccent),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showEditor(context, ref, emp),
                    ),
                  ],
                ),
                onTap: () => _showEditor(context, ref, emp),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showEditor(BuildContext context, WidgetRef ref, Employee? emp) async {
    final firstCtrl = TextEditingController(text: emp?.firstName ?? '');
    final lastCtrl = TextEditingController(text: emp?.lastName ?? '');
    final phoneCtrl = TextEditingController(text: emp?.phone ?? '');
    final pinCtrl = TextEditingController();

    EmployeeRole role = emp?.role ?? EmployeeRole.waiter;
    bool canVoid = emp?.canVoid ?? false;
    bool canDiscount = emp?.canDiscount ?? false;
    int colorValue = emp?.avatarColorValue ?? 0xFFFFB300;

    final colors = [0xFFFFB300, 0xFF4CAF50, 0xFF2196F3, 0xFFE91E63, 0xFF9C27B0, 0xFF00BCD4];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          title: Text(emp == null ? 'Yeni Personel Ekle' : 'Personeli Düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: firstCtrl,
                        decoration: const InputDecoration(labelText: 'Ad *'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lastCtrl,
                        decoration: const InputDecoration(labelText: 'Soyad'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefon'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: emp == null ? '4 Haneli PIN *' : 'Yeni PIN (Değişmeyecekse boş bırak)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<EmployeeRole>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Görev / Rol'),
                  items: [
                    for (final r in EmployeeRole.values)
                      DropdownMenuItem(value: r, child: Text(_roleLabels[r]!)),
                  ],
                  onChanged: (v) => setM(() => role = v!),
                ),
                const SizedBox(height: 12),
                const Text('Özel Yetkiler:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Satır / Sipariş İptal Edebilsin'),
                  value: canVoid,
                  onChanged: (v) => setM(() => canVoid = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Adisyona İndirim Uygulayabilsin'),
                  value: canDiscount,
                  onChanged: (v) => setM(() => canDiscount = v),
                ),
                const SizedBox(height: 8),
                const Text('Profil Rengi:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final c in colors)
                      GestureDetector(
                        onTap: () => setM(() => colorValue = c),
                        child: CircleAvatar(
                          backgroundColor: Color(c),
                          radius: 16,
                          child: colorValue == c ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (emp != null)
              TextButton(
                onPressed: () async {
                  await ref.read(employeeRepositoryProvider).softDelete(emp.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Sil', style: TextStyle(color: AppColors.danger)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () async {
                if (firstCtrl.text.trim().isEmpty) return;
                final e = emp ?? Employee();
                e
                  ..firstName = firstCtrl.text.trim()
                  ..lastName = lastCtrl.text.trim()
                  ..phone = phoneCtrl.text.trim()
                  ..role = role
                  ..canVoid = canVoid
                  ..canDiscount = canDiscount
                  ..avatarColorValue = colorValue;

                await ref.read(employeeRepositoryProvider).save(e, plainPin: pinCtrl.text.isNotEmpty ? pinCtrl.text : null);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}