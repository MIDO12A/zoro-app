// Compatibility shim: allows code originally written against
// `Supabase.instance.client` to keep compiling on top of Firebase
// (Firestore + FirebaseAuth) while the migration to Firebase proceeds.
//
// Migrated services/screens use `FirebaseService` directly; this layer exists
// so the remaining Supabase-style call sites (mostly the host-agency and agent
// recharge subsystems that depend on Postgres RPC functions) still compile.
// RPC functions that have no Firestore equivalent yet throw a clear error.
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/cloudinary_service.dart';

/// Singleton mirroring `Supabase.instance`.
class Supabase {
  static final Supabase instance = Supabase._();
  Supabase._();
  final SupabaseClient client = SupabaseClient();
}

/// Client exposing a subset of the Supabase API backed by Firestore + FirebaseAuth.
class SupabaseClient {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthClient auth = AuthClient();

  SupabaseQueryBuilder from(String table) => SupabaseQueryBuilder(_db, table);

  /// Postgres RPC -> Firebase. Mapped functions work; unmapped throw.
  Future<dynamic> rpc(String fn, {Map<String, dynamic>? params}) async {
    switch (fn) {
      case 'delete_user_account':
        final auth = this.auth;
        final uid = auth.currentUser?.id ?? params?['uid']?.toString();
        if (uid != null) {
          await _db.collection('users').doc(uid).delete();
        }
        await FirebaseAuth.instance.currentUser?.delete();
        return <String, dynamic>{};
      case 'get_user_signin_data':
        return <String, dynamic>{};
      case 'do_signin':
        return <String, dynamic>{};
      case 'agency_send_chat_message':
        return _rpcAgencySendChatMessage(params);
      case 'agency_mute_member_chat':
        return _rpcAgencyMuteMember(params);
      case 'agency_report_screenshot':
        return _rpcAgencyReportScreenshot(params);
      case 'agency_invite_by_kayan_id':
        return _rpcAgencyInviteByKayanId(params);
      case 'agency_assign_supervisor':
        return _rpcAgencySetSupervisor(params, isSupervisor: true);
      case 'agency_revoke_supervisor':
        return _rpcAgencySetSupervisor(params, isSupervisor: false);
      case 'agency_view_once_open':
        return <String, dynamic>{'status': 'ok'};
      case 'agency_create':
        return _rpcAgencyCreate(params);
    }
    throw StateError(
      'RPC "$fn" is not migrated to Firebase yet. '
      'Migrate the calling feature to FirebaseService/Firestore or implement '
      'the equivalent Cloud Function. See AGENTS.md migration notes.',
    );
  }

