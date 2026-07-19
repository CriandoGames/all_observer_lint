import 'package:all_observer/all_observer.dart';

class HistoryLimits {
  final value = Observable(0);

  void create(int configuredLimit) {
    value.withHistory();
    value.withHistory(limit: 1);
    value.withHistory(limit: 100);
    value.withHistory(limit: configuredLimit);
  }
}
