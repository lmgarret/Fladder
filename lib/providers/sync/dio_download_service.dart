import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:fladder/models/syncing/download_status.dart';
import 'package:fladder/providers/connectivity_provider.dart';
import 'package:fladder/providers/settings/client_settings_provider.dart';

part 'dio_download_service.g.dart';

/// Per-download state tracking.
class DownloadEntry {
  final String taskId;
  final String url;
  final String destinationPath;
  final Map<String, String> headers;
  final DownloadStatus status;
  final CancelToken cancelToken;
  final int bytesDownloaded;
  final int retries;
  final double progress;
  final String downloadSpeed;

  DownloadEntry({
    required this.taskId,
    required this.url,
    required this.destinationPath,
    required this.headers,
    required this.status,
    required this.cancelToken,
    this.bytesDownloaded = 0,
    this.retries = 0,
    this.progress = -1.0,
    this.downloadSpeed = '',
  });

  DownloadEntry copyWith({
    DownloadStatus? status,
    CancelToken? cancelToken,
    int? bytesDownloaded,
    int? retries,
    double? progress,
    String? downloadSpeed,
  }) {
    return DownloadEntry(
      taskId: taskId,
      url: url,
      destinationPath: destinationPath,
      headers: headers,
      status: status ?? this.status,
      cancelToken: cancelToken ?? this.cancelToken,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      retries: retries ?? this.retries,
      progress: progress ?? this.progress,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
    );
  }
}

/// Queue item awaiting a concurrent download slot.
class _PendingDownload {
  final String taskId;
  final int startByte;

  _PendingDownload(this.taskId, {this.startByte = 0});
}

/// A self-contained Riverpod notifier that downloads files via dio streaming
/// with progress, pause/resume, cancel, concurrent queue, WiFi constraint, and retry.
///
/// Phase 1: This service is built in isolation — it does not write to
/// downloadTasksProvider or activeDownloadTasksProvider. Those integrations
/// happen in Phase 2.
@Riverpod(keepAlive: true)
class DioDownloadService extends _$DioDownloadService {
  late final Dio _dio;
  final _downloads = <String, DownloadEntry>{};
  final _pendingQueue = <_PendingDownload>[];
  int _activeCount = 0;

  @override
  Map<String, DownloadEntry> build() {
    _dio = Dio();
    ref.listen(connectivityStatusProvider, (_, next) => _onConnectivityChange(next));
    return {};
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Enqueue a download. The download will start immediately if a concurrent
  /// slot is available and WiFi constraints are satisfied.
  Future<void> enqueue({
    required String taskId,
    required String url,
    required String destinationPath,
    required Map<String, String> headers,
  }) async {
    final entry = DownloadEntry(
      taskId: taskId,
      url: url,
      destinationPath: destinationPath,
      headers: headers,
      status: DownloadStatus.enqueued,
      cancelToken: CancelToken(),
    );
    _downloads[taskId] = entry;
    _pendingQueue.add(_PendingDownload(taskId, startByte: 0));
    _tryStartNext();
    _updateState();
  }

  /// Pause an active download. Records bytes on disk for resume.
  void pauseDownload(String taskId) {
    final entry = _downloads[taskId];
    if (entry == null || entry.status != DownloadStatus.running) return;

    final bytesOnDisk = File(entry.destinationPath).existsSync()
        ? File(entry.destinationPath).lengthSync()
        : 0;

    entry.cancelToken.cancel('paused');
    _downloads[taskId] = entry.copyWith(
      status: DownloadStatus.paused,
      bytesDownloaded: bytesOnDisk,
    );
    _activeCount--;
    _tryStartNext();
    _updateState();
  }

  /// Resume a paused download from where it left off using a Range header.
  Future<void> resumeDownload(String taskId) async {
    final entry = _downloads[taskId];
    if (entry == null || entry.status != DownloadStatus.paused) return;

    _pendingQueue.add(_PendingDownload(taskId, startByte: entry.bytesDownloaded));
    _downloads[taskId] = entry.copyWith(status: DownloadStatus.enqueued);
    _tryStartNext();
    _updateState();
  }

  /// Cancel a download. Deletes any partial file on disk.
  void cancelDownload(String taskId) {
    final entry = _downloads[taskId];
    if (entry == null) return;

    if (entry.status == DownloadStatus.running) {
      entry.cancelToken.cancel('cancelled');
      _activeCount--;
    }

    // Remove from pending queue if present
    _pendingQueue.removeWhere((p) => p.taskId == taskId);

    _downloads[taskId] = entry.copyWith(status: DownloadStatus.canceled);

    // Delete partial file
    final file = File(entry.destinationPath);
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {
        // Best-effort cleanup
      }
    }

    _tryStartNext();
    _updateState();
  }

  /// Pause all currently running downloads.
  void pauseAll() {
    final runningIds = _downloads.entries
        .where((e) => e.value.status == DownloadStatus.running)
        .map((e) => e.key)
        .toList();
    for (final taskId in runningIds) {
      pauseDownload(taskId);
    }
  }

  /// Resume all paused downloads.
  void resumeAll() {
    final pausedIds = _downloads.entries
        .where((e) => e.value.status == DownloadStatus.paused)
        .map((e) => e.key)
        .toList();
    for (final taskId in pausedIds) {
      resumeDownload(taskId);
    }
  }

  /// Cancel all non-terminal downloads.
  void cancelAll() {
    final allIds = _downloads.keys.toList();
    for (final taskId in allIds) {
      final entry = _downloads[taskId];
      if (entry != null && !entry.status.isTerminal) {
        cancelDownload(taskId);
      }
    }
  }

