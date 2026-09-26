import '../graph/transit_graph.dart';
import '../models/congestion.dart';

abstract class GraphStore {
  void saveGraph(TransitGraph graph);
  TransitGraph loadGraph({String? city});
  int getSyncVersion();
  void setSyncVersion(int version);

  // Store-and-forward congestion outbox methods
  void queueOutboxCongestion(CongestionRecord record);
  List<CongestionRecord> getPendingOutboxCongestion();
  void clearOutboxCongestion(List<String> ids);

  // Station congestion cache methods
  void updateStationCongestion(String stationId, int score, DateTime timestamp);
  StationCongestionSnapshot? getStationCongestion(
    String stationId, {
    Duration timeout = const Duration(minutes: 45),
  });
  Map<String, StationCongestionSnapshot> getAllStationCongestion({
    Duration timeout = const Duration(minutes: 45),
  });

  void close();
}
