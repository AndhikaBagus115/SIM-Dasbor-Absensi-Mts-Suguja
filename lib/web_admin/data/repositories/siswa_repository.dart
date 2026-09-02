import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/exceptions.dart';
import '../../core/services/master_data_cache_service.dart';
import '../models/siswa_model.dart';

/// Abstract repository interface for Siswa operations
abstract class SiswaRepository {
  /// Get all students with optional filtering and pagination
  Future<List<Siswa>> getAllSiswa({
    String? kelasId,
    String? searchQuery,
    int limit = 20,
    int offset = 0,
  });

  /// Get a single student by ID
  Future<Siswa?> getSiswaById(int id);

  /// Create a new student
  Future<Siswa> createSiswa(Map<String, dynamic> data);

  /// Update an existing student
  Future<Siswa> updateSiswa(int id, Map<String, dynamic> data);

  /// Delete a student
  Future<void> deleteSiswa(int id);

  /// Get total count of students
  Future<int> getSiswaCount({String? kelasId});

  /// Watch real-time updates for all students
  Stream<List<Siswa>> watchSiswa({String? kelasId});
}

/// Implementation of SiswaRepository using Supabase
class SiswaRepositoryImpl implements SiswaRepository {
  final SupabaseClient _supabase;

  SiswaRepositoryImpl(this._supabase);

  @override
  Future<List<Siswa>> getAllSiswa({
    String? kelasId,
    String? searchQuery,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Direct approach: create query and execute in one statement
      // to avoid type inference issues with query builder
      dynamic response;
      
      if (kelasId != null && kelasId.isNotEmpty && searchQuery != null && searchQuery.isNotEmpty) {
        response = await _supabase
            .from(DbTables.siswa)
            .select()
            .eq(SiswaColumns.kelasId, kelasId)
            .ilike(SiswaColumns.nama, '%$searchQuery%')
            .order(SiswaColumns.nama)
            .range(offset, offset + limit - 1);
      } else if (kelasId != null && kelasId.isNotEmpty) {
        response = await _supabase
            .from(DbTables.siswa)
            .select()
            .eq(SiswaColumns.kelasId, kelasId)
            .order(SiswaColumns.nama)
            .range(offset, offset + limit - 1);
      } else if (searchQuery != null && searchQuery.isNotEmpty) {
        response = await _supabase
            .from(DbTables.siswa)
            .select()
            .ilike(SiswaColumns.nama, '%$searchQuery%')
            .order(SiswaColumns.nama)
            .range(offset, offset + limit - 1);
      } else {
        response = await _supabase
            .from(DbTables.siswa)
            .select()
            .order(SiswaColumns.nama)
            .range(offset, offset + limit - 1);
      }

      return (response as List<dynamic>)
          .map((json) => Siswa.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to fetch students: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while fetching students',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Siswa?> getSiswaById(int id) async {
    try {
      final response = await _supabase
          .from(DbTables.siswa)
          .select()
          .filter(SiswaColumns.id, 'eq', id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Siswa.fromJson(response);
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to fetch student: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while fetching student',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Siswa> createSiswa(Map<String, dynamic> data) async {
    try {
      _validateSiswaData(data);

      final response = await _supabase
          .from(DbTables.siswa)
          .insert(data)
          .select()
          .single();

      MasterDataCacheService.instance.invalidateSiswa(kelasId: int.tryParse(data[SiswaColumns.kelasId]?.toString() ?? ''));
      return Siswa.fromJson(response);
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to create student: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while creating student',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Siswa> updateSiswa(int id, Map<String, dynamic> data) async {
    try {
      _validateSiswaData(data, isUpdate: true);

      final response = await _supabase
          .from(DbTables.siswa)
          .update(data)
          .filter(SiswaColumns.id, 'eq', id)
          .select()
          .single();

      MasterDataCacheService.instance.invalidateSiswa(kelasId: int.tryParse(data[SiswaColumns.kelasId]?.toString() ?? ''));
      return Siswa.fromJson(response);
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to update student: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while updating student',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> deleteSiswa(int id) async {
    try {
      await _supabase
          .from(DbTables.siswa)
          .delete()
          .filter(SiswaColumns.id, 'eq', id);
      MasterDataCacheService.instance.invalidateSiswa();
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to delete student: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while deleting student',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<int> getSiswaCount({String? kelasId}) async {
    try {
      var query = _supabase.from(DbTables.siswa).select('id');

      if (kelasId != null && kelasId.isNotEmpty) {
        query = query.eq(SiswaColumns.kelasId, kelasId);
      }

      final response = await query.count(CountOption.exact);
      return response.count;
    } catch (e) {
      return 0;
    }
  }

  @override
  Stream<List<Siswa>> watchSiswa({String? kelasId}) {
    try {
      return _supabase
          .from(DbTables.siswa)
          .stream(primaryKey: [SiswaColumns.id])
          .order(SiswaColumns.nama)
          .map((response) => (response as List)
              .map((json) => Siswa.fromJson(json as Map<String, dynamic>))
              .toList());
    } catch (e) {
      return Stream.error(
        RepositoryException(
          message: 'Failed to watch students',
          originalException: e,
        ),
      );
    }
  }

  /// Validate siswa data before creating or updating
  void _validateSiswaData(Map<String, dynamic> data, {bool isUpdate = false}) {
    if (!isUpdate) {
      final nis = data[SiswaColumns.nis] as String?;
      if (nis == null || nis.isEmpty) {
        throw ValidationException(
          message: 'NIS is required',
          fieldErrors: {SiswaColumns.nis: 'NIS cannot be empty'},
        );
      }

      final nama = data[SiswaColumns.nama] as String?;
      if (nama == null || nama.isEmpty) {
        throw ValidationException(
          message: 'Name is required',
          fieldErrors: {SiswaColumns.nama: 'Name cannot be empty'},
        );
      }
    }

    if (data.containsKey(SiswaColumns.nis)) {
      final nis = data[SiswaColumns.nis] as String?;
      if (nis == null || nis.isEmpty) {
        throw ValidationException(
          message: 'NIS cannot be empty',
          fieldErrors: {SiswaColumns.nis: 'NIS is required'},
        );
      }
    }

    if (data.containsKey(SiswaColumns.nama)) {
      final nama = data[SiswaColumns.nama] as String?;
      if (nama == null || nama.isEmpty) {
        throw ValidationException(
          message: 'Name cannot be empty',
          fieldErrors: {SiswaColumns.nama: 'Name is required'},
        );
      }
    }
  }
}
