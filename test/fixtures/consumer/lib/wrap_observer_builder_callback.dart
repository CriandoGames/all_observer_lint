import 'package:flutter/widgets.dart';

class MyContent extends StatelessWidget {
  const MyContent({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class PanelView extends StatelessWidget {
  const PanelView({super.key});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return MyContent();
      },
    );
  }
}
