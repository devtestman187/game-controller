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

/// The app's only native channel: input ticks with Core Haptics (see
/// lib/src/haptics.dart). It's kept in this file so the Xcode project needs
/// no changes, since iOS builds only happen in the cloud.
final class HapticsChannel: NSObject {
  private let channel: FlutterMethodChannel
  private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
  private var engine: CHHapticEngine?
  private var engineRunning = false
  private var lastError: String?
  // Used only if the Core Haptics engine can't start.
  private let fallback = UIImpactFeedbackGenerator(style: .light)

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
          self?.lastError = "Haptic engine stopped (reason \(reason.rawValue))"
        }
      }
      engine.resetHandler = { [weak self] in
        DispatchQueue.main.async {
          self?.engineRunning = false
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
}
