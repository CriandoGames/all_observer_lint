import 'package:all_observer/all_observer.dart';
import 'package:all_observer/all_observer.dart' as ao;

class HistoryLimits {
  final value = Observable(0);

  void create() {
    value.withHistory(limit: 0);
    value.withHistory(limit: -1);
    ao.ObservableHistory(value, limit: 0);
  }
}
