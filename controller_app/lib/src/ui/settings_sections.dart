part of 'settings_screen.dart';

/// The look's settings (M13): the Look and effects rows, in a card like the
/// sections beside them. The section itself lives in `party_host`, so the
/// phone and the TV show and save the same setting.
class _LookAndSoundSection extends StatelessWidget {
  const _LookAndSoundSection();

  @override
  Widget build(BuildContext context) {
    return const _Section(title: HostText.lookAndSound, children: [LookAndSoundSection()]);
  }
}

class _HapticsSection extends ConsumerWidget {
  const _HapticsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(hapticSettingsProvider);
    final notifier = ref.read(hapticSettingsProvider.notifier);
    final caps = ref.watch(hapticsCapabilitiesProvider).value;
    final supported = caps?.supported ?? false;
    final canScale = supported && (caps?.intensityControl ?? false);
    final on = settings.enabled && supported;
    return _Section(
      title: SettingsText.haptics,
      children: [
        SwitchListTile(
          key: const Key('hapticsSwitch'),
          contentPadding: EdgeInsets.zero,
          title: const Text(SettingsText.haptics),
          subtitle: const Text(SettingsText.hapticsLine),
          value: settings.enabled,
          onChanged: (v) => notifier.update(settings.copyWith(enabled: v)),
        ),
        _tickRow(settings, notifier, on: on, canScale: canScale),
        const SizedBox(height: ToySizes.space8),
        _eventsHeading(context),
        for (final e in HapticEvent.values) _eventRow(settings, notifier, e, on: on, canScale: canScale),
        const SizedBox(height: ToySizes.space4),
        _hardwareLine(context, caps, supported),
        const SizedBox(height: ToySizes.space8),
        const _PressFeedback(),
      ],
    );
  }

  /// The button's own tick: its strength, and Try.
  Widget _tickRow(
    HapticSettings settings,
    HapticSettingsNotifier notifier, {
    required bool on,
    required bool canScale,
  }) => _SliderRow(
    label: SettingsText.buttonTick,
    value: settings.intensity,
    valueText: SettingsText.share(settings.intensity),
    min: 0.1,
    divisions: 9,
    sliderKey: const Key('hapticsIntensity'),
    onChanged: on && canScale ? (v) => notifier.update(settings.copyWith(intensity: v)) : null,
    trailing: TextButton(
      key: const Key('tryTick'),
      onPressed: on ? notifier.test : null,
      child: const Text(SettingsText.trySomething),
    ),
  );

  /// What the event sliders do, above them.
  Widget _eventsHeading(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(SettingsText.tvEvents, style: look.type.button),
        Text(SettingsText.tvEventsLine, style: look.type.body.copyWith(color: look.colors.inkSoft)),
      ],
    );
  }

  /// One TV event: how strong it feels, and Try.
  Widget _eventRow(
    HapticSettings settings,
    HapticSettingsNotifier notifier,
    HapticEvent e, {
    required bool on,
    required bool canScale,
  }) {
    final strength = settings.eventIntensity(e);
    return _SliderRow(
      label: eventLabel(e),
      hint: eventFeel(e),
      value: strength,
      valueText: strength == 0 ? SettingsText.off : SettingsText.share(strength),
      divisions: 10,
      sliderKey: Key('eventIntensity-${e.name}'),
      onChanged: on && canScale ? (v) => notifier.update(settings.withEvent(e, v)) : null,
      trailing: TextButton(
        key: Key('try-${e.name}'),
        onPressed: on && strength > 0 ? () => notifier.tryEvent(e) : null,
        child: const Text(SettingsText.trySomething),
      ),
    );
  }

  /// What the hardware can do, or why the strengths do nothing.
  Widget _hardwareLine(BuildContext context, HapticsCapabilities? caps, bool supported) {
    final look = ToyLookScope.of(context);
    final line = caps == null
        ? SettingsText.checkingHardware
        : !supported
        ? SettingsText.noHaptics
        : caps.intensityControl
        ? caps.engine
        : SettingsText.motorOnOff(caps.engine);
    return Text(line, style: look.type.body.copyWith(color: look.colors.inkSoft));
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
    final look = ToyLookScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(SettingsText.withoutHaptics, style: look.type.button),
        SwitchListTile(
          key: const Key('pressFlash'),
          contentPadding: EdgeInsets.zero,
          title: const Text(SettingsText.flashOnPress),
          subtitle: const Text(SettingsText.flashOnPressLine),
          value: flash,
          onChanged: (v) => n.update(s.copyWith(flash: v)),
        ),
        SwitchListTile(
          key: const Key('pressClick'),
          contentPadding: EdgeInsets.zero,
          title: const Text(SettingsText.clickSound),
          subtitle: Text(isIOS ? SettingsText.clickSoundLineIOS : SettingsText.clickSoundLine),
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
      title: PhoneText.gyro,
      subtitle: SettingsText.gyroCalibrate,
      children: [
        _SliderRow(
          label: SettingsText.sensitivity,
          hint: SettingsText.gyroTiltHint((fullTiltDegrees / s.sensitivity).round()),
          value: s.sensitivity,
          valueText: SettingsText.times(s.sensitivity),
          min: 0.5,
          max: 2.0,
          divisions: 15,
          sliderKey: const Key('settingsGyroSensitivity'),
          onChanged: (v) => n.update(s.copyWith(sensitivity: v)),
        ),
        _SliderRow(
          label: SettingsText.deadZone,
          value: s.deadZone,
          valueText: SettingsText.share(s.deadZone),
          max: 0.3,
          divisions: 15,
          sliderKey: const Key('settingsGyroDeadZone'),
          onChanged: (v) => n.update(s.copyWith(deadZone: v)),
        ),
        _SliderRow(
          label: SettingsText.smoothing,
          value: s.smoothing,
          valueText: SettingsText.share(s.smoothing),
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
      title: PhoneText.sticks,
      children: [
        SwitchListTile(
          key: const Key('settingsStickFloating'),
          contentPadding: EdgeInsets.zero,
          title: const Text(SettingsText.floatingSticks),
          subtitle: const Text(SettingsText.floatingLine),
          value: s.floating,
          onChanged: (v) => n.update(s.copyWith(floating: v)),
        ),
        _SliderRow(
          label: SettingsText.buttonSize,
          hint: SettingsText.buttonSizeHint,
          value: s.buttonSize,
          valueText: SettingsText.share(s.buttonSize),
          min: StickSettings.minButtonSize,
          max: StickSettings.maxButtonSize,
          divisions: 8,
          sliderKey: const Key('settingsStickButtonSize'),
          onChanged: (v) => n.update(s.copyWith(buttonSize: v)),
        ),
        _SliderRow(
          label: SettingsText.deadZone,
          value: s.deadZone,
          valueText: SettingsText.share(s.deadZone),
          max: 0.4,
          divisions: 20,
          sliderKey: const Key('settingsStickDeadZone'),
          onChanged: (v) => n.update(s.copyWith(deadZone: v)),
        ),
        _SliderRow(
          label: SettingsText.sensitivity,
          hint: SettingsText.stickTravelHint((100 / s.sensitivity).round()),
          value: s.sensitivity,
          valueText: SettingsText.times(s.sensitivity),
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
      title: SettingsText.gameOnThisPhone,
      subtitle: SettingsText.gameOnThisPhoneLine,
      children: [
        _SliderRow(
          label: SettingsText.opacity,
          value: s.opacity,
          valueText: SettingsText.share(s.opacity),
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
  static const _topGap = ToySizes.space12;

  /// The space between the row's texts and its buttons.
  static const _labelGap = ToySizes.space4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hz = ref.watch(hostingFrameRateProvider);
    final look = ToyLookScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: _topGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(SettingsText.frameRate, style: look.type.body),
          Text(SettingsText.frameRateLine, style: look.type.body.copyWith(color: look.colors.inkSoft)),
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
