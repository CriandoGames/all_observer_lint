import 'package:flutter/widgets.dart';

class MyContent extends StatelessWidget {
  const MyContent({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Widget createContent() {
  return MyContent();
}

class HolderView extends StatelessWidget {
  const HolderView({super.key});

  @override
  Widget build(BuildContext context) {
    final Widget child = MyContent();
    return child;
  }
}
