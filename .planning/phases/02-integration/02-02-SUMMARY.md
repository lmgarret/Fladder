---
phase: 02-integration
plan: 02
subsystem: sync
tags: [flutter, dart, dio, riverpod, notifications, background-downloader, migration]

# Dependency graph
requires:
  - phase: 01-dio-download-service
    provides: DioDownloadService with enqueue/cancel/pause/resume/pauseAll/resumeAll/cancelAll API
  - phase: 02-integration
    plan: 01
    provides: DownloadStatus enum, DownloadStream without task field, StatusExtension on DownloadStatus

provides:
  - sync_provider.dart using DioDownloadService exclusively for all download operations
  - Progress bridge in SyncNotifier._init() mapping DownloadEntry -> downloadTasksProvider + notifications
  - NotificationService.showDownloadProgress and cancelDownloadNotification for per-file progress
  - Home screen badge reading active count from dioDownloadServiceProvider
  - All syncing UI widgets migrated from TaskStatus to DownloadStatus

affects: [03-cleanup, sync_widgets, notifications, playback]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Progress bridge pattern: ref.listen<Map<String, DownloadEntry>>(dioDownloadServiceProvider) maps entries to downloadTasksProvider + notifications"
    - "Stable notification ID map: _downloadNotifIds ensures no duplicate notifications per taskId"
    - "DioDownloadService pauseAll/resumeAll/cancelAll replace background_downloader batch operations"

key-files:
  created: []
  modified:
    - lib/services/notification_service.dart
    - lib/providers/sync_provider.dart
    - lib/screens/home_screen.dart
    - lib/screens/syncing/sync_widgets.dart
    - lib/screens/syncing/sync_button.dart
    - lib/screens/syncing/sync_list_item.dart
    - lib/screens/syncing/sync_item_details.dart
    - lib/screens/syncing/widgets/sync_options_button.dart
    - lib/screens/syncing/widgets/synced_episode_item.dart
    - lib/screens/syncing/widgets/synced_season_poster.dart
    - lib/screens/settings/client_sections/client_settings_download.dart
    - lib/util/localization_helper.dart
    - lib/models/playback/playback_model.dart

key-decisions:
  - "fileName derived from destinationPath.split('/').last — no extra model field needed for notification title"
  - "Pause/resume/stop buttons in SyncProgressBar simplified: only show stop button when isActive, not guarded by downloadTask != null (task field removed)"
  - "localization_helper.dart updateTranslations call removed — DioDownloadService uses no locale-specific text"

patterns-established:
  - "Type substitution: remove background_downloader import, add download_status.dart, replace TaskStatus -> DownloadStatus throughout"
  - "Terminal state bridge: prev?.status != entry.status guard prevents repeated DownloadStream.empty() updates on already-cleared entries"

requirements-completed: [INT-02, INT-04]

# Metrics
duration: 8min
completed: 2026-03-22
---

# Phase 2 Plan 2: Provider Rewiring and Notification Integration Summary

**sync_provider.dart rewired to DioDownloadService with progress bridge dispatching NotificationService.showDownloadProgress, home screen badge from dioDownloadServiceProvider, all syncing UI widgets migrated from TaskStatus to DownloadStatus**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-22T10:00:58Z
- **Completed:** 2026-03-22T10:08:30Z
- **Tasks:** 3
- **Files modified:** 13

## Accomplishments

- `NotificationService` extended with Android download progress channel (Importance.low, silent), `showDownloadProgress` with stable per-taskId IDs, and `cancelDownloadNotification`
- `SyncNotifier._init()` progress bridge maps every `DownloadEntry` change to `downloadTasksProvider` AND dispatches per-file progress notifications; terminal transitions cancel notifications and clear the stream
- `syncFile()` uses `dioDownloadServiceProvider.notifier.enqueue()` with url+api_key, no DownloadTask construction; `deleteFullSyncFiles()` takes only SyncedItem
- `activeDownloadTasksProvider` and `cleanupTemporaryFiles()` removed entirely
- All `TaskStatus` references in syncing UI and playback model migrated to `DownloadStatus`

## Task Commits

Each task was committed atomically:

1. **Task 1: Add download progress notifications to NotificationService** - `7b88a7e` (feat)
2. **Task 2: Rewire sync_provider.dart** - `aee17a0` (feat)
3. **Task 3: Replace home screen badge + fix all callers** - `5d9c413` (feat)

## Files Created/Modified

