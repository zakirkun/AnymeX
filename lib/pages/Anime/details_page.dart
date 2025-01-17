// ignore_for_file: prefer_const_constructors, deprecated_member_use, non_constant_identifier_names, must_be_immutable, avoid_print, use_build_context_synchronously

import 'dart:convert';
import 'dart:developer';
import 'package:aurora/auth/auth_provider.dart';
import 'package:aurora/components/common/IconWithLabel.dart';
import 'package:aurora/components/anilistExclusive/wong_title_dialog.dart';
import 'package:aurora/components/anime/details/episode_buttons.dart';
import 'package:aurora/components/anime/details/episode_list.dart';
import 'package:aurora/components/common/reusable_carousel.dart';
import 'package:aurora/components/anime/details/character_cards.dart';
import 'package:aurora/hiveData/appData/database.dart';
import 'package:aurora/utils/apiHooks/anilist/anime/details_page.dart';
import 'package:aurora/utils/apiHooks/api.dart';
import 'package:aurora/pages/Anime/watch_page.dart';
import 'package:aurora/utils/sources/anime/handler/sources_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:crystal_navigation_bar/crystal_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iconly/iconly.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';

Color? hexToColor(String hexColor) {
  if (hexColor == '??') {
    return null;
  } else {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }
}

dynamic genrePreviews = {
  'Action': 'https://s4.anilist.co/file/anilistcdn/media/anime/banner/1735.jpg',
  'Adventure':
      'https://s4.anilist.co/file/anilistcdn/media/anime/banner/154587-ivXNJ23SM1xB.jpg',
  'School':
      'https://s4.anilist.co/file/anilistcdn/media/anime/banner/21459-yeVkolGKdGUV.jpg',
  'Shounen':
      'https://s4.anilist.co/file/anilistcdn/media/anime/banner/101922-YfZhKBUDDS6L.jpg',
  'Super Power':
      'https://s4.anilist.co/file/anilistcdn/media/anime/banner/21087-sHb9zUZFsHe1.jpg',
  'Supernatural':
      'https://s4.anilist.co/file/anilistcdn/media/anime/banner/113415-jQBSkxWAAk83.jpg',
  'Slice of Life':
      'https://s4.anilist.co/file/anilistcdn/media/anime/banner/133965-spTi0WE7jR0r.jpg',
  'Romance':
      'https://s4.anilist.co/file/anilistcdn/media/anime/banner/162804-NwvD3Lya8IZp.jpg',
  'Fantasy':
      'https://s4.anilist.co/file/anilistcdn/media/anime/banner/108465-RgsRpTMhP9Sv.jpg',
  'Comedy':
      'https://s4.anilist.co/file/anilistcdn/media/anime/banner/100922-ef1bBJCUCfxk.jpg',
  'Mystery':
      'https://s4.anilist.co/file/anilistcdn/media/anime/banner/110277-iuGn6F5bK1U1.jpg',
  'default':
      'https://s4.anilist.co/file/anilistcdn/media/anime/banner/1-OquNCNB6srGe.jpg'
};

