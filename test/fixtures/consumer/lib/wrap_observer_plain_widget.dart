import 'package:flutter/widgets.dart';

// Not nested inside any Widget-returning expression anywhere in its
// ancestry, unlike a string literal that happens to sit inside a `Text(...)`
// argument (which *does* still resolve to the enclosing Widget — the
// smallest-widget-containing-the-selection rule looks at ancestors, not just
// the exact node under the cursor).
int addOne(int value) => value + 1;

class GreetingView extends StatelessWidget {
  const GreetingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Text('Olá'),
    );
  }
}
