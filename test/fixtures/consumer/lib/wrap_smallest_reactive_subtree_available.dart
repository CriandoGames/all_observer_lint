import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

/// Fixture for `WrapSmallestReactiveSubtreeAssist` — cases where the
/// specialized action must be available.
class TitleAndCounter extends StatelessWidget {
  const TitleAndCounter({super.key, required this.count});
  final Observable<int> count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Title'),
        Text('${count.value}'),
        const Footer(),
      ],
    );
  }
}

class Footer extends StatelessWidget {
  const Footer({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class TwoReadsInOneText extends StatelessWidget {
  const TwoReadsInOneText({super.key, required this.first, required this.second});
  final Observable<int> first;
  final Observable<int> second;

  @override
  Widget build(BuildContext context) {
    return Text('${first.value} ${second.value}');
  }
}

class TwoSiblingTexts extends StatelessWidget {
  const TwoSiblingTexts({super.key, required this.first, required this.second});
  final Observable<int> first;
  final Observable<int> second;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('${first.value}'),
        Text('${second.value}'),
      ],
    );
  }
}

class ItemBuilderWidget extends StatelessWidget {
  const ItemBuilderWidget({super.key, required this.items});
  final ObservableList<Observable<int>> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => Text('${items[index].value}'),
    );
  }
}
