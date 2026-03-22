# Requirements: Fladder Download Refactor

**Defined:** 2026-03-22
**Core Value:** Media files download reliably regardless of size — no /tmp buffering

## v1 Requirements

### Core Download

- [x] **DL-01**: Downloads stream directly to destination file via dio (no /tmp intermediate buffer)
- [x] **DL-02**: Download progress reported as 0.0-1.0 with speed indicator
- [x] **DL-03**: Individual downloads can be paused and resumed (byte-range)
- [x] **DL-04**: Individual downloads can be cancelled
- [x] **DL-05**: Batch pause-all / resume-all / stop-all operations work
- [x] **DL-06**: Max concurrent downloads respected via queue
- [x] **DL-07**: WiFi-only constraint honored when configured
- [x] **DL-08**: Failed downloads retry up to 3 times

### Integration

- [x] **INT-01**: DownloadStream model uses own DownloadStatus enum (no background_downloader types)
- [ ] **INT-02**: sync_provider.dart uses new download service for all download operations
- [x] **INT-03**: UI files reference new DownloadStatus enum for status checks and icons
- [ ] **INT-04**: Download notifications via flutter_local_notifications

### Cleanup

- [ ] **CLN-01**: background_downloader removed from pubspec.yaml
- [ ] **CLN-02**: background_download_provider.dart removed
- [ ] **CLN-03**: cleanupTemporaryFiles() removed (no longer needed)
- [ ] **CLN-04**: No remaining imports of background_downloader anywhere

## Out of Scope

| Feature | Reason |
|---------|--------|
| Background execution (iOS/Android) | Separate concern, can add workmanager later |
| Streaming subtitles/images via dio | Secondary optimization, http.get is fine for small files |
| UI redesign | Just swap types, keep layout |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DL-01 | Phase 1 | Complete |
| DL-02 | Phase 1 | Complete |
| DL-03 | Phase 1 | Complete |
| DL-04 | Phase 1 | Complete |
| DL-05 | Phase 1 | Complete |
| DL-06 | Phase 1 | Complete |
| DL-07 | Phase 1 | Complete |
| DL-08 | Phase 1 | Complete |
| INT-01 | Phase 2 | Complete |
| INT-02 | Phase 2 | Pending |
| INT-03 | Phase 2 | Complete |
| INT-04 | Phase 2 | Pending |
| CLN-01 | Phase 3 | Pending |
| CLN-02 | Phase 3 | Pending |
| CLN-03 | Phase 3 | Pending |
| CLN-04 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-22*
