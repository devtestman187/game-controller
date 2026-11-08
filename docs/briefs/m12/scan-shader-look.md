job: read-only scan — is a shader or cartoon-look restyle of the existing design planned or written down anywhere?
stop: after the report.
read: every .md file in the repository, on every branch · the main checkout E:\AI\game-controller (read only, it may hold uncommitted docs)

Owner's words (Nov 8): "Isn't there new shaders applied to the existing design to give it a more cartoony look? Check the other .md files in the repository as well."

What to do:
1. Search every .md file, case-insensitive, for: shader, fragment, GLSL, FragmentProgram, cartoon, cartoony, toon, cel, outline, stylized, art style, visual style, look and feel, polish, graphics, restyle, redesign, theme, glow, gradient, palette.
2. Cover all branches, not only this one: `git for-each-ref --format='%(refname)' refs/heads refs/remotes` then `git grep -i -n -E '<terms>' <ref> -- '*.md'` for each ref. Also search the main checkout's working tree (its .md files may not be committed).
3. Also check the code once, briefly: any `.frag` file, `FragmentProgram`, or `shaders:` in a pubspec.yaml, on any branch.
4. Skip plain false hits (e.g. "theme" meaning Flutter ThemeData for colours, "polish" of a text, "outline" meaning OutlinedButton) but list anything about how the game should look.

in the report: for each real hit, the branch (or "main checkout, uncommitted"), file:line, and the line quoted (one line); then a one-paragraph answer: is a shader / cartoon look planned, in which milestone, and where it's written. If nothing, say so and list the terms and refs searched.
rules: change no file but the report · write only the report.
allow: docs/briefs/m12/scan-shader-look-report.md
report: docs/briefs/m12/scan-shader-look-report.md
