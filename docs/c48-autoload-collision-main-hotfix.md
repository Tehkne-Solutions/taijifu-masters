# C48 main hotfix

The C48 merge registered `FirstPlayableCombatFeelRuntime` as an autoload singleton while its script also declared the same `class_name`. Godot 4.7 rejects that namespace collision during bootstrap.

The fix removes the global `class_name` declaration and keeps the autoload singleton registration as the single authoritative name.

Tehkné Solutions
