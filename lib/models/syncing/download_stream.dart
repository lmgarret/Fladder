import 'package:fladder/models/syncing/download_status.dart';

class DownloadStream {
  final String id;
  final double progress;
  final String downloadSpeed;
  final DownloadStatus status;
  DownloadStream({
    required this.id,
    this.progress = -1,
    this.downloadSpeed = "",
    required this.status,
  });

  DownloadStream.empty()
      : id = '',
        progress = -1,
        downloadSpeed = "",
        status = DownloadStatus.notFound;

  bool get hasDownload => status.isActive || (progress != -1.0 && status != DownloadStatus.notFound && status != DownloadStatus.complete);

  bool get isEnqueuedOrDownloading => status == DownloadStatus.enqueued || status == DownloadStatus.running;

  DownloadStream copyWith({
    String? id,
    double? progress,
    String? downloadSpeed,
    DownloadStatus? status,
  }) {
    return DownloadStream(
      id: id ?? this.id,
      progress: progress ?? this.progress,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'DownloadStream(id: $id, progress: $progress, status: $status)';
  }
}
