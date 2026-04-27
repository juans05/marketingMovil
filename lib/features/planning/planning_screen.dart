import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/video_model.dart';
import '../../core/services/app_provider.dart';
import '../../core/services/api_service.dart';

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
        setState(() => _allVideos = videos);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<VideoModel> _videosForDay(DateTime day) {
    return _allVideos.where((v) {
      final d = v.scheduledAt ?? (v.isPublished ? v.createdAt : null);
      if (d == null) return false;
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();
  }

  bool _hasEvents(DateTime day) => _videosForDay(day).isNotEmpty;

  void _prevMonth() => setState(() {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      });

  void _nextMonth() => setState(() {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      });

  // Videos "listos" que aún no han sido programados y están disponibles para asignar
  List<VideoModel> get _readyVideos =>
      _allVideos.where((v) => v.isReady).toList();

  Future<void> _openScheduleSheet(DateTime day) async {
    // Videos ya programados para ese día (para mostrárselos)
    final dayVideos = _videosForDay(day);
    final prov = context.read<AppProvider>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ScheduleSheet(
        date: day,
        scheduledVideos: dayVideos,
        readyVideos: _readyVideos,
        allVideos: _allVideos,
        artistId: prov.activeArtist?.id ?? '',
        api: prov.api,
        activePlatforms: prov.activeArtist?.activePlatforms ?? [],
        onSaved: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedVideos = _videosForDay(_selectedDay);
    final isPast = _selectedDay.isBefore(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    );

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
            onDayTap: (day) {
              setState(() => _selectedDay = day);
              _openScheduleSheet(day);
            },
          ),
          const SizedBox(height: 20),

          // Encabezado del día seleccionado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('d MMMM yyyy', 'es').format(_selectedDay),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!isPast)
                TextButton.icon(
                  onPressed: () => _openScheduleSheet(_selectedDay),
                  icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                  label: const Text('Programar',
                      style: TextStyle(color: AppColors.primary, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (_loading)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppColors.primary),
            ))
          else if (selectedVideos.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: AppColors.glassCard(),
              child: Column(
                children: [
                  const Icon(Icons.event_available_outlined,
                      color: AppColors.textMuted, size: 40),
                  const SizedBox(height: 10),
                  const Text('Sin contenido programado',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  if (!isPast) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => _openScheduleSheet(_selectedDay),
                      child: const Text('+ Agregar publicación',
                          style: TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ],
              ),
            )
          else
            ...selectedVideos.map((v) => _ScheduledCard(video: v)),
        ],
      ),
    );
  }
}

// ─── Schedule Bottom Sheet ─────────────────────────────────────────────────────

class ScheduleSheet extends StatefulWidget {
  const ScheduleSheet({
    super.key,
    required this.date,
    required this.scheduledVideos,
    required this.readyVideos,
    required this.allVideos,
    required this.artistId,
    required this.api,
    required this.onSaved,
    required this.activePlatforms,
    this.preselectedVideo,
  });

  final DateTime date;
  final List<VideoModel> scheduledVideos;
  final List<VideoModel> readyVideos;
  final List<VideoModel> allVideos;
  final String artistId;
  final ApiService api;
  final VoidCallback onSaved;
  final List<String> activePlatforms;
  final VideoModel? preselectedVideo;

  @override
  State<ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<ScheduleSheet> {
  VideoModel? _selectedVideo;
  String _format = 'Reel';
  TimeOfDay _time = TimeOfDay.now();
  final Set<String> _platforms = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedVideo = widget.preselectedVideo;

    // Inicializar con la primera plataforma disponible
    if (widget.activePlatforms.isNotEmpty) {
      if (widget.activePlatforms.contains('instagram')) {
        _platforms.add('instagram');
      } else {
        _platforms.add(widget.activePlatforms.first);
      }
    }
  }

  List<VideoModel> get _dropdownVideos {
    final list = List<VideoModel>.from(widget.readyVideos);
    final pre = widget.preselectedVideo;
    if (pre != null && !list.any((v) => v.id == pre.id)) {
      list.insert(0, pre);
    }
    return list;
  }

