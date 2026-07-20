import 'package:flutter/widgets.dart';

class MyCard extends StatelessWidget {
  const MyCard({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class ListPanel extends StatelessWidget {
  const ListPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('A'),
        MyCard(),
      ],
    );
  }
}
