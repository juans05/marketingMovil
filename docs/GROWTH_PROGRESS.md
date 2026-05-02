# Growth Pro — Avance de Implementación
**Fecha:** 2026-05-01

---

## ✅ COMPLETADO

### Flutter (vidalis_mobile)

| Archivo | Estado | Descripción |
|---|---|---|
| `lib/core/models/growth_model.dart` | ✅ | Modelos: GrowthInsight, BestTimeData, ContentStrategyItem, ABVariant, ABTestData, AdCopyData, ViralScorePoint |
| `lib/core/constants/api_constants.dart` | ✅ | 7 nuevas constantes de endpoints Growth |
| `lib/core/services/api_service.dart` | ✅ | 7 nuevos métodos: getGrowthInsights, getGrowthBestTime, getGrowthStrategy, getViralHistory, generateABVariants, getABResult, generateAdCopy |
| `lib/features/analytics/analytics_screen.dart` | ✅ | Tabs STATS \| GROWTH ✦ agregados. Muestra GrowthScreen o GrowthLockedView según plan |
| `lib/features/growth/growth_locked_view.dart` | ✅ | Vista upsell: 1 insight gratis real + 4 features bloqueadas + CTA upgrade |
| `lib/features/growth/growth_screen.dart` | ✅ | Hero card (mejor hora) + 6 tiles que navegan a pantallas de detalle |
| `lib/features/growth/screens/ab_testing_screen.dart` | ✅ | Selector de video + 3 variantes A/B con resultado ganador |
| `lib/features/growth/screens/best_time_screen.dart` | ✅ | Hero con hora, heatmap semanal, multiplicador de alcance |
| `lib/features/growth/screens/content_strategy_screen.dart` | ✅ | Lista recomendados vs. evitar con count semanal |
| `lib/features/growth/screens/growth_insights_screen.dart` | ✅ | Cards de patrones detectados con barra de impacto % |
| `lib/features/growth/screens/ad_copy_screen.dart` | ✅ | Selector de video + copy Meta Ads y TikTok Ads copiable |
| `lib/features/growth/screens/viral_score_history_screen.dart` | ✅ | KPIs avg/max + gráfica fl_chart + historial + mejor video |

### Backend (marketingDigitalBackend)

| Archivo | Estado | Descripción |
|---|---|---|
| `src/services/growthService.js` | ✅ | getInsights, getBestTime, getContentStrategy, getViralHistory, generateABVariants, getABResult, generateAdCopy |
| `src/controllers/vidalisController.js` | ✅ | 7 nuevos controllers Growth |
| `src/routes/vidalisRoutes.js` | ✅ | 7 nuevas rutas GET/POST con auth + authorize middleware |

---

## ⚠️ PENDIENTE / POR HACER

### Backend

1. **Migración SQL para tabla `ab_tests`**
   ```sql
   CREATE TABLE ab_tests (
     id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
     video_id uuid REFERENCES videos(id) ON DELETE CASCADE UNIQUE,
     variants jsonb NOT NULL DEFAULT '[]',
     winner_id text,
     is_complete boolean DEFAULT false,
     created_at timestamptz DEFAULT now(),
     updated_at timestamptz DEFAULT now()
   );
   ALTER TABLE ab_tests ENABLE ROW LEVEL SECURITY;
   ```

2. **Lógica para resolver el A/B test a las 24h**
   - Cron job o webhook que compare métricas reales de cada variante
   - Actualiza `winner_id` e `is_complete = true` en `ab_tests`
   - Archivo sugerido: `src/services/abTestResolver.js`

3. **Plan gating en backend**
   - Los endpoints Growth no verifican si el artista tiene plan Growth
   - Agregar check en middleware o en cada service: `if (plan !== 'Estrella' && plan !== 'Agencia Pro') throw 403`

4. **Rate limiting para endpoints Growth**
   - Las llamadas a Claude cuestan dinero — limitar a N calls/día por artista

### Flutter

5. **Hot restart necesario** — ejecutar `R` en la consola de Flutter para ver los cambios

6. **Gating de plan más robusto**
   - Actualmente usa `stats.planName` que puede ser null si no cargaron los stats
   - Considerar agregar `hasGrowthPlan` booleano al `UserModel` o `ArtistModel` desde el backend

7. **Push notifications para A/B results**
   - Cuando el backend resuelve el ganador → notificar al artista
   - Ya existe `local_notifier.dart` — agregar trigger desde `getABResult`

8. **Tests**
   - Ninguna de las pantallas Growth tiene unit tests aún

---

## Arquitectura final

```
AnalyticsScreen
  ├── Tab: STATS (existente, sin cambios)
  └── Tab: GROWTH ✦
        ├── Sin plan → GrowthLockedView (teaser + CTA upgrade)
        └── Con plan → GrowthScreen
              ├── Hero Card (BestTimeData del backend)
              └── 6 Section Tiles →
                    ├── ABTestingScreen
                    ├── BestTimeScreen
                    ├── ContentStrategyScreen
                    ├── GrowthInsightsScreen
                    ├── AdCopyScreen
                    └── ViralScoreHistoryScreen
```

## Plan Gating
- **Con Growth:** `planName == 'Estrella'` o `planName == 'Agencia Pro'`
- **Sin Growth:** `planName == 'Mini'` o `planName == 'Artista'` → ve GrowthLockedView