  static const _formats = ['Reel', 'Story', 'Post', 'TikTok', 'YouTube Short'];
  static const _platformOptions = [
    ('instagram', '📸 Instagram'),
    ('tiktok', '🎵 TikTok'),
    ('youtube', '▶️ YouTube'),
    ('twitter', '𝕏 Twitter/X'),
    ('facebook', '👤 Facebook'),
  ];

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.bgCard,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (_selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un video primero'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final scheduledDt = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      _time.hour,
      _time.minute,
    );

    try {
      await widget.api.scheduleVideo(
        videoId: _selectedVideo!.id,
        scheduledAt: scheduledDt,
        platforms: _platforms.toList(),
        format: _format,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Programado para el ${DateFormat('d MMM', 'es').format(scheduledDt)} a las ${_time.format(context)}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE d MMMM', 'es').format(widget.date);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary, // Opaque background
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Título
            Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Programar para el $dateStr',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── 1. Seleccionar video ──────────────────────────────
            const _SectionLabel(icon: Icons.video_library_outlined, text: 'Video a publicar'),
            const SizedBox(height: 8),

            if (_dropdownVideos.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.warning, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No tienes videos listos. Sube y analiza un video primero.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedVideo != null ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: DropdownButton<VideoModel>(
                  value: _selectedVideo,
                  hint: const Text('Selecciona un video',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  isExpanded: true,
                  dropdownColor: AppColors.bgCard,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.expand_more, color: AppColors.textMuted),
                  items: _dropdownVideos.map((v) {
                    return DropdownMenuItem(
                      value: v,
                      child: Row(
                        children: [
                          const Icon(Icons.video_file, color: AppColors.primary, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              v.title ?? 'Sin título',
                              style: const TextStyle(
                                  color: AppColors.textPrimary, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedVideo = v),
                ),
              ),
            const SizedBox(height: 20),

            // ── 2. Formato ────────────────────────────────────────
            const _SectionLabel(icon: Icons.auto_awesome_outlined, text: 'Formato de publicación'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _formats.map((f) {
                final selected = f == _format;
                return GestureDetector(
                  onTap: () => setState(() => _format = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        color: selected ? AppColors.primary : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── 3. Hora ───────────────────────────────────────────
            const _SectionLabel(icon: Icons.access_time_outlined, text: 'Hora de publicación'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _time.format(context),
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    const Text('Cambiar',
                        style: TextStyle(color: AppColors.primary, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── 4. Plataformas ────────────────────────────────────
            const _SectionLabel(icon: Icons.share_outlined, text: 'Plataformas'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _platformOptions
                  .where((p) => widget.activePlatforms.contains(p.$1))
                  .map((p) {
                final (id, label) = p;
                final selected = _platforms.contains(id);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _platforms.remove(id);
                    } else {
                      _platforms.add(id);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accent.withValues(alpha: 0.12)
                          : AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppColors.accent : AppColors.border,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected ? AppColors.accent : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // ── Botón guardar ─────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.calendar_month, color: Colors.white),
                label: Text(
                  _saving ? 'Guardando...' : 'Guardar programación',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 14),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3),
        ),
      ],
    );
  }
}

// ─── Calendar Header ──────────────────────────────────────────────────────────

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

// ─── Calendar Grid ────────────────────────────────────────────────────────────

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
    final startWeekday = firstDay.weekday % 7;

    final cells = <Widget>[];

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

    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }

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
                      color: isSelected ? Colors.white : AppColors.accent,
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

// ─── Scheduled Card ───────────────────────────────────────────────────────────

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
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: video.thumbnailUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(video.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                            Icons.video_file,
                            color: AppColors.primary,
                            size: 24)),
                  )
                : const Icon(Icons.video_file,
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
                Row(
                  children: [
                    const Icon(Icons.schedule,
                        color: AppColors.textMuted, size: 11),
                    const SizedBox(width: 3),
                    Text(
                      DateFormat('HH:mm').format(date),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                    if (video.platforms.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        video.platforms.map((p) => _platformEmoji(p)).join(' '),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: video.isPublished
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              video.isPublished ? 'Publicado' : 'Programado',
              style: TextStyle(
                color: video.isPublished ? AppColors.success : AppColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _platformEmoji(String p) {
    switch (p) {
      case 'instagram': return '📸';
      case 'tiktok': return '🎵';
      case 'youtube': return '▶️';
      case 'twitter': return '𝕏';
      case 'facebook': return '👤';
      default: return '🔗';
    }
  }
}
