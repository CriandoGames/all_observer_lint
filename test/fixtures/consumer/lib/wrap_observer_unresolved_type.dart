import 'package:flutter/widgets.dart';

class BrokenView extends StatelessWidget {
  const BrokenView({super.key});

  @override
  Widget build(BuildContext context) {
    return UndefinedWidgetThing();
  }
}
