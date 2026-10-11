/// An airport whose live ATC audio is published by LiveATC.net.
///
/// PilotEnRoute has no licence to rebroadcast LiveATC audio, so it does not
/// play these feeds itself. Each entry links out to the airport's feed page
/// on liveatc.net, where the audio is played under LiveATC's own terms.
class AtcFeed {
  final String id;
  final String airport;
  final String name;

  const AtcFeed({
    required this.id,
    required this.airport,
    required this.name,
  });

  /// The airport's feed listing on liveatc.net, opened in the browser.
  Uri get liveAtcPage => Uri.https(
        'www.liveatc.net',
        '/search/',
        <String, String>{'icao': airport.toLowerCase()},
      );
}

/// Directory of airports with LiveATC feeds. Nothing here streams audio.
class RadioService {
  RadioService._();

  static const List<AtcFeed> feeds = [
    AtcFeed(id: 'kjfk', airport: 'KJFK', name: 'New York (JFK)'),
    AtcFeed(id: 'klax', airport: 'KLAX', name: 'Los Angeles (LAX)'),
    AtcFeed(id: 'kbos', airport: 'KBOS', name: 'Boston (BOS)'),
    AtcFeed(id: 'katl', airport: 'KATL', name: 'Atlanta (ATL)'),
    AtcFeed(id: 'ksfo', airport: 'KSFO', name: 'San Francisco (SFO)'),
    AtcFeed(id: 'kord', airport: 'KORD', name: 'Chicago (ORD)'),
  ];
}
