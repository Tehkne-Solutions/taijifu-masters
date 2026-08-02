# VM01-A4 — DPI-safe capture normalization

Signature: Tehkné Solutions

The Windows Godot window can expose a client area smaller than the requested 1920×1080 because of window decoration and DPI scaling. The VM01-A4 visual gate must therefore distinguish between:

- runtime viewport/client size, which may vary slightly by host OS/window decoration; and
- canonical evidence size, which is fixed at 1920×1080.

The bench scene now captures the actual viewport image, verifies that its aspect ratio remains 16:9 within tolerance, and normalizes the saved evidence to exactly 1920×1080 before writing the PNG.

This does not alter the logical 1280×720 bench layout, FighterController coordinates, art, pivot, or hitboxes. It only removes host-window decoration/DPI variance from the evidence artifact.

`CHARACTER_LOCK=PASS` remains blocked until the normalized capture is visually reviewed.
