# PACK 99 — Direções, classes e eventos de combate

## Classes por build

- `adaptive_staff` → Monk base;
- `aerial_flow` → Ranger ascended;
- `rock_guardian` → Warden base;
- `foundation_breaker` → Reaver ascended;
- `lyra_elementalist` → Mystic ascended;
- `rin_challenger` → Sentinel base.

## Direções

O runtime escolhe a direção visual pelo estado real do lutador:

- direita no chão → SE;
- esquerda no chão → SW;
- direita no ar → NE;
- esquerda no ar → NW.

A troca ocorre sem alterar física, colisão ou controle. Quando o PNG correspondente não está disponível, o fallback existente é espelhado horizontalmente.

## Eventos ligados ao PACK 09

- início de técnica;
- entrada em bloqueio;
- parry;
- quebra de postura;
- desarmamento;
- coleta de arma;
- captura de técnica;
- agarrão;
- estado e interação elemental;
- derrota.

Cada evento aponta para um VFX específico e mantém fallback gerado em runtime.

## Validação

```text
godot --headless --path . --script res://scripts/ci/pack_99_combat_event_smoke_test.gd
```

O gate confirma o autoload, os seis mapeamentos de build, as quatro direções e o registro dos PACKS 07 e 09.
