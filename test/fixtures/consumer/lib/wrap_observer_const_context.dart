import 'package:flutter/widgets.dart';

class StaticView extends StatelessWidget {
  const StaticView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(padding: EdgeInsets.zero, child: Text('Fixed'));
  }
}
