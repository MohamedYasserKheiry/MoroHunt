import 'package:flutter/material.dart';

import '../models/room_member.dart';
import '../services/supabase_service.dart';

/// Room members sidebar (opened as a Scaffold `endDrawer`). Shows the
/// live online count at the top, the admin pinned first with a crown
/// badge, and — only when the CURRENT user is the admin — a kick
/// button next to every other member.
///
/// Stateful specifically so it can force a fresh fetch in [initState]
/// — this is a second layer of defense alongside the icon button's own
/// refresh trigger, since an `endDrawer` can also be opened via an
/// edge-swipe gesture on touch devices, bypassing that button's
/// `onPressed` entirely.
class RoomMembersDrawer extends StatefulWidget {
  final String sessionId;
  final List<RoomMember> members;
  final bool isCurrentUserAdmin;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const RoomMembersDrawer({
    super.key,
    required this.sessionId,
    required this.members,
    required this.isCurrentUserAdmin,
    this.errorMessage,
    this.onRetry,
  });

  @override
  State<RoomMembersDrawer> createState() => _RoomMembersDrawerState();
}

class _RoomMembersDrawerState extends State<RoomMembersDrawer> {
  @override
  void initState() {
    super.initState();
    SupabaseService.instance.refreshRoomMembersNow(widget.sessionId);
  }

  Future<void> _confirmKick(BuildContext context, RoomMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طرد العضو'),
        content: Text('هل أنت متأكد أنك تريد طرد ${member.username} من الغرفة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('طرد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await SupabaseService.instance.kickMember(
        sessionId: widget.sessionId,
        userId: member.userId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم طرد ${member.username} من الغرفة')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر طرد العضو: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF15170F),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.groups, color: Color(0xFF66BB6A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.members.length} أعضاء متصلون',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  if (widget.onRetry != null)
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'تحديث القائمة',
                      onPressed: () {
                        widget.onRetry!();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'session_id: ${widget.sessionId}\nنتيجة آخر تحميل: ${widget.members.length} عضو'
                              '${widget.errorMessage != null ? '\nخطأ: ${widget.errorMessage}' : ''}',
                            ),
                            duration: const Duration(seconds: 6),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            // Always-visible debug line — shows exactly what this
            // screen believes the active session_id is and how many
            // rows the last fetch returned, so this can be diagnosed
            // directly from a screenshot with no DevTools needed.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'session_id: ${widget.sessionId}\nآخر تحميل: ${widget.members.length} صف',
                style: const TextStyle(fontSize: 9, color: Colors.white24),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: widget.errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.redAccent, size: 32),
                            const SizedBox(height: 12),
                            Text(
                              'تعذر تحميل قائمة الأعضاء',
                              style: const TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.errorMessage!,
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: widget.onRetry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : widget.members.isEmpty
                      ? const Center(
                          child: Text('لا يوجد أعضاء بعد',
                              style: TextStyle(color: Colors.white54)),
                        )
                      : ListView.builder(
                      itemCount: widget.members.length,
                      itemBuilder: (context, index) {
                        final member = widget.members[index];
                        final canKick = widget.isCurrentUserAdmin && !member.isAdmin;

                        return ListTile(
                          leading: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: member.avatarUrl != null
                                    ? NetworkImage(member.avatarUrl!)
                                    : null,
                                child: member.avatarUrl == null
                                    ? Text(member.username.isNotEmpty
                                        ? member.username[0].toUpperCase()
                                        : '?')
                                    : null,
                              ),
                              if (member.isAdmin)
                                const Positioned(
                                  top: -6,
                                  right: -2,
                                  child: Text('👑', style: TextStyle(fontSize: 16)),
                                ),
                            ],
                          ),
                          title: Text(
                            member.username,
                            style: TextStyle(
                              fontWeight:
                                  member.isAdmin ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: member.isAdmin
                              ? const Text('المشرف / منشئ الغرفة',
                                  style: TextStyle(fontSize: 11, color: Colors.amberAccent))
                              : null,
                          trailing: canKick
                              ? IconButton(
                                  icon: const Icon(Icons.person_remove_outlined,
                                      color: Colors.redAccent),
                                  tooltip: 'طرد',
                                  onPressed: () => _confirmKick(context, member),
                                )
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
