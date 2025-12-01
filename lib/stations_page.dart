import 'package:flutter/material.dart';
import 'api_service.dart';
import 'models/station.dart';
import 'library/song_page.dart';
import 'library/liked_songs_manager.dart';
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
  // Default to icon-only grid view. Serial badges off by default —
  // user can toggle serials using the header button.
  bool _gridView = true;
  bool _showSerial = false;

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: title or search box + action buttons
        Padding(
          padding: const EdgeInsets.only(top: 0, bottom: 12),
          child: _searching ? _buildSearchBox() : _buildHeaderRow(),
        ),
        Expanded(
          child: FutureBuilder<List<Station>>(
            future: ApiService.getStations(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final stations = snapshot.data!
                    .where((s) => s.name.toLowerCase().contains(_query.toLowerCase()))
                    .toList();
                if (_gridView) {
                  return _buildGrid(stations);
                }
                return _buildList(stations);
              } else if (snapshot.hasError) {
                return Center(
                    child: Text('Failed to load stations', style: TextStyle(color: Colors.white.withOpacity(0.7))));
              }
              return const Center(
                  child: CircularProgressIndicator(color: BakwaasPalette.neonGreen));
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
        bodyPadding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
        body: content,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: content,
    );
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
          icon: Icon(_gridView ? Icons.view_list : Icons.grid_view, color: Colors.white70),
          onPressed: () => setState(() => _gridView = !_gridView),
        ),
        IconButton(
          icon: Icon(_showSerial ? Icons.filter_alt : Icons.filter_alt_off, color: Colors.white70),
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
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SongPage(
                  station: station,
                  title: station.name,
                  subtitle: station.description ?? '',
                  imageUrl: station.profilepic,
                  autoplay: true))),
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
                          color: Colors.white.withOpacity(0.04),
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
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(station.description ?? 'Live station',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withOpacity(0.75))),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        LikedSongsManager.contains({'title': station.name, 'subtitle': station.description ?? ''})
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: Colors.pinkAccent,
                      ),
                      onPressed: () {
                        final songMap = {
                          'title': station.name,
                          'subtitle': station.description ?? '',
                          'image': station.profilepic ?? '',
                          'url': station.playerUrl ?? station.streamURL ?? station.mp3Url ?? ''
                        };
                        if (LikedSongsManager.contains(songMap)) {
                          LikedSongsManager.remove(songMap);
                        } else {
                          LikedSongsManager.add(songMap);
                        }
                      },
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white70)
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<Station> stations) {
    final screenWidth = MediaQuery.of(context).size.width - 40; // account for padding
    final tileSize = 76; // desired tile width
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
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SongPage(
                  station: station,
                  title: station.name,
                  subtitle: station.description ?? '',
                  imageUrl: station.profilepic,
                  autoplay: true))),
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
                        color: Colors.white.withOpacity(0.04),
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
