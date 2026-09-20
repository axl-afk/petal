import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/playback_controller.dart';
import '../../theme/app_theme.dart';

class EqualizerSheet extends ConsumerStatefulWidget {
  const EqualizerSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const EqualizerSheet(),
      );

  @override
  ConsumerState<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends ConsumerState<EqualizerSheet> {
  bool _enabled = true;
  String _preset = 'Flat';

  static const presets = <String, List<double>>{
    'Flat': [0, 0, 0, 0, 0],
    'Bass Boost': [.8, .55, .15, 0, -.1],
    'Vocal': [-.15, .1, .65, .45, .05],
    'Treble': [-.15, 0, .1, .45, .75],
    'Electronic': [.65, .25, -.1, .3, .65],
    'Rock': [.5, .2, -.15, .25, .55],
  };

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    final controller = ref.read(playbackControllerProvider.notifier);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Equalizer',
                        style: petal.text.heroTitle.copyWith(fontSize: 23)),
                  ),
                  Switch(
                    value: _enabled,
                    onChanged: controller.supportsEqualizer
                        ? (value) {
                            setState(() => _enabled = value);
                            controller.setEqualizerEnabled(value);
                          }
                        : null,
                  ),
                ],
              ),
              Text(
                controller.supportsEqualizer
                    ? 'Shape the sound with a hardware-backed Android equalizer.'
                    : 'The equalizer is currently available on Android. Playback remains unchanged on this device.',
                style: petal.text.cardSubtitle,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.entries
                    .map(
                      (entry) => ChoiceChip(
                        label: Text(entry.key),
                        selected: _preset == entry.key,
                        onSelected: controller.supportsEqualizer && _enabled
                            ? (_) {
                                setState(() => _preset = entry.key);
                                controller.applyEqualizerPreset(entry.value);
                              }
                            : null,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              _PresetGraph(values: presets[_preset]!),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetGraph extends StatelessWidget {
  final List<double> values;
  const _PresetGraph({required this.values});

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    const labels = ['Bass', 'Low', 'Mid', 'High', 'Treble'];
    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (index) {
          final value = values[index];
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: 12,
                  height: 54 + value * 42,
                  decoration: BoxDecoration(
                    color: petal.colors.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 9),
                Text(labels[index], style: petal.text.meta),
              ],
            ),
          );
        }),
      ),
    );
  }
}
