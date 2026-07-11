import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

class ProfileController {
  final name = 'Ana'.obs;
  final isSaving = false.obs;
}

class ProfilePageWithObserver extends StatelessWidget {
  const ProfilePageWithObserver({super.key, required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Observer(
      () => Column(
        children: [
          Text(controller.name.value),
          if (controller.isSaving.value) const CircularProgressIndicator(),
        ],
      ),
    );
  }
}

class ProfilePageWithWatch extends StatelessWidget {
  const ProfilePageWithWatch({super.key, required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Text(controller.name.watch(context));
  }
}

class ProfilePageWithEventHandler extends StatelessWidget {
  const ProfilePageWithEventHandler({super.key, required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        final currentName = controller.name.value;
        controller.name.value = '$currentName!';
      },
      child: const Text('change'),
    );
  }
}