- `lib/services/notification_service.dart` - Added _downloadChannelId/Name/GroupKey constants, Android channel registration, showDownloadProgress with stable notifId map, cancelDownloadNotification
- `lib/providers/sync_provider.dart` - Removed background_downloader/activeDownloadTasksProvider/cleanupTemporaryFiles; added dioDownloadServiceProvider progress bridge with notification dispatch; rewrote syncFile/deleteFullSyncFiles/removeSync
- `lib/screens/home_screen.dart` - Badge reads from dioDownloadServiceProvider.select(e.status.isActive)
- `lib/screens/syncing/sync_widgets.dart` - Removed background_downloader; TaskStatus->DownloadStatus; stop button uses isActive instead of downloadTask guard
- `lib/screens/syncing/sync_button.dart` - TaskStatus->DownloadStatus
- `lib/screens/syncing/sync_list_item.dart` - TaskStatus->DownloadStatus
- `lib/screens/syncing/sync_item_details.dart` - TaskStatus->DownloadStatus; removed deleteFullSyncFiles task param
- `lib/screens/syncing/widgets/sync_options_button.dart` - backgroundDownloaderProvider->dioDownloadServiceProvider for pauseAll/resumeAll/cancelAll; TaskStatus->DownloadStatus
- `lib/screens/syncing/widgets/synced_episode_item.dart` - TaskStatus->DownloadStatus; removed deleteFullSyncFiles task param
- `lib/screens/syncing/widgets/synced_season_poster.dart` - TaskStatus->DownloadStatus
- `lib/screens/settings/client_sections/client_settings_download.dart` - backgroundDownloaderProvider.notifier.setMaxConcurrent -> dioDownloadServiceProvider.notifier.setMaxConcurrent
- `lib/util/localization_helper.dart` - Removed backgroundDownloaderProvider.updateTranslations call
- `lib/models/playback/playback_model.dart` - TaskStatus.complete -> DownloadStatus.complete

## Decisions Made

- fileName for notifications derived from `destinationPath.split('/').last` — the file name on disk, no extra field needed
- Stop button in `SyncProgressBar` simplified to show when `downloadStatus.isActive` — the old `downloadTask != null` guard is gone since `DownloadStream.task` was removed in Plan 02-01
- `updateTranslations` removed from localization_helper — background_downloader used this for its own UI strings; DioDownloadService has no such requirement

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed all callers of deleteFullSyncFiles passing removed DownloadTask param**
- **Found during:** Task 3 (home_screen badge replacement)
- **Issue:** Plan changed deleteFullSyncFiles signature but 4 call sites in sync_options_button, synced_episode_item, sync_item_details, sync_widgets still passed the old second argument
- **Fix:** Removed second argument from all call sites; updated sync_widgets.dart button logic
- **Files modified:** sync_options_button.dart, synced_episode_item.dart, sync_item_details.dart, sync_widgets.dart
- **Committed in:** `5d9c413` (Task 3 commit)

**2. [Rule 3 - Blocking] Migrated all remaining TaskStatus references across syncing UI and playback**
- **Found during:** Task 3 verification sweep
- **Issue:** sync_widgets, sync_button, sync_list_item, sync_item_details, synced_season_poster, synced_episode_item, sync_options_button, playback_model all imported background_downloader and used TaskStatus — compile errors
- **Fix:** Replaced TaskStatus->DownloadStatus, background_downloader imports removed, backgroundDownloaderProvider->dioDownloadServiceProvider equivalents
- **Files modified:** 8 files (see list above)
- **Committed in:** `5d9c413` (Task 3 commit)

**3. [Rule 3 - Blocking] Removed backgroundDownloaderProvider from client_settings_download and localization_helper**
- **Found during:** Task 3 verification sweep
- **Issue:** client_settings_download called backgroundDownloaderProvider.notifier.setMaxConcurrent; localization_helper called backgroundDownloaderProvider.notifier.updateTranslations — both compile errors
- **Fix:** client_settings_download switched to dioDownloadServiceProvider.notifier.setMaxConcurrent; localization_helper call removed entirely (DioDownloadService doesn't need locale-specific text)
- **Files modified:** client_settings_download.dart, localization_helper.dart
- **Committed in:** `5d9c413` (Task 3 commit)

---

**Total deviations:** 3 auto-fixed (all Rule 3 - blocking)
**Impact on plan:** All fixes are direct consequences of the new API surface introduced in this plan (removed DownloadTask param, removed TaskStatus). No scope creep — these are the natural callers of the changed API.

## Issues Encountered

None beyond the cascade of compile-blocking callers, all handled via Rule 3.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None — all migrated code is fully wired to DioDownloadService. The pause/resume buttons in SyncProgressBar are temporarily simplified (show only stop when isActive) until a later plan adds per-entry pause/resume UI using dioDownloadServiceProvider.

## Next Phase Readiness

- sync_provider.dart and all syncing UI widgets are now free of background_downloader types
- Progress notifications fire for each active download with per-taskId stable IDs
- Remaining Phase 2 plans can proceed: sync_item.dart model extensions, remaining widget migrations, background_download_provider.dart removal
- No blockers

---
*Phase: 02-integration*
*Completed: 2026-03-22*
