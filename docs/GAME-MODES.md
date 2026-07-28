# Sistema de modos de jogo

## Objetivo

Separar claramente as experiências do Taijifu Masters e ativar apenas os runtimes necessários em cada modo.

## Modos

### Duelo competitivo

Combate técnico puro. Desativa tropas, pickups, sinergias, progressão entre rounds e modo de série.

### Arena com loot

Ativa tropas, Champion Dragon, pickups procedurais e sinergias. Não mantém inventário entre rounds.

### Série roguelite

Ativa toda a camada de arena e também progressão de loot, inventário, proteção, perdas e melhor de três/cinco.

### Treino Tai · Ji · Fu

Desativa interferências da arena e mantém os runtimes de gravação, fantasmas, maestria e certificação.

### Desafio do campeão

Ativa tropas neutras, recursos limitados e Champion Dragon, sem progressão completa de série.

## API

```text
apply_mode(mode_id)
open_mode_selector()
close_mode_selector()
mode_snapshot()
available_modes()
is_feature_enabled(feature)
```

## Validação

```text
godot --headless --path . --script res://scripts/ci/game_mode_smoke_test.gd
```
