---
phase: 02-integration
plan: 03
subsystem: sync
tags: [flutter, dart, dio, riverpod, sync-widgets, migration]

# Dependency graph
requires:
  - phase: 02-integration
    plan: 01
    provides: DownloadStatus enum, StatusExtension, DownloadStream without task field
  - phase: 02-integration
    plan: 02
    provides: DioDownloadService, sync_provider.dart rewired, deleteFullSyncFiles single-arg signature

provides:
  - SyncProgressBar with full pause/resume/stop button set using dioDownloadServiceProvider
  - _cancellableStatuses set for canceled/failed/enqueued state button display
  - All 4 UI files verified free of background_downloader and TaskStatus references

affects: [03-cleanup]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SyncProgressBar button pattern: pause shows when not paused/enqueued; resume+stop show when paused; stop shows for cancellable statuses"
    - "Per-download actions use task.id (DownloadStream.id) directly with dioDownloadServiceProvider.notifier"

key-files:
  created: []
  modified:
    - lib/screens/syncing/sync_widgets.dart

key-decisions:
  - "Task 2 files (synced_episode_item.dart, sync_item_details.dart) already fully migrated by Plan 02-02 Rule 3 auto-fix — no changes needed"
  - "SyncProgressBar: pause button shown for running state, stop+resume shown for paused state, stop shown for cancellable states (canceled/failed/enqueued)"

requirements-completed: [INT-03]

# Metrics
duration: 3min
completed: 2026-03-22
---

# Phase 2 Plan 3: UI Widget Migration Summary

**SyncProgressBar extended with full pause/resume/stop button set wired to dioDownloadServiceProvider; all 4 target UI files verified free of background_downloader and TaskStatus**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-22T10:09:50Z
- **Completed:** 2026-03-22T10:12:14Z
- **Tasks:** 2
- **Files modified:** 1 (1 already done, 2 no-op)

## Accomplishments

- `sync_widgets.dart` extended with `_cancellableStatuses` constant and full button set: pause (when running), stop+resume (when paused), stop (when cancellable)
- `dioDownloadServiceProvider.notifier.pauseDownload(task.id)` and `.resumeDownload(task.id)` wired to per-download action buttons
- `sync_options_button.dart`, `synced_episode_item.dart`, `sync_item_details.dart` — all verified clean, no changes required (already migrated by 02-02)

## Task Commits

Each task was committed atomically:

1. **Task 1: Migrate sync_widgets.dart** - `00d0cd4` (feat)
2. **Task 2: synced_episode_item.dart and sync_item_details.dart** - no commit needed (already complete)

## Files Created/Modified

- `lib/screens/syncing/sync_widgets.dart` - Added dio_download_service.dart import, _cancellableStatuses set, full pause/resume/stop button logic in SyncProgressBar

## Decisions Made

- Task 2 files were already fully migrated by Plan 02-02's Rule 3 cascade auto-fix — no duplicate work done
- Pause button uses `!= paused && != enqueued` guard (mirrors original plan spec)
- Per-download pause/resume use `task.id` (the DownloadStream string id) matching DioDownloadService API

## Deviations from Plan

### Task 2 Pre-completed

**[Rule 3 - Pre-existing] Task 2 files already migrated by 02-02**
- **Found during:** Task 2 read
- **Issue:** `synced_episode_item.dart` and `sync_item_details.dart` were already fully migrated in plan 02-02's Rule 3 auto-fix sweep — no `background_downloader` imports, no `TaskStatus`, single-arg `deleteFullSyncFiles`, `DownloadStatus.notFound` present
- **Action:** Verified acceptance criteria pass, skipped no-op commit
- **Impact:** None — plan goal fully achieved

## Issues Encountered

None.

## User Setup Required

None.

## Known Stubs

None — all buttons are fully wired to live DioDownloadService methods.

## Next Phase Readiness

- All 4 UI files are free of background_downloader types
- SyncProgressBar has full pause/resume/stop control via dioDownloadServiceProvider
- Phase 3 cleanup can now safely remove background_download_provider.dart and the background_downloader dependency
- No blockers

---
*Phase: 02-integration*
*Completed: 2026-03-22*
