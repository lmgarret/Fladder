import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:fladder/models/syncing/download_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:path/path.dart';

import 'package:fladder/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:fladder/models/item_base_model.dart';
import 'package:fladder/models/items/chapters_model.dart';
import 'package:fladder/models/items/images_models.dart';
import 'package:fladder/models/items/item_shared_models.dart';
import 'package:fladder/models/items/media_segments_model.dart';
import 'package:fladder/models/items/media_streams_model.dart';
import 'package:fladder/models/items/trick_play_model.dart';
import 'package:fladder/util/localization_helper.dart';

part 'sync_item.freezed.dart';

@Freezed(copyWith: true)
abstract class SyncedItem with _$SyncedItem {
  const SyncedItem._();

  factory SyncedItem({
    required String id,
    @Default(false) bool syncing,
    String? parentId,
    required String userId,
    String? path,
    @Default(false) bool markedForDelete,
    String? sortName,
    int? fileSize,
    String? videoFileName,
    MediaSegmentsModel? mediaSegments,
    TrickPlayModel? fTrickPlayModel,
    ImagesData? fImages,
    @Default([]) List<Chapter> fChapters,
    @Default([]) List<SubStreamModel> subtitles,
    @Default(false) bool unSyncedData,
    @UserDataJsonSerializer() UserData? userData,
    // ignore: invalid_annotation_target
    @JsonKey(includeFromJson: false, includeToJson: false) ItemBaseModel? itemModel,
  }) = _SyncItem;

  static String trickPlayPath = "TrickPlay";
  static String chaptersPath = "Chapters";

  List<Chapter> get chapters => fChapters.map((e) => e.copyWith(imageUrl: joinAll({"$path", e.imageUrl}))).toList();

  ImagesData? get images => fImages?.copyWith(
        primary: () => fImages?.primary?.copyWith(path: joinAll(["$path", "${fImages?.primary?.path}"])),
        logo: () => fImages?.logo?.copyWith(path: joinAll(["$path", "${fImages?.logo?.path}"])),
        backDrop: () => fImages?.backDrop?.map((e) => e.copyWith(path: joinAll(["$path", (e.path)]))).toList(),
      );

  TrickPlayModel? get trickPlayModel => fTrickPlayModel?.copyWith(
      images: fTrickPlayModel?.images
              .map(
                (trickPlayPath) => joinAll(["$path", trickPlayPath]),
              )
              .toList() ??
          []);

  File get dataFile => File(joinAll(["$path", "data.json"]));
  BaseItemDto? get data {
    return dataFile.existsSync()
        ? BaseItemDto.fromJson(jsonDecode(dataFile.readAsStringSync()))
            .copyWith(userData: UserData.toDto(userData), path: videoFile.existsSync() ? videoFile.path : '')
        : null;
  }

  Directory get trickPlayDirectory => Directory(joinAll(["$path", trickPlayPath]));
  File get videoFile => File(joinAll(["$path", "$videoFileName"]));
  Directory get directory => Directory(path ?? "");

  DownloadStatus get status => switch (videoFile.existsSync()) {
        true => DownloadStatus.complete,
        _ => DownloadStatus.notFound,
      };

  double get totalProgress => 0.0;

  bool get hasVideoFile => videoFileName?.isNotEmpty == true && (fileSize ?? 0) > 0;

  DownloadStatus get anyStatus {
    return DownloadStatus.notFound;
  }

  Future<bool> deleteDatFiles(Ref ref) async {
    try {
      await videoFile.delete();
      await Directory(joinAll([directory.path, trickPlayPath])).delete(recursive: true);
      await Directory(joinAll([directory.path, chaptersPath])).delete(recursive: true);
    } catch (e) {
      return false;
    }

    return true;
  }

  Future<int> get getDirSize async {
    var files = await directory.list(recursive: true).toList();
    var dirSize = files.fold(0, (int sum, file) => sum + file.statSync().size);
    return dirSize;
  }

  ItemBaseModel? createItemModel(Ref ref) {
    if (!dataFile.existsSync()) return null;
    final BaseItemDto itemDto = BaseItemDto.fromJson(jsonDecode(dataFile.readAsStringSync()));
    final itemModel = ItemBaseModel.fromBaseDto(itemDto, ref);
    return itemModel.copyWith(
      images: images,
      userData: userData,
    );
  }
}

extension StatusExtension on DownloadStatus {
  IconData get icon => switch (this) {
        DownloadStatus.enqueued => IconsaxPlusLinear.calendar_circle,
        DownloadStatus.running => IconsaxPlusLinear.arrow_down_1,
        DownloadStatus.complete => IconsaxPlusLinear.tick_circle,
        DownloadStatus.notFound => IconsaxPlusLinear.warning_2,
        DownloadStatus.failed => IconsaxPlusLinear.tag_cross,
        DownloadStatus.canceled => IconsaxPlusLinear.tag_cross,
        DownloadStatus.paused => IconsaxPlusLinear.pause_circle,
      };

  Color color(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode
        ? switch (this) {
            DownloadStatus.enqueued => Colors.blueAccent,
            DownloadStatus.running => Colors.greenAccent,
            DownloadStatus.complete => Colors.limeAccent,
            DownloadStatus.notFound => const Color.fromARGB(255, 221, 135, 23),
            DownloadStatus.canceled || DownloadStatus.failed => Theme.of(context).colorScheme.error,
            DownloadStatus.paused => Colors.tealAccent,
          }
        : switch (this) {
            DownloadStatus.enqueued => Colors.blue,
            DownloadStatus.running => Colors.green,
            DownloadStatus.complete => Colors.lime,
            DownloadStatus.notFound => const Color.fromARGB(255, 221, 135, 23),
            DownloadStatus.canceled || DownloadStatus.failed => Theme.of(context).colorScheme.error,
            DownloadStatus.paused => Colors.teal,
          };
  }

  String name(BuildContext context) => switch (this) {
        DownloadStatus.enqueued => context.localized.syncStatusEnqueued,
        DownloadStatus.running => context.localized.syncStatusRunning,
        DownloadStatus.complete => context.localized.syncStatusSynced,
        DownloadStatus.notFound => context.localized.syncStatusNotFound,
        DownloadStatus.failed => context.localized.syncStatusFailed,
        DownloadStatus.canceled => context.localized.syncStatusCanceled,
        DownloadStatus.paused => context.localized.syncStatusPaused,
      };
}
