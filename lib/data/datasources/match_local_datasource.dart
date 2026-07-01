// lib/data/datasources/match_local_datasource.dart
//
// Adaptador concreto del puerto LocalDataSourcePort.
// Usa Hive para persistencia sin necesidad de code generation
// (sin TypeAdapters): serializa Match a JSON string directamente.
//
// Dos boxes separadas con responsabilidades distintas:
//   statusBox  → estados personales del usuario (pequeños, frecuentes)
//   cacheBox   → fixture completo (grande, refrescado periódicamente)

import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/entities/match.dart';
import '../../data/models/match_model.dart';
import '../../domain/ports/local_datasource_port.dart';

class MatchLocalDataSource implements LocalDataSourcePort {
  // Hive boxes inyectadas desde main.dart (ya abiertas al arrancar la app).
  final Box<int> _statusBox;
  final Box<bool> _extraTimeBox;
  final Box<String> _cacheBox;

  MatchLocalDataSource({
    required Box<int> statusBox,
    required Box<bool> extraTimeBox,
    required Box<String> cacheBox,
  })  : _statusBox = statusBox,
        _extraTimeBox = extraTimeBox,
        _cacheBox = cacheBox;

  // ─────────────────────────────────────────────────────────────────────────
  // Estado personal del usuario
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<void> saveViewingStatus(
    String matchId,
    UserViewingStatus status,
  ) async {
    try {
      await _statusBox.put(matchId, status.index);
    } catch (e) {
      throw CacheException('No se pudo guardar el estado', cause: e);
    }
  }

  @override
  UserViewingStatus readViewingStatus(String matchId) {
    final index = _statusBox.get(matchId);
    if (index == null) return UserViewingStatus.notWatched;
    return UserViewingStatus.values[
      index.clamp(0, UserViewingStatus.values.length - 1)
    ];
  }

  @override
  Map<String, UserViewingStatus> readAllViewingStatuses() {
    return {
      for (final key in _statusBox.keys.cast<String>())
        key: UserViewingStatus.values[
          _statusBox.get(key)!.clamp(0, UserViewingStatus.values.length - 1)
        ],
    };
  }

  @override
  Future<void> saveExtraTimeStatus(String matchId, bool watched) async {
    try {
      await _extraTimeBox.put(matchId, watched);
    } catch (e) {
      throw CacheException('No se pudo guardar el estado de alargue', cause: e);
    }
  }

  @override
  bool readExtraTimeStatus(String matchId) {
    return _extraTimeBox.get(matchId) ?? false;
  }

  @override
  Map<String, bool> readAllExtraTimeStatuses() {
    return {
      for (final key in _extraTimeBox.keys.cast<String>())
        key: _extraTimeBox.get(key)!,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Caché del fixture
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<void> cacheMatches(List<Match> matches) async {
    try {
      final jsonList = matches.map((m) => m.toJson()).toList();
      await _cacheBox.put(
        HiveConstants.cacheMatchesKey,
        jsonEncode(jsonList),
      );
      await _cacheBox.put(
        HiveConstants.cacheTimestampKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      throw CacheException('No se pudo guardar el caché', cause: e);
    }
  }

  @override
  List<Match>? readCachedMatches() {
    try {
      final raw = _cacheBox.get(HiveConstants.cacheMatchesKey);
      if (raw == null) return null;

      final jsonList = jsonDecode(raw) as List<dynamic>;
      return jsonList
          .map((m) => MatchSerialization.fromCacheJson(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Cache corrupto → lo tratamos como ausente
      return null;
    }
  }

  @override
  DateTime? lastSyncedAt() {
    final raw = _cacheBox.get(HiveConstants.cacheTimestampKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  @override
  bool isCacheStale(Duration maxAge) {
    final last = lastSyncedAt();
    if (last == null) return true;
    return DateTime.now().difference(last) > maxAge;
  }
}
