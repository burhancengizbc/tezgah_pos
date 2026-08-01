import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../data/collections/people_collections.dart';

final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError('isarProvider main() icinde override edilmeli.');
});

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

final appUnlockedProvider = StateProvider<bool>((ref) => false);

/// POS ekraninda aktif islem yapan (oturum acmis) personel.
final activeEmployeeProvider = StateProvider<Employee?>((ref) => null);