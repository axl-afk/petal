import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

class ProfileController extends StateNotifier<Uint8List?> {
  final Ref _ref;

  ProfileController(this._ref) : super(_load(_ref));

  static Uint8List? _load(Ref ref) {
    final encoded = ref.read(prefsServiceProvider).loadProfileImage();
    if (encoded == null) return null;
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  Future<bool> chooseImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null || bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      return false;
    }
    state = bytes;
    await _ref.read(prefsServiceProvider).saveProfileImage(base64Encode(bytes));
    return true;
  }

  Future<void> removeImage() async {
    state = null;
    await _ref.read(prefsServiceProvider).saveProfileImage(null);
  }
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, Uint8List?>(
  (ref) => ProfileController(ref),
);
