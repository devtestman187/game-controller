part of 'settings_screen.dart';

class _HapticsSection extends ConsumerWidget {
  const _HapticsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(hapticSettingsProvider);
    final notifier = ref.read(hapticSettingsProvider.notifier);
    final caps = ref.watch(hapticsCapabilitiesProvider).value;
    final text = Theme.of(context).textTheme;
    final supported = caps?.supported ?? false;
    final canScale = supported && (caps?.intensityControl ?? false);
    final on = settings.enabled && supported;

    return _Section(
      title: 'Haptics',
      children: [
        SwitchListTile(
          key: const Key('hapticsSwitch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Haptics'),
          subtitle: const Text("A tick on every press, and the TV's game events"),
          value: settings.enabled,
          onChanged: (v) => notifier.update(settings.copyWith(enabled: v)),
        ),
        _SliderRow(
          label: 'Button tick',
          value: settings.intensity,
          valueText: '${(settings.intensity * 100).round()}%',
          min: 0.1,
          divisions: 9,
          sliderKey: const Key('hapticsIntensity'),
          onChanged: on && canScale ? (v) => notifier.update(settings.copyWith(intensity: v)) : null,
          trailing: TextButton(
            key: const Key('tryTick'),
            onPressed: on ? notifier.test : null,
            child: const Text('Try'),
          ),
        ),
        const SizedBox(height: 8),
        Text('TV events', style: text.titleMedium),
        Text(
          'How strong each event from the TV feels, on its own. 0% turns that event off. The button tick '
          "isn't affected.",
          style: text.bodySmall,
        ),
        for (final e in HapticEvent.values)
          _SliderRow(
            label: eventLabel(e),
            hint: eventFeel(e),
            value: settings.eventIntensity(e),
            valueText: settings.eventIntensity(e) == 0 ? 'Off' : '${(settings.eventIntensity(e) * 100).round()}%',
            divisions: 10,
            sliderKey: Key('eventIntensity-${e.name}'),
            onChanged: on && canScale ? (v) => notifier.update(settings.withEvent(e, v)) : null,
            trailing: TextButton(
              key: Key('try-${e.name}'),
              onPressed: on && settings.eventIntensity(e) > 0 ? () => notifier.tryEvent(e) : null,
              child: const Text('Try'),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          caps == null
              ? 'Checking the hardware…'
              : !supported
              ? 'This device has no haptics. Everything else still works.'
              : '${caps.engine}${caps.intensityControl ? '' : '. This motor can only buzz on or off, so the strengths have no effect.'}',
          style: text.bodySmall,
        ),
        const SizedBox(height: 8),
        const _PressFeedback(),
      ],
    );
  }
}

/// Flash and click, mostly for devices without vibration (v2 C33).
class _PressFeedback extends ConsumerWidget {
  const _PressFeedback();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(pressFeedbackProvider);
    final n = ref.read(pressFeedbackProvider.notifier);
    final flash = ref.watch(flashOnPressProvider);
    final isIOS = ref.watch(isIOSProvider);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Without haptics', style: text.titleMedium),
        SwitchListTile(
          key: const Key('pressFlash'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Flash on press'),
          subtitle: const Text('On by itself on devices without haptics'),
          value: flash,
          onChanged: (v) => n.update(s.copyWith(flash: v)),
        ),
        SwitchListTile(
          key: const Key('pressClick'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Click sound'),
          subtitle: Text(
            isIOS
                ? 'A click on every press. The device must not be muted.'
                : 'A click on every press. Needs Touch sounds on in the system settings.',
          ),
          value: s.click,
          onChanged: (v) => n.update(s.copyWith(click: v)),
        ),
      ],
    );
  }
}

class _GyroSection extends ConsumerWidget {
  const _GyroSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gyroSettingsProvider);
    final n = ref.read(gyroSettingsProvider.notifier);
    return _Section(
      title: 'Gyro',
      subtitle: 'Calibrate from the gyro mode screen (or its settings button).',
      children: [
        _SliderRow(
          label: 'Sensitivity',
          hint: 'full at ${(fullTiltDegrees / s.sensitivity).round()}° of tilt',
          value: s.sensitivity,
          valueText: '${s.sensitivity.toStringAsFixed(2)}×',
          min: 0.5,
          max: 2.0,
          divisions: 15,
          sliderKey: const Key('settingsGyroSensitivity'),
          onChanged: (v) => n.update(s.copyWith(sensitivity: v)),
        ),
        _SliderRow(
          label: 'Dead zone',
          value: s.deadZone,
          valueText: '${(s.deadZone * 100).round()}%',
          max: 0.3,
          divisions: 15,
          sliderKey: const Key('settingsGyroDeadZone'),
          onChanged: (v) => n.update(s.copyWith(deadZone: v)),
        ),
        _SliderRow(
          label: 'Smoothing',
          value: s.smoothing,
          valueText: '${(s.smoothing * 100).round()}%',
          max: 0.9,
          divisions: 9,
          sliderKey: const Key('settingsGyroSmoothing'),
          onChanged: (v) => n.update(s.copyWith(smoothing: v)),
        ),
      ],
    );
  }
}

