import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../models/app_notification.dart';
import '../providers/locale_provider.dart';
import '../services/supabase_service.dart';

/// "مركز الإشعارات" — historical announcements, news, and tournament
/// updates, admin-managed via the `notifications` table (read-only
/// from the client; add rows via the Supabase dashboard).
///
/// NOTE: notification `title`/`body` text comes from database rows,
/// not this file — translating individual announcements requires
/// either multi-language columns in the `notifications` table or
/// separate rows per language, not a code change here. Only this
/// screen's own chrome (header, error, empty state) is localized.
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  late Future<List<AppNotification>> _future;

  String _tr(String key) => AppStrings.translate(key, ref.read(localeProvider));

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.instance.fetchNotifications();
  }

  Future<void> _refresh() async {
    final data = SupabaseService.instance.fetchNotifications();
    setState(() => _future = data);
    await data;
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider); // subscribe so a language change rebuilds this
    return Scaffold(
      appBar: AppBar(title: Text(_tr('notifications_title'))),
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${_tr('error_prefix')}: ${snapshot.error}'));
          }
          final notifications = snapshot.data!;
          if (notifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text(
                        _tr('no_notifications'),
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final n = notifications[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.campaign_outlined,
                                size: 18, color: Colors.greenAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                n.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(n.body, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Text(
                          _formatDate(n.createdAt),
                          style: const TextStyle(fontSize: 11, color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
