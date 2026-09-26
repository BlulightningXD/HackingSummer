import '../graph/transit_graph.dart';
import 'delhi_metro_seed.dart';
import 'lucknow_metro_seed.dart';

class CityRegistry {
  static const String cityDelhi = 'Delhi';
  static const String cityLucknow = 'Lucknow';

  static const List<String> supportedCities = [cityDelhi, cityLucknow];

  /// Detects the target transit city based on passenger coordinates
  static String detectCity(double latitude, double longitude) {
    // Delhi NCR bounding box
    if (latitude >= 28.2 && latitude <= 28.95 && longitude >= 76.8 && longitude <= 77.6) {
      return cityDelhi;
    }
    // Lucknow bounding box
    if (latitude >= 26.6 && latitude <= 27.15 && longitude >= 80.7 && longitude <= 81.2) {
      return cityLucknow;
    }

    // Default fallback is Delhi Metro
    return cityDelhi;
  }

  /// Populates the graph for a specific city
  static void populateCity(TransitGraph graph, String city) {
    switch (city.toLowerCase()) {
      case 'lucknow':
        LucknowMetroSeed.populate(graph);
        break;
      case 'delhi':
      default:
        DelhiMetroSeed.populate(graph);
        break;
    }
  }

  /// Populates all supported transit networks into the graph
  static void populateAll(TransitGraph graph) {
    DelhiMetroSeed.populate(graph);
    LucknowMetroSeed.populate(graph);
  }
}