  /// Notify service that max concurrent setting changed.
  /// May start queued downloads if limit was increased.
  void setMaxConcurrent(int value) {
    _tryStartNext();
  }

  /// Returns a snapshot of all download statuses, keyed by taskId.
  Map<String, DownloadStatus> get downloadStatuses {
    return {for (final e in _downloads.entries) e.key: e.value.status};
  }

  /// Returns the full entry for a given taskId, or null if not found.
  DownloadEntry? getEntry(String taskId) => _downloads[taskId];

  // ---------------------------------------------------------------------------
  // Private methods
  // ---------------------------------------------------------------------------

  /// Check if a pending download slot is available and start the next one.
  /// Respects concurrent limit and WiFi constraint.
  void _tryStartNext() {
    final maxConcurrent = ref.read(
      clientSettingsProvider.select((s) => s.maxConcurrentDownloads),
    );
    final limit = maxConcurrent == 0 ? 999 : maxConcurrent;

    final requireWifi = ref.read(
      clientSettingsProvider.select((s) => s.requireWifi),
    );
    final connection = ref.read(connectivityStatusProvider);

    // WiFi constraint: if requireWifi is set and we're not on home internet,
    // leave pending items in queue — they'll start when connectivity improves.
    if (requireWifi && !connection.homeInternet) return;

    while (_activeCount < limit && _pendingQueue.isNotEmpty) {
      final next = _pendingQueue.removeAt(0);
      _activeCount++;
      _startDownload(next.taskId, startByte: next.startByte);
    }
  }

  /// Start a download attempt for the given taskId from a byte offset.
  Future<void> _startDownload(String taskId, {int startByte = 0}) async {
    final existingEntry = _downloads[taskId];
    if (existingEntry == null) {
      _activeCount--;
      return;
    }

    // CRITICAL: Always create a fresh CancelToken — cancelled tokens cannot be reused.
    final cancelToken = CancelToken();
    _downloads[taskId] = existingEntry.copyWith(
      status: DownloadStatus.running,
      cancelToken: cancelToken,
    );
    _updateState();

    final entry = _downloads[taskId]!;
    final startTime = DateTime.now();
    int lastReceivedBytes = 0;
    DateTime lastSpeedUpdate = startTime;

    try {
      final response = await _dio.get<ResponseBody>(
        entry.url,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            ...entry.headers,
            if (startByte > 0) 'Range': 'bytes=$startByte-',
          },
        ),
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          final currentEntry = _downloads[taskId];
          if (currentEntry == null) return;

          // Guard against total == -1 (no Content-Length header)
          final totalBytes = total > 0 ? total + startByte : -1;
          final progress = totalBytes > 0
              ? (startByte + received) / totalBytes
              : -1.0;

          // Compute download speed since last callback
          final now = DateTime.now();
          final elapsed = now.difference(lastSpeedUpdate).inMilliseconds;
          final bytesDelta = received - lastReceivedBytes;
          final speed = elapsed > 0
              ? _formatSpeed(bytesDelta / elapsed * 1000)
              : currentEntry.downloadSpeed;
          lastReceivedBytes = received;
          lastSpeedUpdate = now;

          _downloads[taskId] = currentEntry.copyWith(
            progress: progress,
            downloadSpeed: speed,
          );
          _updateState();
        },
      );

      // Stream directly to destination — no /tmp intermediate buffer (DL-01)
      final file = File(entry.destinationPath);
      await file.parent.create(recursive: true);
      final sink = file.openWrite(
        // Must use append mode on resume to avoid overwriting existing bytes
        mode: startByte > 0 ? FileMode.append : FileMode.write,
      );
      await response.data!.stream.pipe(sink);
      await sink.close();

      // Success
      final completedEntry = _downloads[taskId];
      if (completedEntry != null) {
        _downloads[taskId] = completedEntry.copyWith(
          status: DownloadStatus.complete,
          progress: 1.0,
        );
      }
      _activeCount--;
      _tryStartNext();
      _updateState();
    } on DioException catch (e) {
      // CancelToken.isCancel: user-initiated pause or cancel — handled by caller methods
      if (CancelToken.isCancel(e)) return;
      _handleRetryOrFail(taskId);
    } catch (_) {
      _handleRetryOrFail(taskId);
    }
  }

  /// Retry the download up to 3 times, then mark as failed.
  void _handleRetryOrFail(String taskId) {
    final entry = _downloads[taskId];
    if (entry == null) {
      _activeCount--;
      _tryStartNext();
      return;
    }

    if (entry.retries < 3) {
      // Use File.lengthSync() as ground truth, not in-memory byte counter.
      // This handles partial flushes after unexpected termination.
      final bytesOnDisk = File(entry.destinationPath).existsSync()
          ? File(entry.destinationPath).lengthSync()
          : 0;

      _downloads[taskId] = entry.copyWith(
        status: DownloadStatus.enqueued,
        retries: entry.retries + 1,
      );
      _activeCount--;
      // Insert at front of queue for immediate retry
      _pendingQueue.insert(0, _PendingDownload(taskId, startByte: bytesOnDisk));
      _tryStartNext();
    } else {
      _downloads[taskId] = entry.copyWith(status: DownloadStatus.failed);
      _activeCount--;
      _tryStartNext();
    }
    _updateState();
  }

  /// React to connectivity changes — attempt to start pending downloads
  /// when home internet becomes available.
  void _onConnectivityChange(ConnectionState connectionState) {
    if (connectionState.homeInternet) {
      _tryStartNext();
    }
  }

  /// Format bytes/second into a human-readable speed string.
  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '';
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  /// Trigger Riverpod state notification by reassigning state.
  void _updateState() {
    state = Map.of(_downloads);
  }
}
