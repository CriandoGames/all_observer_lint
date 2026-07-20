import 'package:flutter/widgets.dart';

class ItemsView extends StatelessWidget {
  const ItemsView({super.key, required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        return Text('Item $index');
      },
    );
  }
}
