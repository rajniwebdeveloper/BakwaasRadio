import 'package:flutter/material.dart';
import 'api_service.dart';
import 'models/station.dart';
import 'library/song_page.dart';
import 'widgets/bakwaas_chrome.dart';

class StationsPage extends StatelessWidget {
  const StationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BakwaasScaffold(
      backgroundImage: null,
      activeTab: 0,
      onMenuTap: () => Navigator.of(context).maybePop(),
      onExitTap: () => Navigator.of(context).maybePop(),
      bodyPadding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stations',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Station>>(
              future: ApiService.getStations(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final stations = snapshot.data!;
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
                              const Icon(Icons.chevron_right, color: Colors.white70)
                            ],
                          ),
                        ),
                      );
                    },
                  );
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
      ),
    );
  }
}
