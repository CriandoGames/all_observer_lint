import 'package:flutter/material.dart';

class DialogTrigger extends StatelessWidget {
  const DialogTrigger({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: Text('Mensagem'),
            );
          },
        );
      },
      child: const Text('Open'),
    );
  }
}
