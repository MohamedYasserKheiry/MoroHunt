import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../models/hunt_catch.dart';
import '../providers/locale_provider.dart';
import '../utils/achievement_badges.dart';

/// Shared photo viewer used by both the map screen and the profile
/// gallery: swipeable (up to 5 photos), touch gesture only — no
/// directional arrow buttons. Forced to RTL so the swipe gesture and
/// page-advance order flow naturally right-to-left, matching the app's
/// global Arabic RTL formatting (swiping from the right edge toward the
/// left reveals the next photo, mirroring how the rest of the app reads).
Future<void> showPhotoSwipeViewer(BuildContext context, List<HuntCatch> group) {
  final capped = group.length > 5 ? group.sublist(0, 5) : group;
  return showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => _PhotoSwipeDialog(photos: capped),
  );
}

class _PhotoSwipeDialog extends ConsumerStatefulWidget {
  final List<HuntCatch> photos;
  const _PhotoSwipeDialog({required this.photos});

  @override
  ConsumerState<_PhotoSwipeDialog> createState() => _PhotoSwipeDialogState();
}

class _PhotoSwipeDialogState extends ConsumerState<_PhotoSwipeDialog> {
  late final PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final language = ref.watch(localeProvider);
    String tr(String key) => AppStrings.translate(key, language);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 380,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: photos.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    if (photo.imageUrl == null || photo.imageUrl!.isEmpty) {
                      // Quick-logged catch with no photo — show a
                      // readable summary card instead of a broken image.
                      return Container(
                        color: const Color(0xFF1C1F1A),
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.pets, size: 48, color: Colors.white54),
                            const SizedBox(height: 12),
                            Text(
                              photo.preyType.label(language),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                            if (photo.weightTier != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                weightTierLabel(photo.weightTier!, language),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                            if (photo.pointsEarned > 0) ...[
                              const SizedBox(height: 6),
                              Text(
                                '+${photo.pointsEarned} ${tr('points_suffix')}',
                                style: const TextStyle(
                                    color: Colors.amberAccent, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      );
                    }
                    return Image.network(
                      photo.imageUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                    );
                  },
                ),
              ),
            ),
            if (photos.length > 1)
              Positioned(
                bottom: 10,
                child: _PageDots(currentPage: _currentPage, count: photos.length),
              ),
            Positioned(
              top: 8,
              left: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int currentPage;
  final int count;

  const _PageDots({required this.currentPage, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == currentPage;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 10 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white38,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
