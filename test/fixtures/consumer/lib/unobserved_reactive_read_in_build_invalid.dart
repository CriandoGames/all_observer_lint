import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';

class ProfileController {
  final name = 'Ana'.obs;
  final isSaving = false.obs;
  late final title = Computed(() => 'Profile ${name.value}');
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(controller.name.value),
        Text(controller.title.value),
        if (controller.isSaving.value) const CircularProgressIndicator(),
      ],
    );
  }
}
