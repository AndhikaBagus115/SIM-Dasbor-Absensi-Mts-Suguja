import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/exceptions.dart';
import '../../core/services/master_data_cache_service.dart';
import '../models/guru_model.dart';

/// Abstract repository interface for Guru operations
abstract class GuruRepository {
  /// Get all teachers
  Future<List<Guru>> getAllGuru({
    String? searchQuery,
    int limit = 20,
    int offset = 0,
  });

  /// Get a single teacher by ID
  Future<Guru?> getGuruById(String id);

  /// Create a new teacher
  Future<Guru> createGuru(Map<String, dynamic> data);

  /// Update an existing teacher
  Future<Guru> updateGuru(String id, Map<String, dynamic> data);

  /// Delete a teacher
  Future<void> deleteGuru(String id);

  /// Get total count of teachers
  Future<int> getGuruCount();

  /// Watch real-time updates for all teachers
  Stream<List<Guru>> watchGuru();
}

/// Implementation of GuruRepository using Supabase
class GuruRepositoryImpl implements GuruRepository {
  final SupabaseClient _supabase;
  List<Guru>? _cachedGuru;

  GuruRepositoryImpl(this._supabase);

  @override
  Future<List<Guru>> getAllGuru({
    String? searchQuery,
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    try {
      if (!forceRefresh &&
          (searchQuery == null || searchQuery.isEmpty) &&
          offset == 0 &&
          _cachedGuru != null) {
        return _cachedGuru!;
      }

      dynamic response;

      var query = _supabase.from(DbTables.guru).select();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike(GuruColumns.nama, '%$searchQuery%');
      }

      response = await query
          .order(GuruColumns.nama)
          .range(offset, offset + limit - 1);

      final result = (response as List<dynamic>)
          .map((json) => Guru.fromJson(json as Map<String, dynamic>))
          .toList();

      if ((searchQuery == null || searchQuery.isEmpty) && offset == 0) {
        _cachedGuru = result;
      }

      return result;
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to fetch teachers: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while fetching teachers',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Guru?> getGuruById(String id) async {
    try {
      final response = await _supabase
          .from(DbTables.guru)
          .select()
          .eq(GuruColumns.id, id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Guru.fromJson(response);
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to fetch teacher: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while fetching teacher',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Guru> createGuru(Map<String, dynamic> data) async {
    try {
      _validateGuruData(data);

      final response = await _supabase
          .from(DbTables.guru)
          .insert(data)
          .select()
          .single();

      _cachedGuru = null;
      MasterDataCacheService.instance.invalidateGuru();
      return Guru.fromJson(response);
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to create teacher: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while creating teacher',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Guru> updateGuru(String id, Map<String, dynamic> data) async {
    try {
      _validateGuruData(data, isUpdate: true);

      final response = await _supabase
          .from(DbTables.guru)
          .update(data)
          .eq(GuruColumns.id, id)
          .select()
          .single();

      _cachedGuru = null;
      MasterDataCacheService.instance.invalidateGuru();
      return Guru.fromJson(response);
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to update teacher: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while updating teacher',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> deleteGuru(String id) async {
    try {
      await _supabase
          .from(DbTables.guru)
          .delete()
          .filter(GuruColumns.id, 'eq', id);
      _cachedGuru = null;
      MasterDataCacheService.instance.invalidateGuru();
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to delete teacher: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while deleting teacher',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<int> getGuruCount() async {
    try {
      var query = _supabase.from(DbTables.guru).select('id');

      final response = await query.count(CountOption.exact);

      return response.count;
    } catch (e) {
      return 0;
    }
  }

  @override
  Stream<List<Guru>> watchGuru() {
    try {
      return _supabase
          .from(DbTables.guru)
          .stream(primaryKey: [GuruColumns.id])
          .order(GuruColumns.nama)
          .map(
            (response) => (response as List)
                .map((json) => Guru.fromJson(json as Map<String, dynamic>))
                .toList(),
          );
    } catch (e) {
      return Stream.error(
        RepositoryException(
          message: 'Failed to watch teachers',
          originalException: e,
        ),
      );
    }
  }

  /// Validate guru data before creating or updating
  void _validateGuruData(Map<String, dynamic> data, {bool isUpdate = false}) {
    for (final column in [GuruColumns.nama, GuruColumns.email]) {
      if (!isUpdate || data.containsKey(column)) {
        final value = data[column];
        if (value is! String || value.trim().isEmpty) {
          throw ValidationException(
            message: '$column wajib diisi',
            fieldErrors: {column: 'Wajib diisi'},
          );
        }
      }
    }
  }
}