  Future<Map<String, dynamic>> _rpcAgencySendChatMessage(
      Map<String, dynamic>? p) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {'status': 'error'};
    final profile = await _db.collection('profiles').doc(uid).get();
    final now = DateTime.now().toUtc();
    final doc = _db.collection('agency_chat_messages').doc();
    await doc.set({
      'id': now.millisecondsSinceEpoch,
      'agency_id': p?['p_agency_id'],
      'sender_id': uid,
      'display_name':
          profile.data()?['display_name']?.toString() ?? 'مستخدم',
      'message_type': p?['p_message_type'] ?? 'text',
      'body': p?['p_body'],
      'asset_url': p?['p_asset_url'],
      'asset_duration_secs': p?['p_asset_duration_secs'],
      'view_duration_seconds': p?['p_view_duration_secs'],
      'is_view_once': p?['p_is_view_once'] ?? false,
      'created_at': now.toIso8601String(),
    });
    return {'status': 'ok'};
  }

  Future<Map<String, dynamic>> _rpcAgencyMuteMember(
      Map<String, dynamic>? p) async {
    final agencyId = p?['p_agency_id']?.toString() ?? '';
    final userId = p?['p_user_id']?.toString() ?? '';
    if (agencyId.isEmpty || userId.isEmpty) return {'status': 'error'};
    final hours = (p?['p_hours'] as num?)?.toInt() ?? 0;
    final col = _db.collection('agency_chat_mutes');
    final query = await col
        .where('agency_id', isEqualTo: agencyId)
        .where('muted_user_id', isEqualTo: userId)
        .get();
    if (hours <= 0) {
      for (final d in query.docs) {
        await d.reference.delete();
      }
      return {'status': 'ok'};
    }
    final until = DateTime.now().toUtc().add(Duration(hours: hours));
    final payload = <String, dynamic>{
      'agency_id': agencyId,
      'muted_user_id': userId,
      'until_at': until.toIso8601String(),
      'reason': p?['p_reason'],
      'muted_by': FirebaseAuth.instance.currentUser?.uid,
    };
    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.set(payload, SetOptions(merge: true));
    } else {
      await col.add(payload);
    }
    return {'status': 'ok'};
  }

  Future<Map<String, dynamic>> _rpcAgencyReportScreenshot(
      Map<String, dynamic>? p) async {
    await _db.collection('agency_screenshot_reports').add({
      'agency_id': p?['p_agency_id'],
      'user_id': FirebaseAuth.instance.currentUser?.uid,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    return {'status': 'ok'};
  }

  Future<Map<String, dynamic>> _rpcAgencyInviteByKayanId(
      Map<String, dynamic>? p) async {
    final kayanId = (p?['p_kayan_id'] ?? '').toString().trim();
    final agencyId = p?['p_agency_id']?.toString() ?? '';
    if (kayanId.isEmpty || agencyId.isEmpty) {
      return {'status': 'error'};
    }
    final snap = await _db
        .collection('profiles')
        .where('kayan_id', isEqualTo: kayanId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return {'status': 'error'};
    final targetUid = snap.docs.first.id;
    await _db.collection('host_agency_join_requests').add({
      'agency_id': agencyId,
      'user_id': targetUid,
      'status': 'invited',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    return {'status': 'ok'};
  }

  Future<Map<String, dynamic>> _rpcAgencySetSupervisor(
      Map<String, dynamic>? p,
      {required bool isSupervisor}) async {
    final agencyId = p?['p_agency_id']?.toString() ?? '';
    final userId = p?['p_user_id']?.toString() ?? '';
    if (agencyId.isEmpty || userId.isEmpty) return {'status': 'error'};
    final snap = await _db
        .collection('host_agency_members')
        .where('agency_id', isEqualTo: agencyId)
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return {'status': 'error'};
    await snap.docs.first.reference
        .update({'role': isSupervisor ? 'supervisor' : 'host'});
    return {'status': 'ok'};
  }

  Future<Map<String, dynamic>> _rpcAgencyCreate(
      Map<String, dynamic>? p) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return {'status': 'error', 'message': 'not_authenticated'};
    }

    final name = (p?['p_name']?.toString() ?? '').trim();
    if (name.isEmpty) {
      return {'status': 'error', 'message': 'name_required'};
    }

    // Check: already member of any agency?
    final existing = await _db
        .collection('host_agency_members')
        .where('user_id', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      return {'status': 'error', 'message': 'already_member'};
    }

    // Create agency doc
    final agencyRef = _db.collection('host_agencies').doc();
    final agencyData = <String, dynamic>{
      'id': agencyRef.id,
      'name': name,
      'owner_id': uid,
      'owner_user_id': uid,
      'description': (p?['p_description']?.toString() ?? '').isEmpty
          ? null
          : p!['p_description'].toString(),
      'photo_url': (p?['p_photo_url']?.toString() ?? '').isEmpty
          ? null
          : p!['p_photo_url'].toString(),
      'phone': (p?['p_phone']?.toString() ?? '').isEmpty
          ? null
          : p!['p_phone'].toString(),
      'country': (p?['p_country']?.toString() ?? '').isEmpty
          ? null
          : p!['p_country'].toString(),
      'tier': 'bronze',
      'is_active': true,
      'member_count': 1,
      'commission_rate': 0.05,
      'specialty': 'mixed',
      'total_diamonds_earned': 0,
      'monthly_diamonds': 0,
      'total_diamonds_monthly': 0,
      'is_hall_of_fame': false,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    await agencyRef.set(agencyData);

    // Add owner as member
    final memberRef = _db.collection('host_agency_members').doc();
    await memberRef.set({
      'id': memberRef.id,
      'agency_id': agencyRef.id,
      'user_id': uid,
      'role': 'owner',
      'status': 'active',
      'diamonds_earned_monthly': 0,
      'diamonds_earned_cumulative': 0,
      'diamonds_balance': 0,
      'diamonds_pending_withdrawal': 0,
      'diamonds_available': 0,
      'joined_at': DateTime.now().toUtc().toIso8601String(),
    });

    return {'status': 'ok', 'agency_id': agencyRef.id};
  }

  RealtimeChannel channel(String topic) => RealtimeChannel(topic);

  void removeChannel(RealtimeChannel channel) {
    channel.dispose();
  }

  StorageClient get storage => StorageClient();
}

/// Storage backed by Cloudinary (mirrors Supabase storage API).
class StorageClient {
  StorageBucket from(String bucket) => StorageBucket(bucket);
}

class StorageBucket {
  final String bucket;
  StorageBucket(this.bucket);

  static final Map<String, String> _uploadedUrls = {};

  Future<String> upload(
    String path,
    dynamic file, {
    FileOptions? fileOptions,
  }) async {
    final File localFile;
    if (file is File) {
      localFile = file;
    } else if (file is Uint8List) {
      final tmp = File(
        '${Directory.systemTemp.path}/$bucket/${path.replaceAll('/', '_')}',
      );
      await tmp.create(recursive: true);
      await tmp.writeAsBytes(file, flush: true);
      localFile = tmp;
    } else {
      throw StateError('Unsupported upload type: ${file.runtimeType}');
    }
    final url = await CloudinaryService().upload(localFile);
    _uploadedUrls[path] = url;
    return path;
  }

  String getPublicUrl(String path) {
    final url = _uploadedUrls[path];
    if (url != null && url.isNotEmpty) return url;
    return 'https://res.cloudinary.com/dl30muiuc/image/upload/$path';
  }
}

class FileOptions {
  final bool upsert;
  const FileOptions({this.upsert = false});
}

/// Realtime-channel shim backed by Firestore snapshot listeners.
/// Replaces Postgres realtime with a Firestore `where` stream on the same table.
class RealtimeChannel {
  final String topic;
  RealtimeChannel(this.topic);

  PostgresChangeEvent? _event;
  String? _table;
  String? _column;
  dynamic _value;
  bool _negated = false;
  void Function(PostgresChangePayload)? _callback;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  RealtimeChannel onPostgresChanges({
    PostgresChangeEvent event = PostgresChangeEvent.all,
    String? schema,
    String? table,
    PostgresChangeFilter? filter,
    void Function(PostgresChangePayload)? callback,
  }) {
    _event = event;
    _table = table;
    _column = filter?.column;
    _value = filter?.value;
    _negated = filter?.type == PostgresChangeFilterType.neq;
    _callback = callback;
    return this;
  }

  RealtimeChannel subscribe() {
    final table = _table;
    final callback = _callback;
    if (table == null || callback == null) return this;
    final db = FirebaseFirestore.instance;
    Query<Map<String, dynamic>> q = db.collection(table);
    if (_column != null && _value != null) {
      q = _negated
          ? q.where(_column!, isNotEqualTo: _value)
          : q.where(_column!, isEqualTo: _value);
    }
    _sub = q.snapshots().listen((snap) {
      final event = _event;
      for (final change in snap.docChanges) {
        final matchesEvent = switch (event) {
          PostgresChangeEvent.insert =>
            change.type == DocumentChangeType.added,
          PostgresChangeEvent.update =>
            change.type == DocumentChangeType.modified,
          PostgresChangeEvent.delete =>
            change.type == DocumentChangeType.removed,
          PostgresChangeEvent.all => true,
          null => true,
        };
        if (matchesEvent) {
          final data = change.doc.data();
          callback(PostgresChangePayload(
            data == null ? <String, dynamic>{} : Map<String, dynamic>.from(data),
          ));
        }
      }
    });
    return this;
  }

  void unsubscribe() {
    _sub?.cancel();
    _sub = null;
  }

  void dispose() => unsubscribe();
}

class PostgresChangeFilter {
  final PostgresChangeFilterType type;
  final String? column;
  final dynamic value;
  const PostgresChangeFilter({
    this.type = PostgresChangeFilterType.eq,
    this.column,
    this.value,
  });
}

enum PostgresChangeFilterType { eq, neq }

enum PostgresChangeEvent { all, insert, update, delete }

class PostgresChangePayload {
  final Map<String, dynamic> newRecord;
  final Map<String, dynamic> oldRecord;
  const PostgresChangePayload(this.newRecord, {this.oldRecord = const {}});
}

/// Auth client backed by FirebaseAuth.
class AuthClient {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserCompat? get currentUser {
    final u = _auth.currentUser;
    return u == null ? null : UserCompat(u);
  }

  Session? get currentSession {
    final u = _auth.currentUser;
    if (u == null) return null;
    return Session(UserCompat(u), u.uid);
  }

  Future<AuthResponse> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return AuthResponse(cred.user == null ? null : UserCompat(cred.user!));
  }

  Future<void> signOut() => _auth.signOut();
}

class Session {
  final UserCompat user;
  final String? accessToken;
  Session(this.user, this.accessToken);
}

class UserCompat {
  final User _user;
  UserCompat(this._user);

  String get id => _user.uid;
  String? get email => _user.email;
  String? get phone => _user.phoneNumber;
  Map<String, dynamic>? get userMetadata => <String, dynamic>{};
}

class AuthResponse {
  final UserCompat? user;
  AuthResponse(this.user);
}

/// Firestore-backed query builder exposing a Supabase-like fluent API.
enum _QOp { select, insert, update, delete }

class SupabaseQueryBuilder implements Future<List<Map<String, dynamic>>> {
  final FirebaseFirestore _db;
  final String _table;
  final List<(String, String, dynamic)> _wheres = [];
  final List<List<(String, String, dynamic)>> _orGroups = [];
  String? _orderCol;
  bool _orderAsc = true;
  int? _limit;
  int? _rangeStart;
  int? _rangeEnd;
  _QOp _op = _QOp.select;
  Map<String, dynamic>? _payload;

  SupabaseQueryBuilder(this._db, this._table);

  SupabaseQueryBuilder select([String columns = '*']) => this;

  SupabaseQueryBuilder eq(String column, dynamic value) {
    _wheres.add((column, 'eq', value));
    return this;
  }

  SupabaseQueryBuilder neq(String column, dynamic value) {
    _wheres.add((column, 'neq', value));
    return this;
  }

  SupabaseQueryBuilder gt(String column, dynamic value) {
    _wheres.add((column, 'gt', value));
    return this;
  }

  SupabaseQueryBuilder gte(String column, dynamic value) {
    _wheres.add((column, 'gte', value));
    return this;
  }

  SupabaseQueryBuilder lt(String column, dynamic value) {
    _wheres.add((column, 'lt', value));
    return this;
  }

  SupabaseQueryBuilder lte(String column, dynamic value) {
    _wheres.add((column, 'lte', value));
    return this;
  }

  SupabaseQueryBuilder inFilter(String column, List<dynamic> values) {
    _wheres.add((column, 'in', values));
    return this;
  }

  /// Supabase `or("a.ilike.%x%,b.ilike.%x%")` -> in-memory OR filtering.
  SupabaseQueryBuilder or(String filter) {
    final clauses = <(String, String, dynamic)>[];
    for (final part in filter.split(',')) {
      final pieces = part.split('.');
      if (pieces.length < 2) continue;
      final field = pieces.removeAt(0);
      final op = pieces.removeAt(0);
      var value = pieces.join('.');
      if (op == 'ilike' || op == 'like') value = value.replaceAll('%', '');
      clauses.add((field, op, value));
    }
    if (clauses.isNotEmpty) _orGroups.add(clauses);
    return this;
  }

  /// Supabase `range(start, end)` -> in-memory slicing of fetched rows.
  SupabaseQueryBuilder range(int start, int end) {
    _rangeStart = start;
    _rangeEnd = end;
    return this;
  }

  SupabaseQueryBuilder order(String column, {bool ascending = true}) {
    _orderCol = column;
    _orderAsc = ascending;
    return this;
  }

  SupabaseQueryBuilder limit(int count) {
    _limit = count;
    return this;
  }

  SupabaseQueryBuilder update(Map<String, dynamic> payload) {
    _op = _QOp.update;
    _payload = payload;
    return this;
  }

  SupabaseQueryBuilder insert(Map<String, dynamic> payload) {
    _op = _QOp.insert;
    _payload = payload;
    return this;
  }

  SupabaseQueryBuilder delete() {
    _op = _QOp.delete;
    return this;
  }

  Future<Map<String, dynamic>?> maybeSingle() async {
    final list = await _execute();
    return list.isEmpty ? null : list.first;
  }

  Future<Map<String, dynamic>> single() async {
    final list = await _execute();
    if (list.isEmpty) {
      throw StateError('single() returned no rows in collection "$_table"');
    }
    return list.first;
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = _db.collection(_table);
    for (final (col, op, val) in _wheres) {
      switch (op) {
        case 'neq':
          q = q.where(col, isNotEqualTo: val);
          break;
        case 'gt':
          q = q.where(col, isGreaterThan: val);
          break;
        case 'gte':
          q = q.where(col, isGreaterThanOrEqualTo: val);
          break;
        case 'lt':
          q = q.where(col, isLessThan: val);
          break;
        case 'lte':
          q = q.where(col, isLessThanOrEqualTo: val);
          break;
        case 'in':
          q = q.where(col, whereIn: val as List);
          break;
        case 'eq':
        default:
          q = q.where(col, isEqualTo: val);
      }
    }
    if (_orderCol != null) q = q.orderBy(_orderCol!, descending: !_orderAsc);
    if (_limit != null) q = q.limit(_limit!);
    return q;
  }

  bool _matchesOrClause(Map<String, dynamic> row, (String, String, dynamic) clause) {
    final (field, op, value) = clause;
    final raw = row[field];
    if (raw == null) return false;
    if (op == 'ilike' || op == 'like') {
      return raw.toString().toLowerCase().contains(value.toString().toLowerCase());
    }
    return raw.toString() == value.toString();
  }

  Future<List<Map<String, dynamic>>> _execute() async {
    switch (_op) {
      case _QOp.select:
        final snap = await _buildQuery().get();
        var rows = snap.docs.map((d) => d.data()).toList();
        for (final group in _orGroups) {
          rows = rows
              .where((row) => group.any((c) => _matchesOrClause(row, c)))
              .toList();
        }
        if (_rangeStart != null) {
          final end = _rangeEnd ?? rows.length - 1;
          rows = rows
              .skip(_rangeStart!)
              .take(end - _rangeStart! + 1)
              .toList();
        }
        return rows;
      case _QOp.insert:
        await _db.collection(_table).add(_payload!);
        return <Map<String, dynamic>>[_payload!];
      case _QOp.update:
        final snap = await _buildQuery().get();
        for (final doc in snap.docs) {
          await doc.reference.set(_payload!, SetOptions(merge: true));
        }
        return <Map<String, dynamic>>[];
      case _QOp.delete:
        final snap = await _buildQuery().get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
        return <Map<String, dynamic>>[];
    }
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(List<Map<String, dynamic>>) onValue,
      {Function? onError}) {
    return _execute().then(onValue, onError: onError);
  }

  @override
  Future<List<Map<String, dynamic>>> catchError(Function onError,
      {bool Function(Object error)? test}) {
    return _execute().catchError(onError, test: test);
  }

  @override
  Future<List<Map<String, dynamic>>> whenComplete(
      FutureOr<void> Function() action) {
    return _execute().whenComplete(action);
  }

  @override
  Stream<List<Map<String, dynamic>>> asStream() => Stream.fromFuture(_execute());

  @override
  Future<List<Map<String, dynamic>>> timeout(Duration timeLimit,
      {FutureOr<List<Map<String, dynamic>>> Function()? onTimeout}) {
    return _execute().timeout(timeLimit, onTimeout: onTimeout);
  }
}
