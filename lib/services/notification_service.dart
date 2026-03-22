import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:fladder/models/notification_model.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const String _channelId = 'fladder_updates';
  static const String _channelName = 'Update notifications';
  static const String _channelDesc = 'Notifications for newly added items';

  static const String _downloadChannelId = 'fladder_downloads';
  static const String _downloadChannelName = 'Download progress';
  static const String _downloadGroupKey = 'fladder_download_group';

  static final StreamController<String?> _selectNotificationController = StreamController<String?>.broadcast();
  static Stream<String?> get notificationTapStream => _selectNotificationController.stream;

  @pragma('vm:entry-point')
  static void _backgroundNotificationHandler(NotificationResponse resp) {
    _selectNotificationController.add(resp.payload);
  }

  static Future<void> init() async {
    if (kIsWeb) return;

    const android = AndroidInitializationSettings('ic_notification');
    final darwin = const DarwinInitializationSettings();
    final linux = const LinuxInitializationSettings(defaultActionName: 'Open notification');
    final windows = const WindowsInitializationSettings(
      appName: 'Fladder',
      appUserModelId: 'nl.jknaapen.fladder',
      guid: 'd49b0314-ee7a-4626-bf79-97cdb8a991bb',
    );

    await _plugin.initialize(
      settings: InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
        linux: linux,
        windows: windows,
      ),
      onDidReceiveNotificationResponse: (NotificationResponse resp) {
        _selectNotificationController.add(resp.payload);
      },
      onDidReceiveBackgroundNotificationResponse: _notificationBackgroundEntryPoint,
    );

    if (!kIsWeb && Platform.isAndroid) {
      final channel = const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.defaultImportance,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      final downloadChannel = const AndroidNotificationChannel(
        _downloadChannelId,
        _downloadChannelName,
        description: 'Shows progress for file downloads',
        importance: Importance.low,
        showBadge: false,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(downloadChannel);
    }
  }

  static Future<String?> getInitialNotificationPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.notificationResponse?.payload;
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (status.isGranted) return true;
      final res = await Permission.notification.request();
      return res.isGranted;
    }

    if (Platform.isIOS || Platform.isMacOS) {
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final result = await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? true;
    }

    if (Platform.isLinux || Platform.isWindows) {
      return true;
    }

    return false;
  }

  static Future<void> showNewItemsNotification(String title, String body) async {
    final androidDetails = const AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails();
    final linuxDetails = const LinuxNotificationDetails(defaultActionName: 'Open notification');
    final windowsDetails = const WindowsNotificationDetails();

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        linux: linuxDetails,
        windows: windowsDetails,
      ),
    );
  }

  static Future<void> showGroupedNotifications(
    String groupId,
    String groupTitle,
    List<NotificationModel> notifications,
    String? summaryText,
  ) async {
    if (notifications.isEmpty) return;

    final baseId = DateTime.now().millisecond;
    final groupKey = 'fladder_group_$groupId';

    if (notifications.length == 1) {
      final single = notifications.first;

      final androidSummary = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        styleInformation: InboxStyleInformation(
          [single.subtitle ?? single.title],
          contentTitle: single.title,
          summaryText: summaryText ?? '${notifications.length} new item',
        ),
        subText: (summaryText?.isNotEmpty == true) ? summaryText : groupTitle,
        groupKey: groupKey,
        setAsGroupSummary: true,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        groupAlertBehavior: GroupAlertBehavior.summary,
      );

      final iosSummary = DarwinNotificationDetails(threadIdentifier: groupKey);
      final linuxSummary = const LinuxNotificationDetails(defaultActionName: 'Open notification');
      final windowsSummary = const WindowsNotificationDetails();

      await _plugin.show(
        id: baseId,
        title: single.title,
        body: (summaryText?.isNotEmpty == true)
            ? ((single.subtitle?.isNotEmpty == true) ? '${single.subtitle}' : summaryText!)
            : (single.subtitle ?? ''),
        payload: single.payLoad,
        notificationDetails: NotificationDetails(
          android: androidSummary,
          iOS: iosSummary,
          linux: linuxSummary,
          windows: windowsSummary,
        ),
      );

      return;
    }

    final futures = <Future<void>>[];
    for (var i = 0; i < notifications.length; i++) {
      final childId = baseId + 1 + i;
      final notification = notifications[i];
      final androidChild = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        groupKey: groupKey,
        groupAlertBehavior: GroupAlertBehavior.summary,
      );
      final iosChild = DarwinNotificationDetails(threadIdentifier: groupKey);
      final linuxChild = const LinuxNotificationDetails(defaultActionName: 'Open notification');
      final windowsChild = const WindowsNotificationDetails();
      futures.add(_plugin.show(
        id: childId,
        title: notification.title,
        body: notification.subtitle,
        payload: notification.payLoad,
        notificationDetails: NotificationDetails(
          android: androidChild,
          iOS: iosChild,
          linux: linuxChild,
          windows: windowsChild,
        ),
      ));
    }

    await Future.wait(futures);

    final androidSummary = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      styleInformation: InboxStyleInformation(
        notifications.map((n) => n.title).toList(),
        contentTitle: groupTitle,
        summaryText: summaryText ?? '${notifications.length} new items',
      ),
      groupKey: groupKey,
      setAsGroupSummary: true,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      groupAlertBehavior: GroupAlertBehavior.summary,
    );

    final iosSummary = DarwinNotificationDetails(threadIdentifier: groupKey);
    final linuxSummary = const LinuxNotificationDetails(defaultActionName: 'Open notification');
    final windowsSummary = const WindowsNotificationDetails();

    await _plugin.show(
      id: baseId,
      title: groupTitle,
      body: summaryText ?? '${notifications.length} new item(s)',
      notificationDetails: NotificationDetails(
        android: androidSummary,
        iOS: iosSummary,
        linux: linuxSummary,
        windows: windowsSummary,
      ),
    );
  }
  /// Stable notification ID map to avoid duplicates per taskId.
  static final Map<String, int> _downloadNotifIds = {};
  static int _nextDownloadNotifId = 90000;

  /// Show or update a download progress notification for a specific file.
  /// [progress] should be 0-100. Call with negative progress to show indeterminate.
  static Future<void> showDownloadProgress({
    required String taskId,
    required String fileName,
    required int progress,
  }) async {
    if (kIsWeb) return;

    final notifId = _downloadNotifIds.putIfAbsent(taskId, () => _nextDownloadNotifId++);

    final androidDetails = AndroidNotificationDetails(
      _downloadChannelId,
      _downloadChannelName,
      channelShowBadge: false,
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: progress.clamp(0, 100),
      ongoing: true,
      onlyAlertOnce: true,
      groupKey: _downloadGroupKey,
    );
    final iosDetails = DarwinNotificationDetails(threadIdentifier: _downloadGroupKey);
    final linuxDetails = const LinuxNotificationDetails(defaultActionName: 'Open notification');

    await _plugin.show(
      id: notifId,
      title: fileName,
      body: '$progress%',
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        linux: linuxDetails,
      ),
    );
  }

  /// Show a non-ongoing notification when a download finishes.
  static Future<void> showDownloadComplete({
    required String taskId,
    required String fileName,
  }) async {
    if (kIsWeb) return;

    // Reuse or allocate a stable notification ID for this task
    final notifId = _downloadNotifIds.putIfAbsent(taskId, () => _nextDownloadNotifId++);

    final androidDetails = AndroidNotificationDetails(
      _downloadChannelId,
      _downloadChannelName,
      channelShowBadge: false,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: false,
      onlyAlertOnce: true,
      groupKey: _downloadGroupKey,
    );
    final iosDetails = DarwinNotificationDetails(threadIdentifier: _downloadGroupKey);
    final linuxDetails = const LinuxNotificationDetails(defaultActionName: 'Open notification');

    await _plugin.show(
      id: notifId,
      title: fileName,
      body: 'Download complete',
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        linux: linuxDetails,
      ),
    );

    // Auto-dismiss after a few seconds so it doesn't linger
    Future.delayed(const Duration(seconds: 5), () => cancelDownloadNotification(taskId));
  }

  /// Cancel a download progress notification when download completes or is cancelled.
  static Future<void> cancelDownloadNotification(String taskId) async {
    final notifId = _downloadNotifIds.remove(taskId);
    if (notifId != null) {
      await _plugin.cancel(id: notifId);
    }
  }
}

@pragma('vm:entry-point')
void _notificationBackgroundEntryPoint(NotificationResponse response) {
  NotificationService._backgroundNotificationHandler(response);
}
