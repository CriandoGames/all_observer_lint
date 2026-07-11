import 'package:all_observer/all_observer.dart';

class ProfileState {
  final nameOverride = Observable<String>('');
  final emailOverride = Observable<String>('');
  final phoneOverride = Observable<String>('');
  final isEditing = Observable<bool>(false);
}

class ProfileController {
  ProfileController(this.state);

  final ProfileState state;

  void save(String name, String email, String phone) {
    Observable.batch(() {
      state.nameOverride.value = name;
      state.emailOverride.value = email;
      state.phoneOverride.value = phone;
      state.isEditing.value = false;
    });
  }

  void updateNameAndEmail(String name, String email) {
    state.nameOverride.value = name;
    state.emailOverride.value = email;
  }
}