class DetailsPage extends StatefulWidget {
  final int id;
  final String? posterUrl;
  final String? tag;
  const DetailsPage({
    super.key,
    required this.id,
    this.posterUrl,
    this.tag,
  });

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage>
    with SingleTickerProviderStateMixin {
  bool usingSaikouLayout =
      Hive.box('app-data').get('usingSaikouLayout', defaultValue: false);
  dynamic data;
  bool isLoading = true;
  dynamic altdata;
  dynamic charactersdata;
  String? description;
  late AnimationController _controller;
  late Animation<double> _animation;
  int selectedIndex = 0;
  PageController pageController = PageController();
  // Episodes Section
  dynamic episodesData;
  dynamic episodeImages;
  int availEpisodes = 0;
  List<dynamic>? episodeSrc;
  int currentEpisode = 1;
  dynamic subtitleTracks;
  String activeServer = 'vidstream';
  bool isDub = false;
  int watchProgress = 1;
  final serverList = ['HD-1', 'HD-2', 'Vidstream'];
  bool usingAPI = false;

  // Sources
  dynamic fetchedData;

  // Layout Buttons
  List<IconData> layoutIcons = [
    IconlyBold.image,
    Icons.list_rounded,
    Iconsax.grid_25
  ];
  int layoutIndex = 0;

  @override
  void initState() {
    super.initState();
    fetchData();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);
    setState(() {
      watchProgress = returnProgress();
    });
    _animation = Tween<double>(begin: -1.0, end: -2.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    pageController.dispose();
    super.dispose();
  }

  Future<void> fetchData() async {
    try {
      final tempdata = await fetchAnimeInfo(widget.id);
      setState(() {
        data = tempdata;
        description = data?['description'];
        description = data['description'] ?? data?['description'];
        charactersdata = data['characters'] ?? [];
        altdata = data;
        isLoading = false;
      });
      final resp = await http.get(Uri.parse(
          "https://raw.githubusercontent.com/RyanYuuki/Anilist-Database/master/anilist/anime/${tempdata['id']}.json"));
      if (resp.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(resp.body);
        if (Provider.of<SourcesHandler>(context, listen: false)
                .selectedSource ==
            "HiAnime") {
          final zoroInfo = jsonResponse['Sites']['Zoro'];
          String? zoroUrl;
          String? zoroId;

          if (zoroInfo != null) {
            zoroUrl = zoroInfo.entries.first.value['url'];
            if (zoroUrl != null) {
              zoroId = zoroUrl.split('/').last;
              await fetchEpisodes(zoroId);
            }
          }
        } else {
          final gogoInfo = jsonResponse['Sites']['Gogoanime'];
          String? gogoUrl;
          String? gogoId;

          if (gogoInfo != null) {
            gogoUrl = gogoInfo.entries.first.value['url'];
            if (gogoUrl != null) {
              gogoId = gogoUrl.split('/').last;
              await fetchEpisodes(gogoId);
            }
          }
        }
      }
    } catch (e) {
      log('Failed to fetch Anime Info: $e');
    }
  }

  Future<void> fetchEpisodes(String id) async {
    try {
      final tempEpisodesData =
          await Provider.of<SourcesHandler>(context, listen: false)
              .fetchEpisodes(id);
      setState(() {
        fetchedData = tempEpisodesData;
        episodesData = tempEpisodesData['episodes'];
        availEpisodes = tempEpisodesData['totalEpisodes'];
        isLoading = false;
      });
      final tempEpisodeImages =
          await fetchStreamingDataConsumet(widget.id.toString());
      setState(() {
        episodeImages = tempEpisodeImages;
      });
    } catch (e) {
      log(e.toString());
    }
  }

  Future<void> fetchEpisodeSrcs() async {
    episodeSrc = null;
    final provider = Provider.of<SourcesHandler>(context, listen: false);
    if (episodesData == null) return;
    try {
      dynamic response;
      if (!usingAPI) {
        response = await provider.fetchEpisodesSrcs(
            episodesData[(currentEpisode - 1)]['episodeId'],
            category: isDub ? 'dub' : 'sub');
        log(response.toString());
      } else {
        response = await fetchStreamingLinksAniwatch(
            episodesData[(currentEpisode - 1)]['episodeId'],
            activeServer,
            isDub ? 'dub' : 'sub');
      }

      if (response != null) {
        setState(() {
          subtitleTracks = response['tracks'];
          episodeSrc = response['sources'];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      log('Error fetching episode sources: $e');
    }

    AppData().addWatchedAnime(
      animeId: data['id'].toString(),
      animeTitle: data['name'],
      currentEpisode: currentEpisode.toString(),
      animePosterImageUrl: data['poster'],
      anilistAnimeId: widget.id.toString(),
      currentSource: provider.selectedSource,
    );

    if (episodeSrc != null) {
      Navigator.pop(context);
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => WatchPage(
                    episodeSrc: episodeSrc ?? [],
                    episodeData: episodesData,
                    currentEpisode: currentEpisode,
                    episodeTitle:
                        episodesData[currentEpisode - 1]['title'] ?? '',
                    animeTitle: data['name'] ?? data['jname'],
                    activeServer: activeServer,
                    isDub: isDub,
                    animeId: widget.id,
                    tracks: subtitleTracks,
                    provider: Theme.of(context),
                  )));
    }
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme customScheme = Theme.of(context).colorScheme;

    Widget currentPage = usingSaikouLayout
        ? saikouDetailsPage(context)
        : originalDetailsPage(customScheme, context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(children: [
        currentPage,
        if (altdata?['status'] != 'CANCELLED' &&
            altdata?['status'] != 'NOT_YET_RELEASED' &&
            data != null)
          Positioned(
            bottom: 0,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: 158,
                  width: MediaQuery.of(context).size.width,
                  child: bottomBar(context),
                );
              },
            ),
          )
      ]),
    );
  }

  double getProperSize(double size) {
    if (size >= 0.0 && size < 5.0) {
      return 50.0;
    } else if (size >= 5.0 && size < 10.0) {
      return 45.0;
    } else if (size >= 10.0 && size < 15.0) {
      return 40.0;
    } else if (size >= 15.0 && size < 20.0) {
      return 35.0;
    } else if (size >= 20.0 && size < 25.0) {
      return 30.0;
    } else if (size >= 25.0 && size < 30.0) {
      return 25.0;
    } else if (size >= 30.0 && size < 35.0) {
      return 20.0;
    } else if (size >= 35.0 && size < 40.0) {
      return 15.0;
    } else if (size >= 40.0 && size < 45.0) {
      return 10.0;
    } else if (size >= 45.0 && size < 50.0) {
      return 5.0;
    } else {
      return 0.0;
    }
  }

  CrystalNavigationBar bottomBar(BuildContext context) {
    final tabBarRoundness =
        Hive.box('app-data').get('tabBarRoundness', defaultValue: 30.0);
    double tabBarSizeVertical =
        Hive.box('app-data').get('tabBarSizeVertical', defaultValue: 30.0);
    return CrystalNavigationBar(
      borderRadius: tabBarRoundness,
      currentIndex: selectedIndex,
      unselectedItemColor: Colors.white,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      marginR: EdgeInsets.symmetric(
          horizontal: 100, vertical: getProperSize(tabBarSizeVertical)),
      paddingR: EdgeInsets.symmetric(horizontal: 10),
      backgroundColor: Colors.black.withOpacity(0.3),
      onTap: (index) {
        setState(() {
          selectedIndex = index;
          pageController.animateToPage(index,
              duration: Duration(milliseconds: 300), curve: Curves.linear);
        });
      },
      items: [
        CrystalNavigationBarItem(
            icon: selectedIndex == 0
                ? Iconsax.info_circle5
                : Iconsax.info_circle),
        CrystalNavigationBarItem(
            icon: selectedIndex == 1 ? IconlyBold.play : IconlyLight.play),
      ],
    );
  }

  String checkAvailability(BuildContext context) {
    final animeList = Provider.of<AniListProvider>(context, listen: false)
        .userData?['animeList'];

    final matchingAnime = animeList?.firstWhere(
      (anime) => anime?['media']?['id']?.toString() == widget.id.toString(),
      orElse: () => null,
    );

    if (matchingAnime != null) {
      String status = matchingAnime['status'];

      switch (status) {
        case 'CURRENT':
          return 'Watching';
        case 'COMPLETED':
          return 'Completed';
        case 'PAUSED':
          return 'Paused';
        case 'DROPPED':
          return 'Dropped';
        case 'PLANNING':
          return 'Planning to Watch';
        case 'REPEATING':
          return 'Rewatching';
        default:
          return 'Add To List';
      }
    }

    return 'Add To List';
  }

  Scaffold saikouDetailsPage(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            saikouTopSection(context),
            if (isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 30.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SizedBox(
                height: selectedIndex == 0 ? 1650 : 750,
                child: PageView(
                  padEnds: false,
                  physics: NeverScrollableScrollPhysics(),
                  controller: pageController,
                  children: [
                    saikouDetails(context),
                    episodeSection(context),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool isList = true;
  List<dynamic> filteredEpisodes = [];
  List<List<int>> episodeRanges = [];

  void initliazedEpisodes() {
    if (episodesData != null && episodeRanges.isEmpty) {
      setState(() {
        if (episodesData.length > 50 && episodesData.length < 100) {
          episodeRanges = getEpisodeRanges(episodesData!, 24);
        } else if (episodesData.length > 200 && episodesData.length < 300) {
          episodeRanges = getEpisodeRanges(episodesData!, 40);
        } else if (episodesData.length > 300) {
          episodeRanges = getEpisodeRanges(episodesData!, 50);
        } else {
          episodeRanges = getEpisodeRanges(episodesData!, 12);
        }
        filteredEpisodes = episodesData!.where((episode) {
          int episodeNumber = (episode['number']);
          return episodeNumber >= episodeRanges[0][0] &&
              episodeNumber <= episodeRanges[0][1];
        }).toList();
      });
    }
  }

  Widget episodeSection(BuildContext context) {
    final sourceProvider = Provider.of<SourcesHandler>(context);
    initliazedEpisodes();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 30,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              'Found: ${fetchedData?['title'] ?? '??'}',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontFamily: "Poppins-SemiBold"),
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          DropdownButtonFormField<String>(
            value: sourceProvider.selectedSource,
            decoration: InputDecoration(
              labelText: 'Choose Source',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              labelStyle:
                  TextStyle(color: Theme.of(context).colorScheme.primary),
              border: OutlineInputBorder(
                borderSide:
                    BorderSide(color: Theme.of(context).colorScheme.primary),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.onPrimaryFixedVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            isExpanded: true,
            items: sourceProvider.getAvailableSource().map((source) {
              return DropdownMenuItem<String>(
                value: source['name'],
                child: Text(
                  source['name']!,
                  style: TextStyle(fontFamily: 'Poppins-SemiBold'),
                ),
              );
            }).toList(),
            onChanged: (value) async {
              setState(() {
                episodesData = null;
              });
              sourceProvider.changeSelectedSource(value!);
              final newData = await sourceProvider.mapToAnilist(data['name']);
              setState(() {
                fetchedData = newData;
                episodesData = newData['episodes'];
                availEpisodes = newData['totalEpisodes'];
                episodeImages = newData['episodes'];
                episodeRanges = [];
              });
              initliazedEpisodes();
            },
            dropdownColor: Theme.of(context).colorScheme.surface,
            icon: Icon(Icons.arrow_drop_down,
                color: Theme.of(context).colorScheme.primary),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
            ),
          ),
          Row(
            children: [
              if (Provider.of<SourcesHandler>(context).selectedSource !=
                  "GogoAnime") ...[
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedPositioned(
                          top: isDub ? 40 : 5,
                          duration: Duration(milliseconds: 300),
                          child: Icon(Iconsax.subtitle5, size: 30)),
                      AnimatedPositioned(
                          top: isDub ? 5 : 40,
                          duration: Duration(milliseconds: 300),
                          child: Icon(Iconsax.microphone5, size: 30)),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Switch(
                    value: isDub,
                    onChanged: (value) {
                      setState(() {
                        isDub = !isDub;
                      });
                    }),
              ],
              Spacer(),
              TextButton(
                onPressed: () {
                  showAnimeSearchModal(context, data['name'], (animeId) async {
                    setState(() {
                      episodesData = null;
                    });
                    final newData = await sourceProvider.fetchEpisodes(animeId);
                    setState(() {
                      fetchedData = newData;
                      episodesData = newData['episodes'];
                      availEpisodes = newData['totalEpisodes'];
                      episodeRanges = [];
                      episodeImages = newData['episodes'];
                    });
                    initliazedEpisodes();
                  });
                },
                child: Stack(
                  children: [
                    Text('Wrong Title?',
                        style: TextStyle(
                          fontFamily: 'Poppins-Bold',
                        )),
                    Positioned(
                      bottom: 0,
                      child: Container(
                        width: 100,
                        height: 1,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Episodes',
                  style:
                      TextStyle(fontSize: 18, fontFamily: 'Poppins-SemiBold')),
              Row(
                children: [
                  IconButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainer),
                    onPressed: () {
                      setState(() {
                        layoutIndex++;
                        if (layoutIndex > layoutIcons.length - 1) {
                          layoutIndex = 0;
                        }
                      });
                    },
                    icon: Icon(layoutIcons[layoutIndex]),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              setState(() {
                currentEpisode = returnProgress();
              });
              selectServerDialog(context);
            },
            child: Container(
              height: 75,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border:
                    Border.all(color: Theme.of(context).colorScheme.primary),
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  image: NetworkImage(
                      altdata?['cover'] ?? data?['poster'] ?? widget.posterUrl),
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.black.withOpacity(0.7),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      returnProgressString(),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 16,
                          fontFamily: 'Poppins-SemiBold'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (episodesData != null)
            SizedBox(
              height: 40,
              child: Stack(
                children: [
                  EpisodeButtons(
                    episodeRanges: episodeRanges,
                    onRangeSelected: (range) {
                      setState(() {
                        filteredEpisodes = episodesData!
                            .where((episode) =>
                                (episode['number']) >= range[0] &&
                                (episode['number']) <= range[1])
                            .toList();
                      });
                    },
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.transparent,
                              Colors.transparent,
                              Colors.transparent,
                              Colors.transparent,
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          const SizedBox(height: 10),
          episodesData == null
              ? Center(child: CircularProgressIndicator())
              : SizedBox(
                  height: layoutIndex == 0 ? 320 : 280,
                  child: EpisodeGrid(
                      currentEpisode: currentEpisode,
                      episodeImages: episodeImages,
                      episodes: filteredEpisodes,
                      progress: watchProgress,
                      layoutIndex: layoutIndex,
                      onEpisodeSelected: (int episode) {
                        setState(() {
                          currentEpisode = episode;
                        });
                        selectServerDialog(context);
                      },
                      coverImage: data?['poster'] ?? widget.posterUrl!),
                ),
        ],
      ),
    );
  }

  int returnProgress() {
    final animeList = Provider.of<AniListProvider>(context, listen: false)
        .userData?['currentlyWatching'];

    if (animeList == null) return 1;

    final matchingAnime = animeList.firstWhere(
      (anime) => anime?['media']?['id'] == widget.id,
      orElse: () => null,
    );

    return matchingAnime?['progress'] ?? 0;
  }

  String returnProgressString() {
    final animeList = Provider.of<AniListProvider>(context, listen: false)
        .userData?['currentlyWatching'];

    if (animeList == null) return "Watch: Episode 1";

    final matchingAnime = animeList.firstWhere(
      (anime) => anime?['media']?['id'] == widget.id,
      orElse: () => null,
    );

    if (matchingAnime == null) return "Watch: Episode 1";

    return 'Continue: Episode ${matchingAnime?['progress']}';
  }

  List<List<int>> getEpisodeRanges(List<dynamic> episodes, int step) {
    List<List<int>> episodeRanges = [];
    for (int i = 0; i < episodes.length; i += step) {
      int end = (i + step > episodes.length) ? episodes.length : i + step;
      episodeRanges.add([i + 1, end]);
    }
    return episodeRanges;
  }

  void selectServerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        int selectedServer = -1;
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              height: 450,
              decoration: BoxDecoration(
                color:
                    Theme.of(context).colorScheme.surface, // Background color
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: 4,
                    width: 40,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Column(children: [
                    Text(
                      'Select Server',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (Provider.of<SourcesHandler>(context).selectedSource ==
                        "HiAnime")
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('USE API',
                              style: TextStyle(
                                fontFamily: 'Poppins-SemiBold',
                                fontSize: 16,
                              )),
                          const SizedBox(width: 5),
                          Switch(
                              value: usingAPI,
                              onChanged: (value) {
                                setState(() {
                                  usingAPI = value;
                                });
                              }),
                        ],
                      ),
                  ]),
                  SizedBox(height: 16),
                  for (int i = 0; i < 3; i++) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: selectedServer == i
                              ? Theme.of(context)
                                  .colorScheme
                                  .onSecondaryFixedVariant
                              : Theme.of(context).colorScheme.surfaceContainer,
                          minimumSize: Size(double.infinity, 60),
                        ),
                        onPressed: () {
                          setState(() {
                            selectedServer = i;
                            activeServer = (serverList[i]).toLowerCase();
                          });
                        },
                        child: Text(
                          serverList[i],
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                  Spacer(),
                  ElevatedButton(
                    onPressed: selectedServer == -1
                        ? null
                        : () async {
                            episodeSrc = null;
                            showLoading();
                            await fetchEpisodeSrcs();
                          },
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      backgroundColor: selectedServer == -1
                          ? Colors.grey
                          : Theme.of(context).colorScheme.primary,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Press to Play',
                          style: TextStyle(
                            color: selectedServer == -1
                                ? Colors.white
                                : Theme.of(context).colorScheme.surface,
                          ),
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        selectedServer == -1
                            ? SizedBox()
                            : Icon(
                                Icons.play_circle_fill_rounded,
                                color: selectedServer == -1
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.surface,
                              )
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  showLoading() {
    Navigator.pop(context);
    showDialog(
        context: context,
        builder: (context) => Center(
              child: CircularProgressIndicator(),
            ));
  }

  Column saikouDetails(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (Provider.of<AniListProvider>(context).userData?['user']
                      ?['name'] !=
                  null)
                SizedBox(
                  height: 50,
                  width: MediaQuery.of(context).size.width - 40,
                  child: ElevatedButton(
                    onPressed: () {
                      showListEditorModal(
                          context, data['totalEpisodes'] ?? '?');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          width: 2,
                          color: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                      ),
                    ),
                    child: Text(
                      (checkAvailability(context)).toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontFamily: 'Poppins-Bold',
                      ),
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'Watched ',
                      style: TextStyle(fontSize: 15),
                      children: [
                        TextSpan(
                          text: "${returnProgress()} ",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontFamily: 'Poppins-Bold',
                          ),
                        ),
                        TextSpan(text: 'Out of ${data?['totalEpisodes']}')
                      ],
                    ),
                  ),
                  Expanded(child: SizedBox.shrink()),
                  IconButton(onPressed: () {}, icon: Icon(Iconsax.heart)),
                  IconButton(onPressed: () {}, icon: Icon(Icons.share)),
                ],
              ),
              const SizedBox(height: 20),
              infoRow(
                  field: 'Rating',
                  value:
                      '${data?['malscore']?.toString() ?? ((data?['rating'])).toString()}/10'),
              // infoRow(
              //     field: 'Studios',
              //     value: data?['studios'] ?? data?['studios']?[0] ?? '??'),
              infoRow(
                  field: 'Total Episodes',
                  value: data?['stats']?['episodes']?['sub'].toString() ??
                      data?['totalEpisodes'] ??
                      '??'),
              infoRow(field: 'Type', value: 'TV'),
              infoRow(
                  field: 'Romaji Name',
                  value: data?['jname'] ?? data?['japanese'] ?? '??'),
              infoRow(field: 'Premiered', value: data?['premiered'] ?? '??'),
              infoRow(field: 'Duration', value: '${data?['duration']}'),
              const SizedBox(height: 20),
              Text('Synopsis', style: TextStyle(fontFamily: 'Poppins-Bold')),
              const SizedBox(height: 10),
              Text(description!.toString().length > 250
                  ? '${description!.toString().substring(0, 250)}...'
                  : description!),

              // Grid Section
              const SizedBox(height: 20),
              Text('Genres', style: TextStyle(fontFamily: 'Poppins-Bold')),
              Flexible(
                flex: 0,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: data?['genres'].length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 55,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, itemIndex) {
                    String genre = data?['genres'][itemIndex];
                    String buttonBackground =
                        genrePreviews[genre] ?? genrePreviews['default'];

                    return Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(2.3),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                image: DecorationImage(
                                  image: NetworkImage(buttonBackground),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          // Gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  width: 3,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainer),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.5),
                                  Colors.black.withOpacity(0.5)
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                          // ElevatedButton
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () {},
                            child: Text(
                              genre.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Poppins-Bold',
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        // Text('Characters',
        //     style: TextStyle(fontFamily: 'Poppins-Bold')),
        CharacterCards(carouselData: charactersdata, isManga: false),
        // ReusableCarousel(
        //   title: 'Popular',
        //   carouselData: data?['popularAnimes'],
        //   tag: 'details-page1',
        // ),
        // ReusableCarousel(
        //   title: 'Related',
        //   carouselData: data?['relations'],
        //   tag: 'details-page2',
        //   detailsPage: true,
        // ),
        ReusableCarousel(
          detailsPage: true,
          title: 'Recommended',
          carouselData: data?['recommendations'],
          tag: 'details-page3',
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Stack saikouTopSection(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        if (altdata?['cover'] != null)
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Positioned(
                left: MediaQuery.of(context).size.width * _animation.value,
                child: CachedNetworkImage(
                  height: 450,
                  alignment: Alignment.center,
                  fit: BoxFit.cover,
                  imageUrl: altdata?['cover'] ?? widget.posterUrl,
                ),
              );
            },
          ),
        Positioned(
          child: Container(
            height: 455,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Theme.of(context).colorScheme.surface.withOpacity(0.7),
                  Theme.of(context).colorScheme.surface,
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Hero(
                      tag: widget.tag!,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          height: 170,
                          width: 120,
                          imageUrl: widget.posterUrl!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      height: 180,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.5,
                            child: Text(
                              data?['name'] ?? 'Loading...',
                              style: TextStyle(
                                fontFamily: 'Poppins-Bold',
                                fontSize: 16,
                                overflow: TextOverflow.ellipsis,
                              ),
                              maxLines: 4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            altdata?['status'] ??
                                data?['status'] ??
                                'RELEASING',
                            style: TextStyle(
                              fontFamily: 'Poppins-Bold',
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 30,
          right: 20,
          child: Material(
            borderOnForeground: false,
            color: Colors.transparent,
            child: IconButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(Icons.close),
            ),
          ),
        ),
      ],
    );
  }

  String selectedStatus = 'CURRENT';
  double score = 1.0;

  void showListEditorModal(BuildContext context, String totalEpisodes) {
    showModalBottomSheet(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 30.0,
                  right: 30.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 80.0,
                  top: 20.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'List Editor',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 55,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.transparent,
                          prefixIcon: Icon(Icons.playlist_add),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              width: 1,
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              width: 1,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          labelText: 'Status',
                          labelStyle: const TextStyle(
                            fontFamily: 'Poppins-Bold',
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedStatus,
                            items: [
                              'PLANNING',
                              'CURRENT',
                              'COMPLETED',
                              'REWATCHING',
                              'PAUSED',
                              'DROPPED',
                            ].map((String status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: (String? newStatus) {
                              setState(() {
                                selectedStatus = newStatus!;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 55,
                            child: TextFormField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.add),
                                suffixText: '/$totalEpisodes',
                                filled: true,
                                fillColor: Colors.transparent,
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    width: 1,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    width: 1,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                labelText: 'Progress',
                                labelStyle: const TextStyle(
                                  fontFamily: 'Poppins-Bold',
                                ),
                              ),
                              initialValue: watchProgress.toString(),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (String value) {
                                int? newProgress = int.tryParse(value);
                                if (newProgress != null && newProgress >= 0) {
                                  setState(() {
                                    if (totalEpisodes == '?') {
                                      watchProgress = newProgress;
                                    } else {
                                      int totalEp = int.parse(totalEpisodes);
                                      watchProgress = newProgress <= totalEp
                                          ? newProgress
                                          : totalEp;
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Score: ${score.toStringAsFixed(1)}/10',
                                style: const TextStyle(
                                  fontFamily: 'Poppins-Bold',
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: score,
                            min: 0.0,
                            max: 10.0,
                            divisions: 100,
                            label: score.toStringAsFixed(1),
                            activeColor: Theme.of(context).colorScheme.primary,
                            inactiveColor: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            onChanged: (double newValue) {
                              setState(() {
                                score = newValue;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SizedBox(
                          height: 50,
                          width: 120,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              side: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            child: const Text('Delete'),
                          ),
                        ),
                        SizedBox(
                          height: 50,
                          width: 120,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Provider.of<AniListProvider>(context,
                                      listen: false)
                                  .updateAnimeList(
                                      animeId: data['id'],
                                      episodeProgress: watchProgress,
                                      rating: score,
                                      status: selectedStatus);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              side: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Scaffold originalDetailsPage(ColorScheme CustomScheme, BuildContext context) {
    return Scaffold(
      backgroundColor: CustomScheme.surface,
      body: isLoading
          ? Column(
              children: [
                Center(
                  child: Poster(
                    context,
                    tag: widget.tag,
                    poster: widget.posterUrl,
                    isLoading: true,
                  ),
                ),
                const SizedBox(height: 30),
                CircularProgressIndicator(),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  Poster(
                    context,
                    isLoading: false,
                    tag: widget.tag,
                    poster: widget.posterUrl,
                  ),
                  const SizedBox(height: 30),
                  Info(context),
                ],
              ),
            ),
    );
  }

  Widget Poster(
    BuildContext context, {
    required String? tag,
    required String? poster,
    required bool? isLoading,
  }) {
    return SizedBox(
      height: 300,
      width: MediaQuery.of(context).size.width,
      child: Stack(
        children: [
          Positioned.fill(
            child: CachedNetworkImage(
              fit: BoxFit.cover,
              imageUrl:
                  (data?['cover'] == '' ? poster : data?['cover']) ?? poster!,
              alignment: Alignment.topCenter,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.surface.withOpacity(0.4),
                    Theme.of(context).colorScheme.surface.withOpacity(0.6),
                    Theme.of(context).colorScheme.surface,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 25,
            child: Row(
              children: [
                Hero(
                  tag: tag!,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: CachedNetworkImage(
                      imageUrl: poster!,
                      fit: BoxFit.cover,
                      width: 70,
                      height: 100,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width - 100,
                      child: Text(
                        data?['name'] ?? 'Loading',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            overflow: TextOverflow.ellipsis),
                        maxLines: 2,
                      ),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        iconWithName(
                          icon: Iconsax.star5,
                          name: data?['rating'] ?? '6.9',
                          isVertical: false,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 2,
                          height: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .inverseSurface
                              .withOpacity(0.4),
                        ),
                        const SizedBox(width: 10),
                        Text(data?['status'] ?? '??',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontFamily: 'Poppins-SemiBold'))
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Info(BuildContext context) {
    ColorScheme CustomScheme = Theme.of(context).colorScheme;
    return isLoading
        ? Padding(
            padding: const EdgeInsets.only(top: 30.0),
            child: Center(child: CircularProgressIndicator()),
          )
        : SizedBox(
            height: selectedIndex == 0 ? 1450 : 750,
            child: PageView(
              padEnds: false,
              physics: NeverScrollableScrollPhysics(),
              controller: pageController,
              children: [
                originalInfoPage(CustomScheme, context),
                episodeSection(context),
              ],
            ),
          );
  }

  Column originalInfoPage(ColorScheme CustomScheme, BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (Provider.of<AniListProvider>(context).userData?['user']
                      ?['name'] !=
                  null)
                SizedBox(
                  height: 50,
                  width: MediaQuery.of(context).size.width - 40,
                  child: ElevatedButton(
                    onPressed: () {
                      showListEditorModal(
                          context, data['totalEpisodes'] ?? '?');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          width: 2,
                          color: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                      ),
                    ),
                    child: Text(
                      (checkAvailability(context)).toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontFamily: 'Poppins-Bold',
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 30),
              Text('Description',
                  style: TextStyle(fontFamily: 'Poppins-SemiBold')),
              const SizedBox(
                height: 5,
              ),
              Column(
                children: [
                  Text(
                    description?.replaceAll(RegExp(r'<[^>]*>'), '') ??
                        data?['description']
                            ?.replaceAll(RegExp(r'<[^>]*>'), '') ??
                        'Description Not Found',
                    maxLines: 13,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[400]),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Statistics',
                  style:
                      TextStyle(fontFamily: 'Poppins-SemiBold', fontSize: 16)),
              infoRow(
                  field: 'Rating',
                  value:
                      '${data?['malscore']?.toString() ?? ((data?['rating'])).toString()}/10'),
              infoRow(
                  field: 'Total Episodes',
                  value: data?['stats']?['episodes']?['sub'].toString() ??
                      data?['totalEpisodes'] ??
                      '??'),
              infoRow(field: 'Type', value: 'TV'),
              infoRow(
                  field: 'Romaji Name',
                  value: data?['jname'] ?? data?['japanese'] ?? '??'),
              infoRow(field: 'Premiered', value: data?['premiered'] ?? '??'),
              infoRow(field: 'Duration', value: '${data?['duration']}'),
            ],
          ),
        ),
        CharacterCards(
          isManga: false,
          carouselData: charactersdata,
        ),
        // ReusableCarousel(
        //   title: 'Related',
        //   carouselData: data?['relations'],
        //   detailsPage: true,
        // ),
        ReusableCarousel(
          title: 'Recommended',
          carouselData: data?['recommendations'],
          detailsPage: true,
        ),
      ],
    );
  }
}

class infoRow extends StatelessWidget {
  final String value;
  final String field;

  const infoRow({super.key, required this.field, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(right: 10),
      margin: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(field,
              style: TextStyle(
                  fontFamily: 'Poppins-Bold',
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.7))),
          SizedBox(
            width: 170,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontFamily: 'Poppins-Bold')),
            ),
          ),
        ],
      ),
    );
  }
}
