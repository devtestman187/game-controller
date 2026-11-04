/// On only in builds made with --dart-define=DEMO_DIRECTOR=true (the demo
/// video pipeline, docs/demo-video-runbook.md). Store builds never set it.
const bool demoDirector = bool.fromEnvironment('DEMO_DIRECTOR');
