import 'package:flutter/material.dart';
import 'library/library_data.dart';
import '../app_data.dart';
import '../playback_manager.dart';
import 'models/station.dart';
import 'widgets/bakwaas_chrome.dart';

class StationsPage extends StatefulWidget {
  final bool useScaffold;
  const StationsPage({super.key, this.useScaffold = true});

  @override
  State<StationsPage> createState() => _StationsPageState();
}

class _StationsPageState extends State<StationsPage> {
  bool _searching = false;
  String _query = '';
  bool _gridView = true;
  bool _showSerial = false;

  @override
  void initState() {
    super.initState();
    LibraryData.load();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 0, bottom: 12),
          child: _searching ? _buildSearchBox() : _buildHeaderRow(),
        ),
        Expanded(
          child: ValueListenableBuilder<List<Station>>(
            valueListenable: LibraryData.stations,
                      builder: (context, stations, __) {
                        if (LibraryData.stationsError.value != null) {
                          return Center(
                              child: Text(LibraryData.stationsError.value!,
                                  style: TextStyle(
                                      color: Colors.white
                                          .withAlpha((0.7 * 255).round()))));
                        }

                        final filtered = stations
                            .where((s) => s.name
                                .toLowerCase()
                                .contains(_query.toLowerCase()))
                            .toList();
                        if (filtered.isEmpty) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: BakwaasPalette.neonGreen));
                        }
                        if (_gridView) return _buildGrid(filtered);
                        return _buildList(filtered);
                      },
                    ),
                  )
                ],
              );

              if (widget.useScaffold) {
                return BakwaasScaffold(
                  backgroundImage: null,
                  activeTab: 0,
                  showBottomNav: false,
                  onMenuTap: () => Navigator.of(context).maybePop(),
                  onExitTap: () => Navigator.of(context).maybePop(),
                  bodyPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  body: content,
                );
              }

              return Padding(padding: const EdgeInsets.fromLTRB(0, 0, 0, 0), child: content);
            }

            Widget _buildHeaderRow() {
              return Row(
                children: [
                  const Expanded(
                    child: Text('Stations',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white70),
                    onPressed: () => setState(() => _searching = true),
                  ),
                  IconButton(
                    icon: Icon(_gridView ? Icons.view_list : Icons.grid_view,
                        color: Colors.white70),
                    onPressed: () => setState(() => _gridView = !_gridView),
                  ),
                  IconButton(
                    icon: Icon(_showSerial ? Icons.filter_alt : Icons.filter_alt_off,
                        color: Colors.white70),
                    onPressed: () => setState(() => _showSerial = !_showSerial),
                  ),
                ],
              );
            }

            Widget _buildSearchBox() {
              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search stations',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                      onSubmitted: (_) => setState(() => _searching = false),
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => setState(() {
                            _searching = false;
                            _query = '';
                          })),
                ],
              );
            }

            Widget _buildList(List<Station> stations) {
              return ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: stations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final station = stations[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      final url = station.playerUrl ?? station.streamURL ?? station.mp3Url ?? '';
                      final song = {
                        'title': station.name,
                        'subtitle': station.description ?? '',
                        'image': station.profilepic ?? '',
                        'url': url,
                      };
                      try {
                        PlaybackManager.instance.play(song);
                      } catch (_) {}
                      AppData.rootTab.value = 1; // switch to Player tab
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BakwaasTheme.glassDecoration(radius: 18, opacity: 0.08),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    image: (station.profilepic != null && station.profilepic!.isNotEmpty)
                                        ? DecorationImage(image: NetworkImage(station.profilepic!), fit: BoxFit.cover)
                                        : const DecorationImage(image: AssetImage('assets/logo.png'), fit: BoxFit.cover),
                                    color: Colors.white.withAlpha((0.04 * 255).round()),
                                  ),
                                ),
                              ),
                              if (_showSerial)
                                Positioned(
                                  left: 6,
                                  top: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                                    child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(station.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(station.description ?? 'Live station',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.white.withAlpha((0.75 * 255).round()))),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white70)
                        ],
                      ),
                    ),
                  );
                },
              );
            }

            Widget _buildGrid(List<Station> stations) {
              final screenWidth = MediaQuery.of(context).size.width - 40;
              const tileSize = 76;
              int cross = (screenWidth / tileSize).floor();
              if (cross < 3) cross = 3;
              if (cross > 6) cross = 6;

              return GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  childAspectRatio: 1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: stations.length,
                itemBuilder: (context, index) {
                  final station = stations[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final url = station.playerUrl ?? station.streamURL ?? station.mp3Url ?? '';
                      final song = {
                        'title': station.name,
                        'subtitle': station.description ?? '',
                        'image': station.profilepic ?? '',
                        'url': url,
                      };
                      try {
                        PlaybackManager.instance.play(song);
                      } catch (_) {}
                      AppData.rootTab.value = 1;
                    },
                    child: Container(
                      decoration: BakwaasTheme.glassDecoration(radius: 12, opacity: 0.06),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  image: (station.profilepic != null && station.profilepic!.isNotEmpty)
                                      ? DecorationImage(image: NetworkImage(station.profilepic!), fit: BoxFit.cover)
                                      : null,
                                  color: Colors.white.withAlpha((0.04 * 255).round()),
                                ),
                              ),
                            ),
                          ),
                          if (_showSerial)
                            Positioned(
                              left: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                                child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }

          }
