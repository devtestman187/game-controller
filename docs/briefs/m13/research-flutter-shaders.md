job: research — Flutter fragment shaders on our four targets, for M13's toon shader
web: yes
report: docs/briefs/m13/research-flutter-shaders-report.md

Context: Thumb Party is a Flutter app (Flutter 3.47.8, Dart 3.13) that runs on iOS, Android phones and tablets, Android TV boxes (often weak GPUs) and Windows desktop. M13 plans two small fragment shaders: one set as `Paint.shader` on a single game shape (cel shading, a glint, a rim light), and one full-screen animated background on menus. A drawn fallback (gradients) is used when a shader can't run. Nothing in the project uses shaders yet, and the Impeller setting is left at the engine default.

Questions (answer each, with the URL of the page that says so, and the page's date or Flutter version if it shows one):
1. How a fragment shader is added and loaded in Flutter today: the pubspec `shaders:` section, `FragmentProgram.fromAsset`, `FragmentShader` uniforms (floats, samplers), and what GLSL subset is allowed (version, no-ops, limits).
2. Does `FragmentShader` set on a `Paint` (in a CustomPainter) work with both renderers, Impeller and Skia? On which platforms is Impeller the default in recent Flutter (iOS, Android, Windows desktop), and what happens on Android devices without Vulkan (the OpenGL ES fallback)?
3. `ImageFilter.shader` and `BackdropFilter` with a shader: which renderer they need, and on which platforms they work.
4. Known problems: first-use jank or warm-up, shader compile failures on some Android GPUs, Windows desktop issues, web-only limits; anything in Flutter's GitHub issues about FragmentProgram crashes or wrong output on Android TV or Mali/Adreno/PowerVR GPUs in 2025–2026.
5. Performance advice for a full-screen animated shader on a weak GPU (resolution, uniforms per frame, caching to an image).
6. The flutter_shaders package (pub.dev): what it adds (AnimatedSampler, SetUniforms), its current version and whether it's maintained.

Start with docs.flutter.dev (search for "fragment shaders" and "Impeller"), api.flutter.dev (FragmentProgram, FragmentShader, ImageFilter.shader), pub.dev/packages/flutter_shaders, and github.com/flutter/flutter issues.

In the report: one section per question, facts as short bullets each with its URL; a "Not confirmed" list; and a 10-line summary of what this means for the plan above (a paint shader on shapes plus a background shader, with a fallback). Keep it under 200 lines.
