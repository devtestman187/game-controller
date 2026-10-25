import CoreHaptics
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var haptics: HapticsChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ControllerHaptics") {
      haptics = HapticsChannel(messenger: registrar.messenger())
    }
  }
}

/// The app's only native channel: input ticks and the TV's haptic events with
/// Core Haptics (see lib/src/haptics.dart; the event patterns are built in
/// lib/src/haptic_patterns.dart). It's kept in this file so the Xcode project
/// needs no changes, since iOS builds only happen in the cloud.
final class HapticsChannel: NSObject {
  private let channel: FlutterMethodChannel
  private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
  private var engine: CHHapticEngine?
  private var engineRunning = false
  private var lastError: String?
  // Used only if the Core Haptics engine can't start.
  private let fallback = UIImpactFeedbackGenerator(style: .light)
  private let heavyFallback = UIImpactFeedbackGenerator(style: .heavy)
  private let notificationFallback = UINotificationFeedbackGenerator()
  // The latest player per TV event, so a new rumble replaces the one playing.
  private var eventPlayers: [String: CHHapticPatternPlayer] = [:]

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.gamecontrollerdev.controller/haptics", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    if supportsHaptics {
      createEngine()
    }
    // iOS stops the engine in the background; start it again on return.
    NotificationCenter.default.addObserver(
      self, selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification, object: nil)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "capabilities":
      result([
        "supported": supportsHaptics,
        "intensityControl": supportsHaptics,
        "engine": supportsHaptics ? "Core Haptics" : "none (no Taptic Engine)",
        "detail": lastError as Any,
      ])
    case "tick":
      let args = call.arguments as? [String: Any]
      let intensity = (args?["intensity"] as? Double) ?? 1.0
      tick(Float(max(0.0, min(1.0, intensity))))
      result(nil)
    case "play":
      // segments: [[startMs, durationMs, intensity, sharpness]], duration 0 = a tap.
      let args = call.arguments as? [String: Any]
      let event = (args?["event"] as? String) ?? ""
      let segments = ((args?["segments"] as? [Any]) ?? []).compactMap { item -> [Double]? in
        let values = ((item as? [Any]) ?? []).compactMap { ($0 as? NSNumber)?.doubleValue }
        return values.count >= 4 ? values : nil
      }
      play(event, segments)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func createEngine() {
    do {
      let engine = try CHHapticEngine()
      engine.playsHapticsOnly = true
      // Keep it running while the app is open: starting it again adds delay.
      engine.isAutoShutdownEnabled = false
      engine.stoppedHandler = { [weak self] reason in
        DispatchQueue.main.async {
          self?.engineRunning = false
          self?.eventPlayers.removeAll()
          self?.lastError = "Haptic engine stopped (reason \(reason.rawValue))"
        }
      }
      engine.resetHandler = { [weak self] in
        DispatchQueue.main.async {
          self?.engineRunning = false
          self?.eventPlayers.removeAll()
          self?.startEngine()
        }
      }
      self.engine = engine
      startEngine()
    } catch {
      lastError = "Could not create the haptic engine: \(error.localizedDescription)"
    }
  }

  private func startEngine() {
    guard let engine = engine, !engineRunning else { return }
    do {
      try engine.start()
      engineRunning = true
    } catch {
      lastError = "Could not start the haptic engine: \(error.localizedDescription)"
    }
  }

  @objc private func appDidBecomeActive() {
    startEngine()
  }

  private func tick(_ intensity: Float) {
    guard supportsHaptics, intensity > 0 else { return }
    if !engineRunning {
      startEngine()
    }
    guard let engine = engine, engineRunning else {
      fallback.impactOccurred(intensity: CGFloat(intensity))
      return
    }
    do {
      let event = CHHapticEvent(
        eventType: .hapticTransient,
        parameters: [
          CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
          CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
        ],
        relativeTime: 0)
      let pattern = try CHHapticPattern(events: [event], parameters: [])
      let player = try engine.makePlayer(with: pattern)
      try player.start(atTime: CHHapticTimeImmediate)
    } catch {
      lastError = "Tick failed: \(error.localizedDescription)"
      engineRunning = false
      fallback.impactOccurred(intensity: CGFloat(intensity))
    }
  }

  /// A haptic event from the TV. If the engine was stopped behind our back
  /// (for example while the app was in the background), it's restarted and
  /// the pattern tried once more before falling back to UIKit feedback.
  private func play(_ event: String, _ segments: [[Double]]) {
    guard supportsHaptics, !segments.isEmpty else { return }
    for attempt in 0..<2 {
      if !engineRunning {
        startEngine()
      }
      guard let engine = engine, engineRunning else { break }
      do {
        let pattern = try CHHapticPattern(events: segments.map(hapticEvent), parameters: [])
        let player = try engine.makePlayer(with: pattern)
        try? eventPlayers[event]?.stop(atTime: CHHapticTimeImmediate)
        eventPlayers[event] = player
        try player.start(atTime: CHHapticTimeImmediate)
        return
      } catch {
        lastError = "Event \(event) failed (attempt \(attempt + 1)): \(error.localizedDescription)"
        engineRunning = false
      }
    }
    eventFallback(event, segments)
  }

  private func hapticEvent(_ s: [Double]) -> CHHapticEvent {
    let parameters = [
      CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(max(0, min(1, s[2])))),
      CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(max(0, min(1, s[3])))),
    ]
    let start = max(0, s[0]) / 1000
    if s[1] <= 0 {
      return CHHapticEvent(eventType: .hapticTransient, parameters: parameters, relativeTime: start)
    }
    return CHHapticEvent(
      eventType: .hapticContinuous, parameters: parameters, relativeTime: start, duration: s[1] / 1000)
  }

  /// Without Core Haptics: UIKit's success and error feedback, or one heavy
  /// impact at the pattern's peak strength.
  private func eventFallback(_ event: String, _ segments: [[Double]]) {
    switch event {
    case "success":
      notificationFallback.notificationOccurred(.success)
    case "error":
      notificationFallback.notificationOccurred(.error)
    default:
      let peak = segments.map { $0[2] }.max() ?? 1
      heavyFallback.impactOccurred(intensity: CGFloat(max(0.1, min(1, peak))))
    }
  }
}
