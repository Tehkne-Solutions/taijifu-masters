# C48 autoload collision hotfix

Remove the `class_name FirstPlayableCombatFeelRuntime` declaration because the same identifier is registered as an autoload singleton in `project.godot`. Godot 4.7 rejects a global class and an autoload with the same name during project bootstrap.

Validation target: C48 gate must reach Godot bootstrap without `hides an autoload singleton` parse errors.

Tehkné Solutions
