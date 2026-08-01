import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_streams.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/catalog_collections.dart';
import '../../data/enums/app_enums.dart';

class ProductEditScreen extends ConsumerStatefulWidget {
  final Product? product;
  const ProductEditScreen({super.key, this.product});

  @override
  ConsumerState<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends ConsumerState<ProductEditScreen> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _barcode = TextEditingController();
  final _desc = TextEditingController();
  final _stockQty = TextEditingController();
  final _minStock = TextEditingController();

  int? _categoryId;
  double _vat = 10;
  StockType _stockType = StockType.unlimited;
  bool _sellByWeight = false;
  bool _active = true;
  String? _imagePath;
  String? _originalImagePath;
  List<ModifierGroup> _groups = [];
  List<RecipeItem> _recipe = [];
  bool _busy = false;

  bool get _isNew => widget.product == null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _name.text = p.name;
      _price.text = Money.plain(p.salePriceKurus);
      _cost.text = Money.plain(p.costPriceKurus);
      _barcode.text = p.barcode ?? '';
      _desc.text = p.description;
      _stockQty.text = p.stockQty.toString();
      _minStock.text = p.minStock.toString();
      _categoryId = p.categoryId;
      _vat = p.vatRate;
      _stockType = p.stockType;
      _sellByWeight = p.sellByWeight;
      _active = p.isActive;
      _imagePath = p.imagePath;
      _originalImagePath = p.imagePath;
      _groups = p.modifierGroups
          .map((g) => ModifierGroup()
            ..name = g.name
            ..required = g.required
            ..multiSelect = g.multiSelect
            ..options = g.options
                .map((o) => ModifierOption()
                  ..name = o.name
                  ..priceKurus = o.priceKurus)
                .toList())
          .toList();
      _recipe = p.recipe
          .map((r) => RecipeItem()
            ..rawMaterialId = r.rawMaterialId
            ..rawMaterialName = r.rawMaterialName
            ..quantity = r.quantity
            ..unit = r.unit)
          .toList();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _price,
      _cost,
      _barcode,
      _desc,
      _stockQty,
      _minStock
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final path = await ref.read(imageServiceProvider).pickProductImage();
    if (path != null) setState(() => _imagePath = path);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Urun adi ve kategori zorunlu.')));
      return;
    }
    setState(() => _busy = true);
    final imageSvc = ref.read(imageServiceProvider);
    // Gorsel degistiyse eskisini sil.
    if (_originalImagePath != null && _originalImagePath != _imagePath) {
      await imageSvc.deleteImage(_originalImagePath);
    }

    final p = widget.product ?? Product();
    p
      ..name = _name.text.trim()
      ..categoryId = _categoryId!
      ..salePriceKurus = Money.parse(_price.text)
      ..costPriceKurus = Money.parse(_cost.text)
      ..barcode = _barcode.text.trim().isEmpty ? null : _barcode.text.trim()
      ..description = _desc.text.trim()
      ..vatRate = _vat
      ..stockType = _stockType
      ..stockQty = double.tryParse(_stockQty.text.replaceAll(',', '.')) ?? 0
      ..minStock = double.tryParse(_minStock.text.replaceAll(',', '.')) ?? 0
      ..sellByWeight = _sellByWeight
      ..isActive = _active
      ..imagePath = _imagePath
      ..modifierGroups = _groups
      ..recipe = _recipe;

    await ref.read(productRepositoryProvider).save(p);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(allCategoriesStreamProvider).value ?? [];
    
    // EKLENEN KONTROL: Eğer ürünün kategorisi silinmişse (listede yoksa) seçimi temizle.
    if (_categoryId != null && !cats.any((c) => c.id == _categoryId)) {
      _categoryId = null;
    }
    
    _categoryId ??= cats.isNotEmpty ? cats.first.id : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Urun Ekle' : 'Urun Duzenle'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: const Text('Kaydet'),
          ),
        ],
      ),
      body: cats.isEmpty
          ? const Center(
              child: Text('Once bir kategori olusturun (Kategoriler).'))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _imagePicker(),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Urun adi *'),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int>(
                  value: _categoryId,
                  decoration: const InputDecoration(labelText: 'Kategori *'),
                  items: [
                    for (final c in cats)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Satis fiyati', suffixText: 'TL'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextField(
                        controller: _cost,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Alis maliyeti', suffixText: 'TL'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<double>(
                  value: _vat,
                  decoration: const InputDecoration(labelText: 'KDV %'),
                  items: const [
                    DropdownMenuItem(value: 1.0, child: Text('%1')),
                    DropdownMenuItem(value: 8.0, child: Text('%8')),
                    DropdownMenuItem(value: 10.0, child: Text('%10')),
                    DropdownMenuItem(value: 20.0, child: Text('%20')),
                  ],
                  onChanged: (v) => setState(() => _vat = v ?? 10),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _barcode,
                  decoration: const InputDecoration(labelText: 'Barkod'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _desc,
                  decoration: const InputDecoration(labelText: 'Aciklama'),
                  maxLines: 2,
                ),
                const Divider(height: AppSpacing.xl),

                // Stok
                Text('Stok', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<StockType>(
                  segments: const [
                    ButtonSegment(
                        value: StockType.unlimited,
                        label: Text('Sinirsiz'),
                        icon: Icon(Icons.all_inclusive)),
                    ButtonSegment(
                        value: StockType.numeric,
                        label: Text('Sayisal'),
                        icon: Icon(Icons.tag)),
                  ],
                  selected: {_stockType},
                  onSelectionChanged: (s) =>
                      setState(() => _stockType = s.first),
                ),
                if (_stockType == StockType.numeric) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _stockQty,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Stok adedi'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: _minStock,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Min. stok (uyari)'),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tartili satis (kg)'),
                    value: _sellByWeight,
                    onChanged: (v) => setState(() => _sellByWeight = v),
                  ),
                ],
                const Divider(height: AppSpacing.xl),

                // Secenekler
                _modifiersEditor(),
                const Divider(height: AppSpacing.xl),

                // Reçete / Hammadde (BOM)
                _recipeEditor(),
                const Divider(height: AppSpacing.xl),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktif (satista gorunsun)'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
    );
  }

  Widget _imagePicker() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSpacing.rLg),
                image: (_imagePath != null && _imagePath!.isNotEmpty)
                    ? DecorationImage(
                        image: FileImage(File(_imagePath!)), fit: BoxFit.cover)
                    : null,
              ),
              child: (_imagePath == null || _imagePath!.isEmpty)
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            color: AppColors.amber),
                        SizedBox(height: 6),
                        Text('Resim ekle (istege bagli)',
                            style: TextStyle(fontSize: 11)),
                      ],
                    )
                  : null,
            ),
          ),
          if (_imagePath != null && _imagePath!.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => _imagePath = null),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Resmi kaldir'),
            ),
        ],
      ),
    );
  }

  Widget _modifiersEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Secenekler (porsiyon/ekstra)',
                style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              onPressed: _addGroup,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Grup'),
            ),
          ],
        ),
        for (var gi = 0; gi < _groups.length; gi++) _groupCard(gi),
      ],
    );
  }

  Widget _groupCard(int gi) {
    final g = _groups[gi];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${g.name}${g.required ? ' *' : ''}${g.multiSelect ? '  (coklu)' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => setState(() => _groups.removeAt(gi)),
                ),
              ],
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var oi = 0; oi < g.options.length; oi++)
                  Chip(
                    label: Text(g.options[oi].priceKurus > 0
                        ? '${g.options[oi].name} +${Money.plain(g.options[oi].priceKurus)}'
                        : g.options[oi].name),
                    onDeleted: () =>
                        setState(() => g.options.removeAt(oi)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Secenek'),
                  onPressed: () => _addOption(gi),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addGroup() async {
    final nameCtrl = TextEditingController();
    var required = false;
    var multi = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          title: const Text('Secenek Grubu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Grup adi (orn: Porsiyon)'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Zorunlu'),
                value: required,
                onChanged: (v) => setM(() => required = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Coklu secim'),
                value: multi,
                onChanged: (v) => setM(() => multi = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgec')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() => _groups.add(ModifierGroup()
                  ..name = nameCtrl.text.trim()
                  ..required = required
                  ..multiSelect = multi
                  ..options = []));
                Navigator.pop(ctx);
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addOption(int gi) async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Secenek Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration:
                  const InputDecoration(labelText: 'Secenek adi'),
            ),
            TextField(
              controller: priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
              ],
              decoration: const InputDecoration(
                  labelText: 'Ek ucret', suffixText: 'TL'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgec')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() => _groups[gi].options.add(ModifierOption()
                ..name = nameCtrl.text.trim()
                ..priceKurus = Money.parse(priceCtrl.text)));
              Navigator.pop(ctx);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  Widget _recipeEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Reçete / Hammadde İçeriği (BOM)',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: _addRecipeItem, // DÜZELTİLDİ: _addRecipeItem bağlandı
              icon: const Icon(Icons.link),
              label: const Text('Hammadde Ekle'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Bu ürün satıldığında stoktan otomatik düşülecek alt malzemeler:',
          style: TextStyle(fontSize: 12, color: AppColors.dTextDim),
        ),
        const SizedBox(height: 8),
        if (_recipe.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Henüz reçete tanımı yok. (Normal stok düşülür)',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
          )
        else
          for (var ri = 0; ri < _recipe.length; ri++)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                dense: true,
                title: Text(_recipe[ri].rawMaterialName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Her satışta: ${_recipe[ri].quantity} ${_recipe[ri].unit} düşülür'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                  onPressed: () => setState(() => _recipe.removeAt(ri)),
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _addRecipeItem() async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    String selectedUnit = 'g';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          title: const Text('Hammadde / Malzeme Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Hammadde Adı (Örn: Dana Kıyma, Lavaş)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Miktar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: selectedUnit,
                      decoration: const InputDecoration(labelText: 'Birim'),
                      items: const [
                        DropdownMenuItem(value: 'g', child: Text('Gram (g)')),
                        DropdownMenuItem(value: 'ml', child: Text('Mililitre (ml)')),
                        DropdownMenuItem(value: 'adet', child: Text('Adet')),
                        DropdownMenuItem(value: 'kg', child: Text('Kilogram (kg)')),
                      ],
                      onChanged: (v) => setM(() => selectedUnit = v ?? 'g'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                final qtyVal = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
                if (qtyVal <= 0) return;

                setState(() => _recipe.add(RecipeItem()
                  ..rawMaterialId = DateTime.now().millisecondsSinceEpoch // Basit benzersiz ID
                  ..rawMaterialName = nameCtrl.text.trim()
                  ..quantity = qtyVal
                  ..unit = selectedUnit));
                Navigator.pop(ctx);
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}