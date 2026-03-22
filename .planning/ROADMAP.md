# Roadmap: Fladder Download Refactor

**Created:** 2026-03-22
**Milestone:** v1.0 — Replace background_downloader with dio streaming
**Phases:** 3
**Requirements covered:** 16/16

## Phase Overview

| # | Phase | Goal | Requirements | Success Criteria |
|---|-------|------|--------------|------------------|
| 1 | Dio Download Service | 2/2 | Complete   | 2026-03-22 |
| 2 | Integration | Swap sync_provider and UI to use new service | INT-01 through INT-04 | 4 |
| 3 | Cleanup | Remove background_downloader entirely | CLN-01 through CLN-04 | 4 |

## Phase 1: Dio Download Service

**Goal:** Create a self-contained dio-based download service that streams files directly to destination with progress, pause/resume, cancel, queue, and retry support.

**Requirements:** DL-01, DL-02, DL-03, DL-04, DL-05, DL-06, DL-07, DL-08

**Plans:** 2/2 plans complete

Plans:
- [x] 01-01-PLAN.md — Add dio dependency and create DownloadStatus enum
- [x] 01-02-PLAN.md — Build DioDownloadService with streaming, queue, pause/resume, retry

**Success Criteria:**
1. A DioDownloadService provider exists that can download a URL to a file path using dio streaming (no /tmp)
2. Progress callbacks emit 0.0-1.0 progress with download speed
3. Pause stores bytes-downloaded, resume sends Range header to continue
4. Concurrent download queue limits active downloads to configured max

**Key files to create:**
- `lib/models/syncing/download_status.dart` — own DownloadStatus enum
- `lib/providers/sync/dio_download_service.dart` — the new download engine

**Key files to modify:**
- `pubspec.yaml` — add dio dependency

## Phase 2: Integration

**Goal:** Replace all background_downloader usage in sync_provider and UI with the new dio download service. All existing download UX preserved.

**Requirements:** INT-01, INT-02, INT-03, INT-04

**Success Criteria:**
1. DownloadStream model uses DownloadStatus enum instead of dl.TaskStatus
2. sync_provider.dart calls DioDownloadService for download/cancel operations
3. All UI files compile with new status types and show correct icons/states
4. Download notifications show via flutter_local_notifications

**Key files to modify:**
- `lib/models/syncing/download_stream.dart` — remove background_downloader import, use own types
- `lib/providers/sync_provider.dart` — swap backgroundDownloaderProvider → dioDownloadService
- `lib/screens/syncing/sync_widgets.dart` — swap TaskStatus references
- `lib/screens/syncing/widgets/sync_options_button.dart` — swap TaskStatus references
- `lib/models/syncing/sync_item.dart` — swap TaskStatus references
- `lib/providers/sync/background_download_provider.dart` — keep temporarily for compilation

## Phase 3: Cleanup

**Goal:** Remove all traces of background_downloader from the codebase. No remaining imports, no temp file cleanup code.

**Requirements:** CLN-01, CLN-02, CLN-03, CLN-04

**Success Criteria:**
1. `background_downloader` removed from pubspec.yaml
2. `lib/providers/sync/background_download_provider.dart` and `.g.dart` deleted
3. `cleanupTemporaryFiles()` removed from sync_provider.dart
4. `grep -r background_downloader lib/` returns zero results

**Key files to modify/delete:**
- `pubspec.yaml` — remove background_downloader
- `lib/providers/sync/background_download_provider.dart` — delete
- `lib/providers/sync/background_download_provider.g.dart` — delete
- `lib/providers/sync_provider.dart` — remove cleanupTemporaryFiles(), remove import
- `lib/screens/home_screen.dart` — remove any background_downloader references

---
*Roadmap created: 2026-03-22*
