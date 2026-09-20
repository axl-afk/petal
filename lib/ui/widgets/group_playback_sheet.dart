import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/group_playback_controller.dart';
import '../../theme/app_theme.dart';

class GroupPlaybackSheet extends ConsumerStatefulWidget {
  const GroupPlaybackSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const GroupPlaybackSheet(),
      );

  @override
  ConsumerState<GroupPlaybackSheet> createState() =>
      _GroupPlaybackSheetState();
}

class _GroupPlaybackSheetState extends ConsumerState<GroupPlaybackSheet> {
  final _address = TextEditingController();

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    final group = ref.watch(groupPlaybackControllerProvider);
    final controller =
        ref.read(groupPlaybackControllerProvider.notifier);
    final connected = group.mode != GroupPlaybackMode.disconnected;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Listen Together',
                  style: petal.text.heroTitle.copyWith(fontSize: 23)),
              const SizedBox(height: 6),
              Text(
                'Keep the same song and position aligned on up to six Petal devices on the same Wi-Fi network.',
                style: petal.text.cardSubtitle,
              ),
              const SizedBox(height: 20),
              if (connected) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: petal.colors.surface2,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.graphic_eq_rounded,
                          color: petal.colors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.mode == GroupPlaybackMode.hosting
                                  ? 'Hosting at ${group.address}'
                                  : 'Joined ${group.address}',
                              style: petal.text.cardTitle,
                            ),
                            Text(
                              '${group.deviceCount} of 6 devices connected',
                              style: petal.text.cardSubtitle,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: controller.leave,
                        child: const Text('Leave'),
                      ),
                    ],
                  ),
                ),
              ] else if (controller.supported) ...[
                FilledButton.icon(
                  onPressed: controller.host,
                  icon: const Icon(Icons.wifi_tethering_rounded),
                  label: const Text('Start a group'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _address,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Host address',
                          hintText: '192.168.1.24:45872',
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => controller.join(_address.text),
                      child: const Text('Join'),
                    ),
                  ],
                ),
              ] else
                Text(
                  'Listen Together requires the installed Petal app.',
                  style: petal.text.cardSubtitle,
                ),
              if (group.error != null) ...[
                const SizedBox(height: 12),
                Text(group.error!,
                    style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 12),
              Text(
                'Cloud songs must exist in each device’s signed-in library. Local-only files must be imported on every device.',
                style: petal.text.meta,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
