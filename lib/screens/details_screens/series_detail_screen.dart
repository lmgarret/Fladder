import 'package:ficonsax/ficonsax.dart';
import 'package:fladder/screens/details_screens/components/overview_header.dart';
import 'package:fladder/screens/shared/media/components/media_play_button.dart';
import 'package:fladder/screens/shared/media/components/next_up_episode.dart';
import 'package:fladder/util/item_base_model/item_base_model_extensions.dart';
import 'package:fladder/util/item_base_model/play_item_helpers.dart';
import 'package:fladder/util/localization_helper.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/models/item_base_model.dart';
import 'package:fladder/providers/items/series_details_provider.dart';
import 'package:fladder/providers/user_provider.dart';
import 'package:fladder/screens/shared/detail_scaffold.dart';
import 'package:fladder/screens/shared/media/components/media_header.dart';
import 'package:fladder/screens/shared/media/episode_posters.dart';
import 'package:fladder/screens/shared/media/expanding_overview.dart';
import 'package:fladder/screens/shared/media/people_row.dart';
import 'package:fladder/screens/shared/media/poster_row.dart';
import 'package:fladder/screens/shared/media/season_row.dart';
import 'package:fladder/util/list_padding.dart';
import 'package:fladder/util/widget_extensions.dart';
import 'package:fladder/widgets/shared/selectable_icon_button.dart';
import 'package:go_router/go_router.dart';

class SeriesDetailScreen extends ConsumerStatefulWidget {
  final ItemBaseModel item;
  const SeriesDetailScreen({required this.item, super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  late final providerId = seriesDetailsProvider(widget.item.id);

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(providerId);
    return DetailScaffold(
      label: details?.name ?? "",
      item: details,
      actions: (context) => details?.generateActions(
        context,
        ref,
        exclude: {
          ItemActions.play,
          ItemActions.playFromStart,
          ItemActions.details,
        },
        onDeleteSuccesFully: (item) {
          if (context.mounted) {
            context.pop();
          }
        },
      ),
      onRefresh: () => ref.read(providerId.notifier).fetchDetails(widget.item),
      backDrops: details?.images,
      content: (padding) => details != null
          ? Padding(
              padding: const EdgeInsets.only(bottom: 64),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.35),
                  MediaHeader(
                    name: details.name,
                    logo: details.images?.logo,
                  ),
                  OverviewHeader(
                    name: details.name,
                    padding: padding,
                    originalTitle: details.originalTitle,
                    productionYear: details.overview.productionYear,
                    runTime: details.overview.runTime,
                    studios: details.overview.studios,
                    officialRating: details.overview.parentalRating,
                    genres: details.overview.genreItems,
                    communityRating: details.overview.communityRating,
                    externalUrls: details.overview.externalUrls,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      MediaPlayButton(
                        item: details.nextUp,
                        onPressed: details.nextUp != null
                            ? () async {
                                await details.nextUp.play(context, ref);
                                ref.read(providerId.notifier).fetchDetails(widget.item);
                              }
                            : null,
                        onLongPressed: details.nextUp != null
                            ? () async {
                                await details.nextUp.play(context, ref, showPlaybackOption: true);
                                ref.read(providerId.notifier).fetchDetails(widget.item);
                              }
                            : null,
                      ),
                      SelectableIconButton(
                        onPressed: () async {
                          await ref
                              .read(userProvider.notifier)
                              .setAsFavorite(!details.userData.isFavourite, details.id);
                        },
                        selected: details.userData.isFavourite,
                        selectedIcon: IconsaxBold.heart,
                        icon: IconsaxOutline.heart,
                      ),
                      SelectableIconButton(
                        onPressed: () async {
                          await ref.read(userProvider.notifier).markAsPlayed(!details.userData.played, details.id);
                        },
                        selected: details.userData.played,
                        selectedIcon: IconsaxBold.tick_circle,
                        icon: IconsaxOutline.tick_circle,
                      ),
                    ],
                  ).padding(padding),
                  if (details.nextUp != null)
                    NextUpEpisode(
                      nextEpisode: details.nextUp!,
                      onChanged: (episode) => ref.read(providerId.notifier).updateEpisodeInfo(episode),
                    ).padding(padding),
                  if (details.overview.summary.isNotEmpty)
                    ExpandingOverview(
                      text: details.overview.summary,
                    ).padding(padding),
                  if (details.availableEpisodes?.isNotEmpty ?? false)
                    EpisodePosters(
                      contentPadding: padding,
                      label: context.localized.episode(details.availableEpisodes?.length ?? 2),
                      playEpisode: (episode) async {
                        await episode.play(
                          context,
                          ref,
                        );
                        ref.read(providerId.notifier).fetchDetails(widget.item);
                      },
                      episodes: details.availableEpisodes ?? [],
                    ),
                  if (details.seasons?.isNotEmpty ?? false)
                    SeasonsRow(
                      contentPadding: padding,
                      seasons: details.seasons,
                      onSeasonPressed: (season) => season.navigateTo(context),
                    ),
                  if (details.overview.people.isNotEmpty)
                    PeopleRow(
                      people: details.overview.people,
                      contentPadding: padding,
                    ),
                  if (details.related.isNotEmpty)
                    PosterRow(posters: details.related, contentPadding: padding, label: context.localized.related),
                ].addPadding(const EdgeInsets.symmetric(vertical: 16)),
              ),
            )
          : Container(),
    );
  }
}
