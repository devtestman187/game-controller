import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

}

/// The app's only screen (set as the custom class in Main.storyboard), with
/// the iPadOS 26 window rules for a game held in the hands (PRD v2 C32, Apple
/// TN3192). Info.plist allows landscape only, and Flutter still picks the
/// side (gyro mode locks to the side the screen shows).
class ControllerViewController: FlutterViewController {
  /// Lock the window's orientation while the controller is shown, so the
  /// controls don't turn when the iPad is tilted.
  override var prefersInterfaceOrientationLocked: Bool { true }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    // Below about this size the controller shows "Make the window bigger"
    // anyway, so don't let a resizable window get smaller. Points.
    view.window?.windowScene?.sizeRestrictions?.minimumSize = CGSize(width: 600, height: 380)
  }
}
