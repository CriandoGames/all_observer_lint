import 'package:flutter/widgets.dart';

class ResponsiveView extends StatelessWidget {
  const ResponsiveView({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Text('${constraints.maxWidth}');
      },
    );
  }
}
