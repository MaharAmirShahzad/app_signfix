import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.api, this.onUnreadChanged});
  final ApiClient api;
  final void Function(int unread)? onUnreadChanged;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchAndNotify();
  }

  Future<List<dynamic>> _fetchAndNotify() async {
    final list = await widget.api.notifications();
    final unread = list.where((n) => n['read'] != true).length;
    if (mounted) widget.onUnreadChanged?.call(unread);
    return list;
  }

  void _reload() {
    final f = _fetchAndNotify();
    if (mounted) setState(() => _future = f);
  }

  Future<void> _markAllRead() async {
    await widget.api.markAllNotificationsRead();
    _reload();
  }

  Future<void> _markRead(String id) async {
    await widget.api.markNotificationRead(id);
    _reload();
  }

  IconData _icon(String? type) {
    switch (type) {
      case 'order':   return Icons.shopping_bag_outlined;
      case 'service': return Icons.build_outlined;
      default:        return Icons.notifications_outlined;
    }
  }

  Color _color(String? type) {
    switch (type) {
      case 'order':   return AppColors.gold;
      case 'service': return AppColors.accent;
      default:        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.navyDeep,
    appBar: AppBar(
      backgroundColor: AppColors.navyDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.gold),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Notifications',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w800)),
      actions: [
        TextButton(
          onPressed: _markAllRead,
          child: const Text('Mark all read',
              style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
    body: FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        }

        final list = snap.data ?? [];
        if (list.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.navyDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.navyLight),
                ),
                child: const Icon(Icons.notifications_none_rounded,
                    size: 48, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              const Text('No notifications yet',
                  style: TextStyle(color: AppColors.textLight, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('We\'ll notify you about your orders\nand service requests here.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center),
            ]),
          );
        }

        final unread = list.where((n) => n['read'] != true).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread count badge
            if (unread > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.gold.withValues(alpha: .3)),
                    ),
                    child: Text('$unread unread',
                        style: const TextStyle(
                            color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  const Spacer(),
                  Text('${list.length} total',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ]),
              ),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final n      = list[i] as Map<String, dynamic>;
                  final isRead = n['read'] == true;
                  final color  = _color(n['type']?.toString());
                  final icon   = _icon(n['type']?.toString());

                  return GestureDetector(
                    onTap: () { if (!isRead) _markRead(n['id'].toString()); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        // ✅ FIX: both read and unread use dark background
                        color: isRead
                            ? AppColors.navyDark
                            : AppColors.navyMid,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isRead
                              ? AppColors.navyLight
                              : color.withValues(alpha: .4),
                          width: isRead ? 1 : 1.5,
                        ),
                        boxShadow: isRead ? [] : [
                          BoxShadow(
                            color: color.withValues(alpha: .1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Icon
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .15),
                            shape: BoxShape.circle,
                            border: Border.all(color: color.withValues(alpha: .3)),
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),

                        // Content
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(
                                child: Text(n['title'] ?? '',
                                    style: TextStyle(
                                      color: AppColors.white,   // ✅ always white
                                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                      fontSize: 14,
                                    )),
                              ),
                              if (!isRead)
                                Container(
                                  width: 8, height: 8,
                                  margin: const EdgeInsets.only(left: 6),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ]),
                            const SizedBox(height: 5),
                            Text(n['body'] ?? '',
                                style: const TextStyle(
                                  color: AppColors.textLight,  // ✅ always textLight
                                  fontSize: 13,
                                  height: 1.4,
                                )),
                            const SizedBox(height: 6),
                            Row(children: [
                              const Icon(Icons.access_time_rounded, size: 11, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(n['createdAt'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted, // ✅ always textMuted
                                  )),
                              if (isRead) ...[
                                const Spacer(),
                                const Icon(Icons.done_all_rounded, size: 13, color: AppColors.success),
                              ],
                            ]),
                          ]),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}
