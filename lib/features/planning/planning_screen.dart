import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/video_model.dart';
import '../../core/services/app_provider.dart';

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<VideoModel> _allVideos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prov = context.read<AppProvider>();
    final artistId = prov.activeArtist?.id;
    if (artistId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final videos = await prov.api.getGallery(artistId);
      if (mounted) {
        setState(() => _allVideos = videos
            .where((v) => v.scheduledAt != null || v.isPublished)
            .toList());
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<VideoModel> _videosForDay(DateTime day) {
    return _allVideos.where((v) {
      final d = v.scheduledAt ?? v.createdAt;
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();
  }

  bool _hasEvents(DateTime day) => _videosForDay(day).isNotEmpty;

  void _prevMonth() => setState(() {
        _currentMonth =
            DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      });

  void _nextMonth() => setState(() {
        _currentMonth =
            DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      });

  @override
  Widget build(BuildContext context) {
    final selectedVideos = _videosForDay(_selectedDay);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CalendarHeader(
            month: _currentMonth,
            onPrev: _prevMonth,
            onNext: _nextMonth,
          ),
          const SizedBox(height: 12),
          _CalendarGrid(
            month: _currentMonth,
            selectedDay: _selectedDay,
            hasEvents: _hasEvents,
            onDayTap: (day) => setState(() => _selectedDay = day),
          ),
          const SizedBox(height: 20),
          Text(
            DateFormat('d MMMM yyyy', 'es').format(_selectedDay),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(16),
              child:
                  CircularProgressIndicator(color: AppColors.primary),
            ))
          else if (selectedVideos.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppColors.glassCard(),
              child: const Center(
                child: Text('Sin contenido programado para este día',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ),
            )
          else
            ...selectedVideos.map((v) => _ScheduledCard(video: v)),
        ],
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader(
      {required this.month, required this.onPrev, required this.onNext});
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
        ),
        Text(
          DateFormat('MMMM yyyy', 'es').format(month),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.selectedDay,
    required this.hasEvents,
    required this.onDayTap,
  });
  final DateTime month;
  final DateTime selectedDay;
  final bool Function(DateTime) hasEvents;
  final void Function(DateTime) onDayTap;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=Sun

    final cells = <Widget>[];

    // Day labels
    const labels = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    for (final l in labels) {
      cells.add(Center(
        child: Text(l,
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ));
    }

    // Empty cells before first day
    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }

    // Days
    final today = DateTime.now();
    for (int d = 1; d <= daysInMonth; d++) {
      final day = DateTime(month.year, month.month, d);
      final isSelected = day.year == selectedDay.year &&
          day.month == selectedDay.month &&
          day.day == selectedDay.day;
      final isToday = day.year == today.year &&
          day.month == today.month &&
          day.day == today.day;
      final hasEv = hasEvents(day);

      cells.add(GestureDetector(
        onTap: () => onDayTap(day),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? AppColors.primary : Colors.transparent,
            border: isToday && !isSelected
                ? Border.all(color: AppColors.primary)
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Text(
                  d.toString(),
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : isToday
                            ? AppColors.primary
                            : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: isToday || isSelected
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
              if (hasEv)
                Positioned(
                  bottom: 4,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isSelected ? Colors.white : AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppColors.glassCard(),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: cells,
      ),
    );
  }
}

class _ScheduledCard extends StatelessWidget {
  const _ScheduledCard({required this.video});
  final VideoModel video;

  @override
  Widget build(BuildContext context) {
    final date = video.scheduledAt ?? video.createdAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppColors.glassCard(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.video_file,
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title ?? 'Sin título',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('HH:mm').format(date),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: video.isPublished
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              video.isPublished ? 'Publicado' : 'Programado',
              style: TextStyle(
                color: video.isPublished
                    ? AppColors.success
                    : AppColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
