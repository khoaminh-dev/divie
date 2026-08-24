import 'package:supabase_flutter/supabase_flutter.dart';

class CareRecipient {
  const CareRecipient({
    required this.relationshipId,
    required this.elderId,
    required this.name,
    required this.phone,
  });

  final String relationshipId;
  final String elderId;
  final String name;
  final String phone;
}

class CareInvitation {
  const CareInvitation({
    required this.relationshipId,
    required this.caregiverId,
    required this.name,
    required this.phone,
  });

  final String relationshipId;
  final String caregiverId;
  final String name;
  final String phone;
}

/// Owns the explicit, accepted relationship between two DiVie accounts.
/// The database RPCs enforce that an elder accepts before a caregiver receives
/// access to health and reminder data.
class CareRelationshipService {
  CareRelationshipService(this.client);

  final SupabaseClient client;

  Future<List<CareRecipient>> loadRecipients() async {
    final rows = await client.rpc('list_divie_care_recipients');
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => CareRecipient(
            relationshipId: row['relationship_id']?.toString() ?? '',
            elderId: row['elder_id']?.toString() ?? '',
            name: _name(row['full_name']),
            phone: _string(row['phone_number']),
          ),
        )
        .where(
          (item) => item.relationshipId.isNotEmpty && item.elderId.isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<List<CareInvitation>> loadInvitations() async {
    final rows = await client.rpc('list_divie_care_invitations');
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => CareInvitation(
            relationshipId: row['relationship_id']?.toString() ?? '',
            caregiverId: row['caregiver_id']?.toString() ?? '',
            name: _name(row['full_name']),
            phone: _string(row['phone_number']),
          ),
        )
        .where((item) => item.relationshipId.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> requestByPhone(String phone) async {
    await client.rpc(
      'request_divie_care_connection',
      params: {'target_phone': phone},
    );
  }

  Future<void> respond({
    required String relationshipId,
    required bool accept,
  }) async {
    await client.rpc(
      'respond_divie_care_connection',
      params: {'relationship_id': relationshipId, 'accept_request': accept},
    );
  }

  static String _string(Object? value) => value is String ? value.trim() : '';

  static String _name(Object? value) {
    final name = _string(value);
    return name.isEmpty ? 'Người dùng DiVie' : name;
  }
}
