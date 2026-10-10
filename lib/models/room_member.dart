/// A single member currently inside a hunt-session room, joined from
/// `session_participants` + `profiles`. [isAdmin] is computed by the
/// caller (comparing [userId] to the session's `creator_id`), not
/// stored — there's exactly one source of truth for who created a
/// room: `hunt_sessions.creator_id`.
class RoomMember {
  final String userId;
  final String username;
  final String? avatarUrl;
  final DateTime joinedAt;
  final bool isAdmin;

  const RoomMember({
    required this.userId,
    required this.username,
    required this.joinedAt,
    required this.isAdmin,
    this.avatarUrl,
  });

  factory RoomMember.fromMap(Map<String, dynamic> map, {required String creatorId}) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    final userId = map['user_id'] as String;
    return RoomMember(
      userId: userId,
      username: profile?['username'] as String? ?? '...',
      avatarUrl: profile?['avatar_url'] as String?,
      joinedAt: DateTime.parse(map['joined_at'] as String),
      isAdmin: userId == creatorId,
    );
  }
}
