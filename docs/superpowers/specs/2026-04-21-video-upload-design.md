# Video Upload System — Diseño Técnico
**Fecha:** 2026-04-21
**Proyecto:** Vidalis Mobile (Flutter)
**Enfoque elegido:** B — Flutter + Cloudinary directo, backend como orquestador ligero

---

## Contexto y problema

El flujo actual en `content_screen.dart` tiene tres problemas críticos:
1. No comprime el video antes de subir — un video 4K puede pesar 1–2 GB.
2. Bloquea la UI mientras sube — el usuario no puede navegar la app.
3. No tiene recuperación ante fallos — si se corta la señal, el upload se pierde y hay que empezar desde cero.

---

## Decisiones de diseño

| Decisión | Elección |
|---|---|
| Fuente de video | Galería + Cámara in-app + URL remota |
| Compresión | 1080p optimizado con `video_compress` (reducción ~80%) |
| Upload | Chunks de 6MB resumibles vía Cloudinary Chunked Upload API |
| Recuperación ante fallos | `uploadId` persistido en `SharedPreferences` |
| Feedback de progreso | Banner flotante global en toda la app |
| Notificación | `flutter_local_notifications` al completar |
| Background task | No se usa `workmanager` — el chunked upload de Cloudinary es suficiente y evita restricciones de iOS |

---

## Arquitectura — 3 capas

### Capa 1: Flutter (nueva lógica)

| Componente | Responsabilidad |
|---|---|
| `VideoCompressor` | Comprime video a 1080p antes de subir |
| `ChunkedUploader` | Divide archivo en chunks de 6MB, sube secuencialmente, maneja retry por chunk |
| `UploadQueue` | Estado global de uploads activos/pendientes/fallidos — vive en `AppProvider` |
| `LocalNotifier` | Dispara notificación del sistema al completar |
| `UploadBanner` | Widget flotante en la base del scaffold global — muestra % en tiempo real |
| `VideoSourcePicker` | Unifica las 3 fuentes: galería, cámara, URL remota |

### Capa 2: Backend Node.js (sin cambios de upload)

Los endpoints existentes son suficientes:
- `GET /api/vidalis/cloudinary-signature` — genera firma para upload autenticado (ya existe)
- `POST /api/vidalis/videos` — registra el video en Supabase tras upload (ya existe)
- `PATCH /api/vidalis/videos/:id` — actualiza estado y URL (ya existe)

El backend nunca toca los bytes del video.

### Capa 3: Cloudinary

- Recibe chunks con header `X-Unique-Upload-Id`
- Ensambla el video final cuando llega el último chunk
- Genera URL HLS para streaming y thumbnail automático
- Permite consultar bytes recibidos para reanudar un upload interrumpido

---

## Flujo completo

```
Artista elige fuente
        │
        ├─ Galería → image_picker → File
        ├─ Cámara → camera package → File
        └─ URL remota → skip compresión → URL string
        │
        ▼
VideoCompressor.compress(file, quality: MediumQuality)
  → archivo temporal comprimido (~80% menor)
  → banner aparece: "Preparando video..."
        │
        ▼
GET /api/vidalis/cloudinary-signature
  → { uploadId, signature, timestamp, apiKey, cloudName, folder }
  → uploadId se persiste en SharedPreferences
        │
        ▼
ChunkedUploader.upload(file, sigData)
  → divide en chunks de 6MB
  → POST cada chunk a Cloudinary con X-Unique-Upload-Id
  → banner actualiza: "Subiendo... 34%"
  → si falla un chunk: retry hasta 3 veces con backoff
  → si se pierde señal: connectivity_plus pausa, reanuda al recuperar
        │
        ▼ (último chunk exitoso)
Cloudinary retorna secure_url + public_id
        │
        ▼
POST /api/vidalis/videos
  → { artist_id, source_url: secure_url, title, status: 'analyzing' }
  → backend guarda en Supabase y dispara análisis de IA
        │
        ▼
Banner: "¡Video subido! ✓" (verde, 3 segundos)
LocalNotifier: notificación del sistema
Limpieza: archivo temporal eliminado
SharedPreferences: uploadId eliminado
```

### Flujo de reanudación tras fallo

```
App abre
  → UploadQueue revisa SharedPreferences
  → si existe uploadId pendiente:
      → GET a Cloudinary: ¿cuántos bytes recibiste?
      → ChunkedUploader reanuda desde el chunk siguiente
      → banner reaparece con progreso previo
```

---

## Archivos a crear

| Archivo | Tipo |
|---|---|
| `lib/core/services/video_compressor.dart` | NUEVO |
| `lib/core/services/chunked_uploader.dart` | NUEVO |
| `lib/core/services/upload_queue.dart` | NUEVO |
| `lib/core/services/local_notifier.dart` | NUEVO |
| `lib/shared/widgets/upload_banner.dart` | NUEVO |
| `lib/features/content/video_source_picker.dart` | NUEVO |

## Archivos a modificar

| Archivo | Cambio |
|---|---|
| `lib/features/content/content_screen.dart` | Reemplaza `_pickAndUpload` por `VideoSourcePicker` + `UploadQueue` |
| `lib/core/services/app_provider.dart` | Agrega `UploadQueue uploadQueue` como campo |
| `lib/app.dart` | Envuelve scaffold global con `UploadBanner` |
| `pubspec.yaml` | Agrega 4 paquetes nuevos |

---

## Paquetes nuevos

```yaml
camera: ^0.11.0
video_compress: ^3.1.0
flutter_local_notifications: ^17.0.0
connectivity_plus: ^6.0.0
```

---

## Invariantes críticos

1. El archivo temporal comprimido **siempre** se elimina al terminar, sin importar si el upload fue exitoso o fallido.
2. El `uploadId` en `SharedPreferences` se elimina **solo** al confirmar que el backend registró el video correctamente.
3. El banner es **read-only** — el usuario no puede cancelar un upload desde el banner (evita estado inconsistente con Cloudinary).
4. Para URL remotas, el backend recibe la URL directa y Cloudinary la descarga por su cuenta — Flutter no descarga el video.

---

## Lo que NO cambia

- El backend no procesa ni almacena bytes de video.
- La lógica de análisis de IA en el backend no se toca.
- El `VideoModel` y los endpoints existentes no necesitan cambios de schema.
