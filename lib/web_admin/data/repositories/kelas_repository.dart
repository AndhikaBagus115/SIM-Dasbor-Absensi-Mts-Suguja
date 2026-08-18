import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_admin_mts/web_admin/core/constants.dart';
import 'package:web_admin_mts/web_admin/core/exceptions.dart';
import 'package:web_admin_mts/web_admin/data/models/kelas_model.dart';

/// Abstract repository interface for Kelas operations
abstract class KelasRepository {
  /// Get all classes
  Future<List<Kelas>> getAllKelas({
    String? searchQuery,
    int limit = 20,
    int offset = 0,
  });

  /// Get a single class by ID
  Future<Kelas?> getKelasById(int id);

  /// Create a new class
  Future<Kelas> createKelas(Map<String, dynamic> data);

  /// Update an existing class
  Future<Kelas> updateKelas(int id, Map<String, dynamic> data);

  /// Delete a class
  Future<void> deleteKelas(int id);

  /// Get total count of classes
  Future<int> getKelasCount();

  /// Watch real-time updates for all classes
  Stream<List<Kelas>> watchKelas();
}

/// Implementation of KelasRepository using Supabase
class KelasRepositoryImpl implements KelasRepository {
  final SupabaseClient _supabase;
  List<Kelas>? _cachedKelas;

  KelasRepositoryImpl(this._supabase);

  @override
  Future<List<Kelas>> getAllKelas({
    String? searchQuery,
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    try {
      if (!forceRefresh && (searchQuery == null || searchQuery.isEmpty) && offset == 0 && _cachedKelas != null) {
        return _cachedKelas!;
      }

      dynamic response;

      var query = _supabase.from(DbTables.kelas).select();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike(KelasColumns.namaKelas, '%$searchQuery%');
      }

      response = await query
          .order(KelasColumns.namaKelas)
          .range(offset, offset + limit - 1);

      final result = (response as List<dynamic>)
          .map((json) => Kelas.fromJson(json as Map<String, dynamic>))
          .toList();

      if ((searchQuery == null || searchQuery.isEmpty) && offset == 0) {
        _cachedKelas = result;
      }

      return result;
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to fetch classes: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while fetching classes',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Kelas?> getKelasById(int id) async {
    try {
      final response = await _supabase
          .from(DbTables.kelas)
          .select()
          .eq(KelasColumns.id, id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Kelas.fromJson(response);
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to fetch class: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while fetching class',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Kelas> createKelas(Map<String, dynamic> data) async {
    try {
      _validateKelasData(data);

      final response = await _supabase
          .from(DbTables.kelas)
          .insert(data)
          .select()
          .single();

      _cachedKelas = null;
      return Kelas.fromJson(response);
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to create class: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while creating class',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Kelas> updateKelas(int id, Map<String, dynamic> data) async {
    try {
      _validateKelasData(data, isUpdate: true);

      final response = await _supabase
          .from(DbTables.kelas)
          .update(data)
          .eq(KelasColumns.id, id)
          .select()
          .single();

      _cachedKelas = null;
      return Kelas.fromJson(response);
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to update class: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while updating class',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> deleteKelas(int id) async {
    try {
      await _supabase
          .from(DbTables.kelas)
          .delete()
          .eq(KelasColumns.id, id);
      _cachedKelas = null;
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to delete class: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while deleting class',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<int> getKelasCount() async {
    try {
      var query = _supabase.from(DbTables.kelas).select('id');

      final response = await query.count(CountOption.exact);
      
      return response.count;
    } catch (e) {
      return 0;
    }
  }

  @override
  Stream<List<Kelas>> watchKelas() {
    try {
      return _supabase
          .from(DbTables.kelas)
          .stream(primaryKey: [KelasColumns.id])
          .order(KelasColumns.namaKelas)
          .map((response) => (response as List)
              .map((json) => Kelas.fromJson(json as Map<String, dynamic>))
              .toList());
    } catch (e) {
      return Stream.error(
        RepositoryException(
          message: 'Failed to watch classes',
          originalException: e,
        ),
      );
    }
  }

  /// Validate kelas data before creating or updating
  void _validateKelasData(Map<String, dynamic> data, {bool isUpdate = false}) {
    if (!isUpdate) {
      final namaKelas = data[KelasColumns.namaKelas] as String?;
      if (namaKelas == null || namaKelas.isEmpty) {
        throw ValidationException(
          message: 'Class name is required',
          fieldErrors: {KelasColumns.namaKelas: 'Class name cannot be empty'},
        );
      }

      final tingkat = data[KelasColumns.tingkat] as String?;
      if (tingkat == null || tingkat.isEmpty) {
        throw ValidationException(
          message: 'Level is required',
          fieldErrors: {KelasColumns.tingkat: 'Level cannot be empty'},
        );
      }
    }

    if (data.containsKey(KelasColumns.namaKelas)) {
      final value = data[KelasColumns.namaKelas] as String?;
      if (value == null || value.isEmpty) {
        throw ValidationException(
          message: 'Class name cannot be empty',
          fieldErrors: {KelasColumns.namaKelas: 'Class name is required'},
        );
      }
    }

    if (data.containsKey(KelasColumns.tingkat)) {
      final value = data[KelasColumns.tingkat] as String?;
      if (value == null || value.isEmpty) {
        throw ValidationException(
          message: 'Level cannot be empty',
          fieldErrors: {KelasColumns.tingkat: 'Level is required'},
        );
      }
    }
  }
}
