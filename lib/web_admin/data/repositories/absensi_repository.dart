import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_admin_mts/web_admin/core/constants.dart';
import 'package:web_admin_mts/web_admin/core/exceptions.dart';
import 'package:web_admin_mts/web_admin/data/models/absensi_model.dart';

/// Abstract repository interface for Absensi operations
abstract class AbsensiRepository {
  /// Get attendance records with optional filtering
  Future<List<Absensi>> getAbsensi({
    String? siswaId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int limit = 20,
    int offset = 0,
  });

  /// Get a single attendance record by ID
  Future<Absensi?> getAbsensiById(int id);

  /// Create a new attendance record
  Future<Absensi> createAbsensi(Map<String, dynamic> data);

  /// Update an existing attendance record
  Future<Absensi> updateAbsensi(int id, Map<String, dynamic> data);

  /// Delete an attendance record
  Future<void> deleteAbsensi(int id);

  /// Get attendance summary for a date
  Future<Map<String, int>> getAttendanceSummary(DateTime date);

  /// Get daily attendance summary
  Future<List<Absensi>> getDailyAbsensi(DateTime date, {String? kelasId});

  /// Watch real-time updates for attendance
  Stream<List<Absensi>> watchAbsensi();
}

/// Implementation of AbsensiRepository using Supabase
class AbsensiRepositoryImpl implements AbsensiRepository {
  final SupabaseClient _supabase;

  AbsensiRepositoryImpl(this._supabase);

  @override
  Future<List<Absensi>> getAbsensi({
    String? siswaId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      dynamic response;

      var query = _supabase.from(DbTables.absensi).select();

      if (siswaId != null && siswaId.isNotEmpty) {
        query = query.eq(AbsensiColumns.siswaId, int.parse(siswaId));
      }
      if (startDate != null) {
        query = query.gte(AbsensiColumns.tanggal, startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte(AbsensiColumns.tanggal, endDate.toIso8601String());
      }
      if (status != null && status.isNotEmpty) {
        query = query.eq(AbsensiColumns.status, status);
      }

      response = await query
          .order(AbsensiColumns.tanggal, ascending: false)
          .range(offset, offset + limit - 1);


      return (response as List<dynamic>)
          .map((json) => Absensi.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to fetch attendance: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while fetching attendance',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Absensi?> getAbsensiById(int id) async {
    try {
      final response = await _supabase
          .from(DbTables.absensi)
          .select()
          .filter(AbsensiColumns.id, 'eq', id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Absensi.fromJson(response);
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to fetch attendance: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while fetching attendance',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Absensi> createAbsensi(Map<String, dynamic> data) async {
    try {
      _validateAbsensiData(data);

      final response = await _supabase
          .from(DbTables.absensi)
          .insert(data)
          .select()
          .single();

      return Absensi.fromJson(response);
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to create attendance: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while creating attendance',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Absensi> updateAbsensi(int id, Map<String, dynamic> data) async {
    try {
      _validateAbsensiData(data, isUpdate: true);

      final response = await _supabase
          .from(DbTables.absensi)
          .update(data)
          .filter(AbsensiColumns.id, 'eq', id)
          .select()
          .single();

      return Absensi.fromJson(response);
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to update attendance: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while updating attendance',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> deleteAbsensi(int id) async {
    try {
      await _supabase
          .from(DbTables.absensi)
          .delete()
          .filter(AbsensiColumns.id, 'eq', id);
    } on PostgrestException catch (e) {
      throw RepositoryException(
        message: 'Failed to delete attendance: ${e.message}',
        code: e.code,
        originalException: e,
      );
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Unexpected error while deleting attendance',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Map<String, int>> getAttendanceSummary(DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      final response = await _supabase
          .from(DbTables.absensi)
          .select()
          .eq(AbsensiColumns.tanggal, dateStr);

      final summary = <String, int>{};
      for (final record in response) {
        final status = (record)[AbsensiColumns.status] as String? ?? 'hadir';
        summary[status] = (summary[status] ?? 0) + 1;
      }

      return summary;
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Failed to get attendance summary',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<Absensi>> getDailyAbsensi(DateTime date, {String? kelasId}) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      
      final response = await _supabase
          .from(DbTables.absensi)
          .select()
          .eq(AbsensiColumns.tanggal, dateStr)
          .order(AbsensiColumns.siswaId);

      return (response as List<dynamic>)
          .map((json) => Absensi.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      throw RepositoryException(
        message: 'Failed to get daily attendance',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Stream<List<Absensi>> watchAbsensi() {
    try {
      return _supabase
          .from(DbTables.absensi)
          .stream(primaryKey: [AbsensiColumns.id])
          .order(AbsensiColumns.tanggal, ascending: false)
          .map((response) => (response as List)
              .map((json) => Absensi.fromJson(json as Map<String, dynamic>))
              .toList());
    } catch (e) {
      return Stream.error(
        RepositoryException(
          message: 'Failed to watch attendance',
          originalException: e,
        ),
      );
    }
  }

  /// Validate absensi data before creating or updating
  void _validateAbsensiData(Map<String, dynamic> data, {bool isUpdate = false}) {
    if (!isUpdate) {
      if ((data[AbsensiColumns.siswaId] as int?) == null) {
        throw ValidationException(
          message: 'Student is required',
          fieldErrors: {AbsensiColumns.siswaId: 'Student cannot be empty'},
        );
      }

      final status = data[AbsensiColumns.status] as String?;
      if (status == null || status.isEmpty) {
        throw ValidationException(
          message: 'Status is required',
          fieldErrors: {AbsensiColumns.status: 'Status cannot be empty'},
        );
      }
    }

    if (data.containsKey(AbsensiColumns.status)) {
      final status = data[AbsensiColumns.status] as String?;
      if (status == null || status.isEmpty) {
        throw ValidationException(
          message: 'Status cannot be empty',
          fieldErrors: {AbsensiColumns.status: 'Status is required'},
        );
      }
    }
  }
}
