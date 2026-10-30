import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

}

/// The app's only screen (set as the custom class in Main.storyboard).
///
/// Orientation: Flutter asks for landscape at run time (gyro mode locks to
/// the side the screen shows). iPhone's Info.plist allows landscape only; on
/// iPad every orientation is listed, as App Store Connect requires for
/// multitasking, and the layout works in any window shape.
///
/// M7 also set `prefersInterfaceOrientationLocked` here (iPadOS 26). It was
/// removed in M8: it locks the window to whatever orientation it opens in, so
/// an iPhone started upright kept a portrait window with the landscape app
/// turned inside it, and the keyboard for the pairing code came up sideways.
class ControllerViewController: FlutterViewController {
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    // Below about this size the controller shows "Make the window bigger"
    // anyway, so don't let a resizable iPad window get smaller. Points.
    view.window?.windowScene?.sizeRestrictions?.minimumSize = CGSize(width: 600, height: 380)
  }
}
