import 'package:flutter/widgets.dart';

class PartiallyBrokenView extends StatelessWidget {
  const PartiallyBrokenView({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: undefinedTextStyle);
  }
}
