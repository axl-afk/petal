import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/auth_session.dart';
import '../../state/profile_controller.dart';
import '../../theme/app_theme.dart';

class ProfileAvatar extends ConsumerWidget {
  final AuthSession? session;
  final double radius;
  final VoidCallback? onTap;

  const ProfileAvatar({
    super.key,
    required this.session,
    this.radius = 18,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(profileControllerProvider);
    final petal = context.petal;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: petal.colors.surface2,
      backgroundImage: bytes == null ? null : MemoryImage(bytes),
      child: bytes != null
          ? null
          : session == null
              ? Icon(Icons.person_outline,
                  size: radius, color: petal.colors.ink2)
              : Text(
                  session!.email.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: radius * .8,
                    fontWeight: FontWeight.w700,
                    color: petal.colors.ink,
                  ),
                ),
    );
    if (onTap == null) return avatar;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: avatar,
    );
  }
}
