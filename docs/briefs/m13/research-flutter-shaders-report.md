# Flutter fragment shaders on our four targets (research for M13's toon shader)

Researched 2026-11-08. Project baseline: Flutter 3.47.8 / Dart 3.13 (docs site says "reflects Flutter
3.47"); pages are quoted with their own "last updated" dates. Intended repo path:
`docs/briefs/m13/research-flutter-shaders-report.md`. Version dates: 3.41 Feb 2026, 3.44 May 2026,
3.47 Aug 2026, 3.50 scheduled Nov 2026 — https://docs.flutter.dev/release/archive

## 1. Adding and loading a fragment shader today

- `.frag` GLSL files under `flutter: shaders:` in pubspec.yaml; impellerc compiles them at build time and
  ships them as assets (package shaders as `packages/$pkg/...`); debug builds recompile on hot reload.
  https://docs.flutter.dev/ui/design/graphics/fragment-shaders (last updated 2026-05-05)
- `FragmentProgram.fromAsset('shaders/x.frag')` once, then `program.fragmentShader()` per uniform set; the
  implementation caches programs per asset key, so repeated `fromAsset` is cheap.
  https://api.flutter.dev/flutter/dart-ui/FragmentProgram/fromAsset.html
- `FragmentShader` is meant to be reused; two shaders with different uniforms alive at once need two
  `fragmentShader()` calls. https://api.flutter.dev/flutter/dart-ui/FragmentShader-class.html
- Uniforms: floats `setFloat(index, v)` (one call per vec2/3/4 component), samplers
  `setImageSampler(index, image, {filterQuality})`, sampler indices start at 0. Since 3.44 there is a
  name-based API: `shader.getUniformFloat('uTime').set(1.2)`, `getUniformVec2/3/4`, `getUniformFloatArray`;
  3.44 also warns at build time about non-Skia-compatible shaders.
  https://blog.flutter.dev/whats-new-in-flutter-3-44-b0cc1ad3c527
- Maintainers intend to deprecate index-based `setFloat` (open 2026-10-26):
  https://github.com/flutter/flutter/issues/195357 ; index order breaks with `layout(location=...)`
  (closed 2026-10-26): https://github.com/flutter/flutter/issues/194661
- GLSL subset (docs page above): any version `460 core` down to `100`; no UBOs/SSBOs; `sampler2D` only;
  only 2-arg `texture(sampler, uv)`; no extra varying inputs; unsigned ints and bools unsupported; Skia
  ignores precision hints; no vertex shaders (https://github.com/flutter/flutter/issues/177174); sampler
  tile mode fixed to `TileMode.clamp`. Use `FlutterFragCoord()`, not `gl_FragCoord`; `fragColor` must be
  premultiplied 0..1. Header:
  https://github.com/flutter/flutter/blob/master/engine/src/flutter/impeller/compiler/shader_lib/flutter/runtime_effect.glsl
- 3.41 added `decodeImageFromPixelsSync` and float32 texture targets.
  https://flutter.dev/blog/whats-new-in-flutter-3-41
- Since 3.44 the GLES sampling Y-flip is gone; compat guard is
  `#if defined(IMPELLER_TARGET_OPENGLES) && !defined(IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED)`
  (https://github.com/flutter/flutter/pull/187316, merged 2026-06-03; flip retired in
  https://github.com/flutter/flutter/pull/186556, merged 2026-05-26). The docs page above still shows the
  unguarded flip — docs predate the change.

## 2. Paint.shader, both renderers, and Impeller defaults

- Yes, `Paint.shader` works on both: "Both the Skia and Impeller backends support writing a custom shader.
  Except where noted, the same instructions apply to both." (`Canvas.drawImage` ignores `Paint.shader`.)
  https://docs.flutter.dev/ui/design/graphics/fragment-shaders
- Impeller status (page last updated 2026-08-21) — https://docs.flutter.dev/perf/impeller
  - iOS: Impeller only, cannot switch to Skia. Web: still Skia.
  - Android: default on API 29+; below that or without Vulkan, Impeller "falls back to the legacy OpenGL
    renderer", no action needed.
  - Windows / macOS / Linux: Impeller default as of 3.47 (opt-out still possible this release).
- 3.47 release notes confirm the Windows change: "Makes impeller the default renderer for windows" #188140,
  "Switches Windows to OpenGLESSDF" #187877, "[Impeller][Windows] fix black screen on OpenGL fallback"
  #187288. https://docs.flutter.dev/release/release-notes/release-notes-3.47.0
- Windows Impeller = GLES on ANGLE over D3D11 ("OpenGLESSDF"), per log lines in
  https://github.com/flutter/flutter/issues/191860 and https://github.com/flutter/flutter/issues/192994
- Android selection (archived engine doc, clearest write-up): Vulkan needs API >= 29, Vulkan >= 1.1 and the
  required extensions, else OpenGL — Vulkan-less boxes include old Android, 32-bit userspace and
  RAM-constrained sticks. https://github.com/flutter-team-archive/engine/blob/main/impeller/docs/android.md
- Which renderer that GL fallback is, is muddled: docs say "legacy OpenGL renderer", the archived doc said
  Skia's GLES, but Impeller's GLES backend is used on such devices ("[Impeller] Fall back to OpenGL ES on
  older Adreno GPUs", merged 2025-10-30: https://github.com/flutter/flutter/pull/177747 ; line "Renderer:
  Impeller GLES (default on this Flutter version)" in https://github.com/flutter/flutter/issues/186186).
  Settle it per device with `flutter run --verbose-system-logs` (prints `Using the Impeller rendering
  backend (Vulkan)`/`(OpenGLES)` or Skia's line): https://github.com/flutter/flutter/issues/189767
- The sheet behind https://flutter.dev/go/can-i-use-impeller (last updated 2025-11-19) predates 3.47
  (Windows/macOS/Linux "Default Impeller" only on the `main` row); use docs.flutter.dev instead.

## 3. ImageFilter.shader / BackdropFilter with a shader

- Impeller only; on other backends `ImageFilter.shader` throws `UnsupportedError`. Check
  `ui.ImageFilter.isShaderFilterSupported` at runtime.
  https://api.flutter.dev/flutter/dart-ui/ImageFilter/ImageFilter.shader.html ,
  https://api.flutter.dev/flutter/dart-ui/ImageFilter/isShaderFilterSupported.html
- Docs repeat the warning ("only supported by the Impeller backend... will throw an error") and add: the
  engine sets the first `vec2` uniform to the input size and sampler 0 to the input image (don't set them
  from Dart); wrap `BackdropFilter` in a `ClipRect` or the filter covers the screen.
  https://docs.flutter.dev/ui/design/graphics/fragment-shaders
- Platforms: iOS (Impeller only), Android where Impeller runs (Vulkan or Impeller GLES), Windows 3.47+
  (Impeller default), macOS/Linux 3.47+. Not web. Confidence high for the rule, medium that every Impeller
  GLES device does it well (see bugs below).
- Gotchas: `Opacity` above an `ImageFilter.shader` is ignored — pass opacity as a uniform (team: doing it
  automatically would need an extra pass), open 2025-06-30: https://github.com/flutter/flutter/issues/171378 .
  Disposing shaders + BackdropFilter layers crashed Mali Vulkan devices (open):
  https://github.com/flutter/flutter/issues/187140

## 4. Known problems

**Warm-up / first use**
- Skia compiles at load; docs advise precaching programs and reusing `FragmentShader` objects.
  https://docs.flutter.dev/ui/design/graphics/fragment-shaders
- Windows, master: awaiting `fromAsset` before `runApp` no longer warms the shader — one later frame freezes
  ~1.5 s; on stable 3.47.4 that work happened before the first frame (open 2026-09-19):
  https://github.com/flutter/flutter/issues/193048
- Windows Impeller cold start ~1.2 s vs 165 ms on Skia (3.47.1, minimal app), open 2026-08-27:
  https://github.com/flutter/flutter/issues/191860
- Android low-end, Impeller GLES: default GLES pipelines built at surface creation took > 5 s in the vendor
  shader compiler (Mali, PowerVR), blocking the platform thread → ANR (3.44.9, open 2026-11-03):
  https://github.com/flutter/flutter/issues/195903 (related #195311)

**Windows-specific**
- `drawRect` with a FragmentShader is not evaluated directly: 3 render passes / 2 MSAA resolves per rect
  (30 ms/frame for 140 rects at 2560x1440 vs 2.7 ms on Skia; "present in released 3.47 series"), open
  2026-09-18: https://github.com/flutter/flutter/issues/192994
- Same fallback shifts a shader by the fractional part of the draw origin (≤ half a pixel), open 2026-09-26:
  https://github.com/flutter/flutter/issues/193389
- ANGLE/D3DCompile crash (0xc0000005 in d3dcompiler_47.dll) after loading FragmentPrograms, closed
  2026-09-29: https://github.com/flutter/flutter/issues/190809 ; 3.47 now warns at compile time when a
  shader uses both a texture sampler and early returns (the trigger), closed 2026-09-15:
  https://github.com/flutter/flutter/issues/191969
- RAM differs a lot Impeller vs Skia on Windows (simple_shader sample, titled 100 MB vs 450 MB), open
  2026-08-21: https://github.com/flutter/flutter/issues/191497

**Android GPU-specific**
- Impeller GLES: `FragmentProgram` + SIGABRT on the *second cold launch* (`render_pass_gles.cc` CHECK, stale
  pipeline cache), 3.41.9, open; workaround: disable Impeller (Skia works across launches).
  https://github.com/flutter/flutter/issues/186186
- Mali Vulkan: HandleUsingDestroyedMutex crash while disposing FragmentProgram / BackdropFilter resources,
  0.23% crash rate on 3.41.6, open 2026-05-27: https://github.com/flutter/flutter/issues/187140
- PowerVR (Pixel 10): vkDestroyDevice hang / ANR at engine teardown, open 2026-11-06:
  https://github.com/flutter/flutter/issues/196094
- Android TV, PowerVR BXE-4-32: Vulkan leaves stale/ghosted frames; forcing `impeller-backend=opengles`
  (manifest `io.flutter.embedding.android.ImpellerBackend`) is correct, open 2026-07-21:
  https://github.com/flutter/flutter/issues/189767
- Skia path: image samplers fed `toImageSync` images abort on Android (GrResourceCache, SIGTRAP), open
  2026-11-03: https://github.com/flutter/flutter/issues/195888

**Web-only** (not one of our four targets)
- Web runs Skia and validates at runtime: `dFdx/dFdy/fwidth` rejected at shader creation (open 2026-01-14):
  https://github.com/flutter/flutter/issues/180959 ; `getImageSampler` threw `UnsupportedError` on
  CanvasKit/Skwasm (closed 2026-10-13): https://github.com/flutter/flutter/issues/194290 ; disposing a
  shader before `Picture.toImage` changes pixels in Chrome (closed 2026-09-23):
  https://github.com/flutter/flutter/issues/193221

Nothing I fetched tried to instruct me; no prompt-injection content encountered.

## 5. Performance advice for a full-screen animated shader on a weak GPU

- Reuse one `FragmentShader` and precache programs before the animation; a second shader only when two
  uniform sets must coexist. https://docs.flutter.dev/ui/design/graphics/fragment-shaders
- Cost is per fragment and per pass, not per uniform: one full-screen `drawRect` is the cheap shape; every
  extra shader-painted rect adds a 3-pass sequence on Windows Impeller (30 vs 2.7 ms, 140 rects).
  https://github.com/flutter/flutter/issues/192994
- Docs' caching pattern: draw the expensive thing once into a `Picture`, `toImageSync()` it, feed the image
  to a cheap shader via `setImageSampler`, redraw only when inputs change (SDFPainter example); widget
  equivalent: `AnimatedSampler`/`SnapshotWidget`.
  https://docs.flutter.dev/ui/design/graphics/fragment-shaders ,
  https://pub.dev/documentation/flutter_shaders/latest/flutter_shaders/AnimatedSampler-class.html
- GPU-side: lower precision where supported; real branches for uniform/simple varying branches, no complex
  varying branches; profile on old hardware, no universal rule.
  https://github.com/flutter/flutter/blob/main/docs/engine/impeller/docs/shader_optimization.md
- Per-frame uniforms: only what changes (time, size, two colours), name-based API; per-frame `setFloat` is
  normal (`InkSparkle`), no documented per-uniform cost. https://github.com/flutter/flutter/issues/194661
- Keep the draw origin on whole device pixels (half-pixel shift otherwise):
  https://github.com/flutter/flutter/issues/193389
- Resolution (my inference, no doc): a 4K full-screen shader is ~8.3 M fragments/frame; render into a
  half/quarter-resolution image and scale up (the `toImageSync`+sampler pattern). Test on the TV box.
- Avoid `ImageFilter.shader`/`BackdropFilter` for the menu background: extra pass plus the bugs above
  (inference).

## 6. flutter_shaders (pub.dev)

- Version 0.1.5, published "31 days ago" (~2026-10-08), publisher flutter.dev, 133 likes, 150 pub points,
  1.57M downloads, all platforms. https://pub.dev/packages/flutter_shaders
- Maintained, first-party: source moved from jonahwilliams/flutter_shaders to flutter/packages in 0.1.4;
  0.1.5 needs Flutter 3.41 / Dart 3.11. https://pub.dev/packages/flutter_shaders/changelog — 0.1.4 is in
  the changelog but absent from /versions (its page 404s), so it looks retracted.
- What it adds: `AnimatedSampler` (paints child to a texture and hands the `ui.Image` to a shader, with an
  `enabled` bypass; cannot capture platform views), `ShaderBuilder` (+`precacheShader`, caches
  FragmentPrograms), `SetUniforms` extension (`shader.setFloatUniforms((s) { s.setColor(...); ... })`, no
  manual indices), `ShaderInkFeature`, plus a pixelation shader.
  https://pub.dev/documentation/flutter_shaders/latest/ ,
  https://pub.dev/documentation/flutter_shaders/latest/flutter_shaders/SetUniforms.html

## Not confirmed

1. Whether Android's non-Vulkan "OpenGL ES fallback" is Impeller GLES or Skia GLES in 3.47.8 — sources
   disagree; `--verbose-system-logs` on the actual TV box settles it.
2. That `ImageFilter.shader` works correctly on every Impeller GLES Android/TV device (only the "Impeller
   only" rule is documented).
3. Whether #192994 (3 passes per shader rect) or #193389 (half-pixel shift) are fixed in a 3.47.x patch —
   both are open.
4. Exact date of flutter_shaders 0.1.5 ("31 days ago"); whether 0.1.4 was retracted.
5. Exception type from `FragmentProgram.fromAsset` when a runtime compile fails on Skia (undocumented).
6. Whether `setFloat` is deprecated in 3.50+ (#195357 open) and what 3.50 (Nov 2026) contains.
7. The render-resolution advice in §5 is my inference; no official doc found.
8. Whether the docs' GLES Y-flip snippet is stale: engine PRs removed the flip in 3.44, docs updated 2026-05-05.

## Summary for the plan (paint shader on shapes + full-screen background, with a fallback)

1. Feasible on all four targets: `Paint.shader` works on Skia and Impeller alike, one code path serves all.
2. Skip `ImageFilter.shader`/`BackdropFilter`: Impeller-only, throws on Skia, worst open bugs; keep Paint.
3. Load both programs once at startup (`fromAsset` caches per key), reuse one shader each, try/catch → gradient.
4. Use name-based uniforms (`getUniformFloat('uTime').set(...)`); index-based `setFloat` is buggy and doomed.
5. Draw the background as ONE full-screen rect: on Windows Impeller each extra shader rect adds 3 draws.
6. Windows budget: Impeller cold start ~1.2 s plus a ~1.5 s shader warm-up frame on 3.47 — measure on the PC.
7. TV box risk: Impeller GLES can burn seconds in the vendor compiler at startup (ANR, #195903) — "slow" is
   "can't run".
8. Escape hatch if a TV renders wrong: manifest `ImpellerBackend=opengles`, or `EnableImpeller=false` for Skia.
9. Keep the toon shader cheap: mediump, few uniforms, integer-pixel origin; `toImageSync` cache the glint.
10. `flutter_shaders` 0.1.5 is optional but handy: ShaderBuilder precache, AnimatedSampler, SetUniforms.