class _SticksSection extends ConsumerWidget {
  const _SticksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stickSettingsProvider);
    final n = ref.read(stickSettingsProvider.notifier);
    return _Section(
      title: 'Sticks',
      children: [
        SwitchListTile(
          key: const Key('settingsStickFloating'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Floating sticks'),
          subtitle: const Text('Each stick starts where your thumb lands'),
          value: s.floating,
          onChanged: (v) => n.update(s.copyWith(floating: v)),
        ),
        _SliderRow(
          label: 'Button size',
          hint: 'A, B, X and Y, compared with D-pad mode',
          value: s.buttonSize,
          valueText: '${(s.buttonSize * 100).round()}%',
          min: StickSettings.minButtonSize,
          max: StickSettings.maxButtonSize,
          divisions: 8,
          sliderKey: const Key('settingsStickButtonSize'),
          onChanged: (v) => n.update(s.copyWith(buttonSize: v)),
        ),
        _SliderRow(
          label: 'Dead zone',
          value: s.deadZone,
          valueText: '${(s.deadZone * 100).round()}%',
          max: 0.4,
          divisions: 20,
          sliderKey: const Key('settingsStickDeadZone'),
          onChanged: (v) => n.update(s.copyWith(deadZone: v)),
        ),
        _SliderRow(
          label: 'Sensitivity',
          hint: 'full at ${(100 / s.sensitivity).round()}% of the travel',
          value: s.sensitivity,
          valueText: '${s.sensitivity.toStringAsFixed(2)}×',
          min: 0.5,
          max: 2.0,
          divisions: 15,
          sliderKey: const Key('settingsStickSensitivity'),
          onChanged: (v) => n.update(s.copyWith(sensitivity: v)),
        ),
      ],
    );
  }
}

/// How the controls look over a game shown on this phone (m12 §2.7, v2 C28).
class _GameSection extends ConsumerWidget {
  const _GameSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(controlsSettingsProvider);
    final n = ref.read(controlsSettingsProvider.notifier);
    return _Section(
      title: 'Game on this phone',
      subtitle: 'How much you can see the buttons when a game is behind them',
      children: [
        _SliderRow(
          label: 'Button visibility (opacity)',
          value: s.opacity,
          valueText: '${(s.opacity * 100).round()}%',
          min: ControlsSettings.minOpacity,
          max: ControlsSettings.maxOpacity,
          // 20% to 100% in steps of 10%.
          divisions: 8,
          sliderKey: const Key('controlsOpacitySlider'),
          onChanged: (v) => n.update(s.copyWith(opacity: v)),
        ),
        const _FrameRateRow(),
      ],
    );
  }
}

/// The rate a game this phone hosts runs at (m12 §0.5): a test option, so it
/// is always shown and its label says what it is. A change applies from the
/// next round, since a running round keeps the rate it started with.
class _FrameRateRow extends ConsumerWidget {
  const _FrameRateRow();

  /// The space above the row, which puts it apart from the slider before it.
  static const _topGap = 12.0;

  /// The space between the row's texts and its buttons.
  static const _labelGap = 4.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hz = ref.watch(hostingFrameRateProvider);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: _topGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Frame rate (test)', style: text.bodyLarge),
          Text('For testing: fewer pictures a second saves battery but looks less smooth', style: text.bodySmall),
          const SizedBox(height: _labelGap),
          SegmentedButton<int>(
            key: const Key('settingsFrameRate'),
            segments: [for (final rate in hostingFrameRates) ButtonSegment(value: rate, label: Text('$rate'))],
            selected: {hz},
            showSelectedIcon: false,
            onSelectionChanged: (rates) => ref.read(hostingFrameRateProvider.notifier).set(rates.single),
          ),
        ],
      ),
    );
  }
}
