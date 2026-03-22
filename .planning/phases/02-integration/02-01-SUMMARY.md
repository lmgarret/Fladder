---
phase: 02-integration
plan: 01
subsystem: sync
tags: [flutter, dart, download-status, background-downloader, migration]

# Dependency graph
requires:
  - phase: 01-dio-download-service
    provides: DownloadStatus enum in lib/models/syncing/download_status.dart
provides:
  - DownloadStream model using DownloadStatus exclusively (no background_downloader)
  - StatusExtension on DownloadStatus with icon/color/name for all 7 enum values
  - SyncedItem.status and anyStatus getters returning DownloadStatus
  - SyncDownloadStatus helper using DownloadStatus comparisons throughout
affects: [02-integration, 03-cleanup, sync_provider, sync_widgets, notifications]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "DownloadStatus enum as sole status type — no background_downloader types in model layer"
    - "StatusExtension on DownloadStatus for UI icon/color/localized name lookup"

key-files:
  created: []
  modified:
    - lib/models/syncing/download_stream.dart
    - lib/models/syncing/sync_item.dart
    - lib/providers/sync/sync_provider_helpers.dart

key-decisions:
  - "waitingToRetry case removed from StatusExtension — retries handled internally in DioDownloadService, status stays enqueued"
  - "DownloadStream.task field removed — UI only needs taskId, full DownloadTask object no longer required in stream"

patterns-established:
  - "Type substitution pattern: remove background_downloader import, add download_status.dart import, replace all dl.TaskStatus/TaskStatus references with DownloadStatus"

requirements-completed: [INT-01, INT-03]

# Metrics
duration: 2min
completed: 2026-03-22
---

# Phase 2 Plan 1: Core Model Migration Summary

**Three sync model/helper files migrated from background_downloader TaskStatus to own DownloadStatus enum — DownloadStream.task field removed, StatusExtension rewritten for 7 enum values without waitingToRetry**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-22T09:57:48Z
- **Completed:** 2026-03-22T09:59:10Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- `DownloadStream` fully decoupled from background_downloader: `task` field removed, `status` now `DownloadStatus`
- `SyncedItem.status`, `anyStatus`, and `StatusExtension` now operate on `DownloadStatus` with 7 enum values
- `SyncDownloadStatus.build()` in sync_provider_helpers uses `DownloadStatus.running` and `DownloadStatus.complete` instead of `TaskStatus`

## Task Commits

Each task was committed atomically:

1. **Task 1: Migrate DownloadStream model to DownloadStatus** - `312c0f3` (feat)
2. **Task 2: Migrate sync_item.dart StatusExtension and SyncedItem getters to DownloadStatus** - `c65e3ce` (feat)
3. **Task 3: Migrate sync_provider_helpers.dart to DownloadStatus** - `e067967` (feat)

## Files Created/Modified

- `lib/models/syncing/download_stream.dart` - Replaced background_downloader import with download_status.dart; removed task field and dl.TaskStatus; uses DownloadStatus throughout
- `lib/models/syncing/sync_item.dart` - Replaced background_downloader import; updated status/anyStatus getters; rewrote StatusExtension on DownloadStatus (7 values, no waitingToRetry)
- `lib/providers/sync/sync_provider_helpers.dart` - Replaced background_downloader import; replaced TaskStatus.running and TaskStatus.complete with DownloadStatus equivalents

## Decisions Made

- `waitingToRetry` case removed from all three switch expressions in StatusExtension — DioDownloadService handles retries internally and surfaces status as `enqueued` while retrying
- `DownloadStream.task` field removed entirely — downstream UI code only needs the string `taskId`, passing a full `DownloadTask` object through the stream is unnecessary coupling

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Core model/helper layer is fully free of background_downloader types in these three files
- Remaining Phase 2 plans can now migrate sync_provider.dart, UI widgets, and notifications using DownloadStatus as the canonical type
- No blockers

---
*Phase: 02-integration*
*Completed: 2026-03-22*
