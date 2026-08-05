# C54 — Godot Runtime Image Load Hotfix

Signature: Tehkné Solutions

## Observed failure

After the C54 static contract hotfix passed, Godot 4.7.1 reached the runtime bench but failed to parse it:

- the raw PNG was preloaded as a Texture2D before a Godot importer resource existed;
- the external assembler method call was statically resolved by GDScript and failed during parse;
- the scene then remained open and the gate ended as a timeout instead of reporting the parse failure directly.

## Correction

The visual bench now:

- reads the canonical PNG with `Image.load_from_file`;
- creates the runtime texture with `ImageTexture.create_from_image`;
- derives bounds by scanning the real alpha channel rather than depending on an imported texture;
- invokes modular assembler methods dynamically through `call`, preserving the same production implementation while avoiding brittle external static resolution;
- forbids reintroduction of raw PNG `preload`;
- adds a finite Godot `--quit-after` guard;
- recognizes runtime texture failures as fatal gate markers.

The BASE-00 art master, its SHA-256, QA, pivot and baseline remain unchanged. No gameplay or visual-progress promotion is made by this hotfix.

Tehkné Solutions
