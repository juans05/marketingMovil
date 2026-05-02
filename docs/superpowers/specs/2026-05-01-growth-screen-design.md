# Growth Screen — Design Spec
**Date:** 2026-05-01  
**Project:** Vidalis Mobile (Flutter)  
**Status:** Approved

---

## Summary

Add a **Growth Pro** premium tier feature to the Vidalis mobile app. Content creators get AI-powered insights to grow faster: A/B testing, best posting times, content strategy, growth insights, ad copy, and viral score history.

---

## Decisions Made

| Question | Decision |
|---|---|
| Where does it live? | Premium section inside existing **Analítica** screen (tab "GROWTH ✦") |
| Layout when unlocked | **Hero + Lista**: urgent recommendation at top, list of section shortcuts below |
| Upsell state | **Teaser with real data**: show 1 free insight, lock the rest — maximum FOMO |
| Section navigation | Each list item opens a **dedicated full screen** (Navigator.push) |

---

## Sections Included

1. **🧪 A/B Testing de Captions** — 3 caption variants per video, winner declared at 24h
2. **⏰ Mejor Hora para Publicar** — best day/time based on artist's real history
3. **🎯 Estrategia de Contenido** — weekly content plan (types + quantity)
4. **💡 Insights de Crecimiento** — AI-detected patterns from all published videos
5. **📣 Copy para Anuncios Pagados** — Meta Ads + TikTok Ads copy generator
6. **🏆 Viral Score Histórico** — time-series chart of viral score evolution

---

## Screen Architecture

```
AnalyticsScreen
  └── TabBar: [STATS] [GROWTH ✦]
        ├── GrowthLockedView (no plan)   ← teaser with 1 free insight + CTA
        └── GrowthScreen (plan active)
              ├── Hero Card (most urgent recommendation)
              └── List of shortcuts:
                    ├── → ABTestingScreen
                    ├── → BestTimeScreen
                    ├── → ContentStrategyScreen
                    ├── → GrowthInsightsScreen
                    ├── → AdCopyScreen
                    └── → ViralScoreHistoryScreen
```

---

## Design System

- Colors: `AppColors.primary` (#00F2EA cyan), `AppColors.accent` (#E1306C magenta)
- Cards: `AppColors.glassCard(radius: 16)`
- Premium badge: gradient cyan→magenta, label "GROWTH ✦"
- Lock icon: `Icons.lock_rounded`, color `AppColors.accent`
- All screens use existing `AppColors`, `VidalisButton`, `StatCard` widgets

---

## Plan Gating

- Plans that include Growth: **Estrella** and **Agencia Pro** (or new dedicated "Growth" plan)
- Check: `AppProvider.stats.planName` — if not in allowed list → show `GrowthLockedView`
- Free teaser: 1 insight calculated client-side from existing `StatsModel` data

---

## Backend Endpoints Needed

| Endpoint | Purpose |
|---|---|
| `GET /api/vidalis/artists/:id/growth/insights` | AI-detected patterns |
| `GET /api/vidalis/artists/:id/growth/best-time` | Best posting time analysis |
| `GET /api/vidalis/artists/:id/growth/strategy` | Weekly content strategy |
| `POST /api/vidalis/videos/:id/ab-variants` | Generate 3 caption variants |
| `GET /api/vidalis/videos/:id/ab-result` | Get A/B test winner |
| `POST /api/vidalis/videos/:id/ad-copy` | Generate Meta/TikTok ad copy |
| `GET /api/vidalis/artists/:id/growth/viral-history` | Viral score time series |

---

## Flutter Files to Create/Modify

**New files:**
- `lib/features/growth/growth_screen.dart`
- `lib/features/growth/growth_locked_view.dart`
- `lib/features/growth/screens/ab_testing_screen.dart`
- `lib/features/growth/screens/best_time_screen.dart`
- `lib/features/growth/screens/content_strategy_screen.dart`
- `lib/features/growth/screens/growth_insights_screen.dart`
- `lib/features/growth/screens/ad_copy_screen.dart`
- `lib/features/growth/screens/viral_score_history_screen.dart`
- `lib/features/growth/widgets/growth_hero_card.dart`
- `lib/features/growth/widgets/growth_section_tile.dart`

**Modified files:**
- `lib/features/analytics/analytics_screen.dart` — add GROWTH tab
- `lib/core/services/api_service.dart` — add Growth API methods
- `lib/core/services/app_provider.dart` — add growth data + plan gating

---

## Success Criteria

- Creator without Growth plan sees teaser with 1 real insight + upgrade CTA
- Creator with Growth plan sees Hero recommendation + all 6 sections
- Each section loads its own screen with real data from backend
- A/B test winner is highlighted visually after 24h
- All screens match existing dark glassmorphic design system
