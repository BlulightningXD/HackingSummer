import 'graph_store.dart';
import 'sqlite_stub.dart' if (dart.library.ffi) 'sqlite_graph_store.dart';

GraphStore resolveGraphStore({String? path}) {
  return createPlatformGraphStore(path: path);
}
