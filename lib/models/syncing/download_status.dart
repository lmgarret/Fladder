/// Download status enum decoupled from background_downloader's TaskStatus.
/// Values intentionally parallel TaskStatus for minimal Phase 2 migration diff.
enum DownloadStatus {
  notFound,
  enqueued,
  running,
  paused,
  complete,
  failed,
  canceled;

  /// True when the download is actively queued or transferring.
  bool get isActive => this == running || this == enqueued;

  /// True when the download has reached a terminal state.
  bool get isTerminal => this == complete || this == canceled || this == failed;

  /// True when there is a meaningful download in progress (mirrors DownloadStream.hasDownload).
  bool get hasDownload => this != notFound && this != complete;
}
