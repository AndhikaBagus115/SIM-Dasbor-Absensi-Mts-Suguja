import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_admin_mts/web_admin/core/constants.dart';
import 'package:web_admin_mts/web_admin/core/exceptions.dart';
import 'package:web_admin_mts/web_admin/data/models/surat_model.dart';

/// Abstract repository interface for Surat operations
abstract class SuratRepository {
  /// Get all absence letters
  Future<List<Surat>> getAllSurat({
    String? siswaId,
    String? tipe,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
    int offset = 0,
  });

  /// Get a single absence letter by ID
  Future<Surat?> getSuratById(int id);

  /// Create a new absence letter
  Future<Surat> createSurat(Map<String, dynamic> data);

  /// Update an existing absence letter
  Future<Surat> updateSurat(int id, Map<String, dynamic> data);

  /// Delete an absence letter
  Future<void> deleteSurat(int id);

  /// Get total count of letters
  Future<int> getSuratCount();

  /// Watch real-time updates for letters
  Stream<List<Surat>> watchSurat();
}

/// Implementation of SuratRepository using Supabase
class SuratRepositoryImpl implements SuratRepository {
  final SupabaseClient _supabase;

  SuratRepositoryImpl(this._supabase);

  @override
  Future<List<Surat>> getAllSurat({
    String? siswaId,
    String? tipe,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      dynamic response;

      var query = _supabase.from(DbTables.surat).select();

      if (siswaId != null && siswaId.isNotEmpty) {
        query = query.eq(SuratColumns.siswaId, int.parse(siswaId));
      }
      if (tipe != null && tipe.isNotEmpty) {
        query = query.eq(SuratColumns.tipe, tipe);
      }
      if (startDate != null) {
        query = query.gte(SuratColumns.tanggal, startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte(SuratColumns.tanggal, endDate.toIso8601String());
      }

      response = await query
          .order(SuratColumns.tanggal, ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List<dynamic>)
          .map((json) => Surat.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to fetch letters: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while fetching letters',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Surat?> getSuratById(int id) async {
    try {
      final response = await _supabase
          .from(DbTables.surat)
          .select()
          .eq(SuratColumns.id, id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Surat.fromJson(response);
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to fetch letter: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while fetching letter',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Surat> createSurat(Map<String, dynamic> data) async {
    try {
      _validateSuratData(data);

      final response = await _supabase
          .from(DbTables.surat)
          .insert(data)
          .select()
          .single();

      return Surat.fromJson(response);
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to create letter: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while creating letter',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Surat> updateSurat(int id, Map<String, dynamic> data) async {
    try {
      _validateSuratData(data, isUpdate: true);

      final response = await _supabase
          .from(DbTables.surat)
          .update(data)
          .eq(SuratColumns.id, id)
          .select()
          .single();

      return Surat.fromJson(response);
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to update letter: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while updating letter',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> deleteSurat(int id) async {
    try {
      await _supabase
          .from(DbTables.surat)
          .delete()
          .eq(SuratColumns.id, id);
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to delete letter: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while deleting letter',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<int> getSuratCount() async {
    try {
      var query = _supabase.from(DbTables.surat).select('id');

      final response = await query.count(CountOption.exact);
      
      return response.count;
    } catch (e) {
      return 0;
    }
  }

  @override
  Stream<List<Surat>> watchSurat() {
    try {
      return _supabase
          .from(DbTables.surat)
          .stream(primaryKey: [SuratColumns.id])
          .order(SuratColumns.tanggal, ascending: false)
          .map((response) => (response as List)
              .map((json) => Surat.fromJson(json as Map<String, dynamic>))
              .toList());
    } catch (e) {
      return Stream.error(
        RepositoryException(
          message: 'Failed to watch letters',
          originalException: e,
        ),
      );
    }
  }

  /// Validate surat data before creating or updating
  void _validateSuratData(Map<String, dynamic> data, {bool isUpdate = false}) {
    if (!isUpdate) {
      final siswaId = data[SuratColumns.siswaId] as int?;
      if (siswaId == null) {
        throw ValidationException(
          message: 'Student is required',
          fieldErrors: {SuratColumns.siswaId: 'Student cannot be empty'},
        );
      }

      final tipe = data[SuratColumns.tipe] as String?;
      if (tipe == null || tipe.isEmpty) {
        throw ValidationException(
          message: 'Type is required',
          fieldErrors: {SuratColumns.tipe: 'Type cannot be empty'},
        );
      }
    }

    if (data.containsKey(SuratColumns.tipe)) {
      final value = data[SuratColumns.tipe] as String?;
      if (value == null || value.isEmpty) {
        throw ValidationException(
          message: 'Type cannot be empty',
          fieldErrors: {SuratColumns.tipe: 'Type is required'},
        );
      }
    }
  }
}
