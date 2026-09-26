import 'graph_store.dart';
import 'in_memory_graph_store.dart';

GraphStore createPlatformGraphStore({String? path}) {
  return InMemoryGraphStore();
}
