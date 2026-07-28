# Dificuldade real e objetivos de treino

## Escalonamento de combate

A dificuldade selecionada na preparação agora altera unidades e Champion Dragon já criados na arena.

São escalados:

- vida atual;
- vida máxima;
- dano;
- dano de postura;
- presença visual.

Unidades comuns usam `unit_scale`. O Champion Dragon usa `champion_scale`.

## Frequência de pickups

O intervalo configurado pela dificuldade passa a limitar diretamente o cronômetro interno do `ProceduralArenaPickupRuntime`.

- Iniciado: até 7 segundos;
- Mestre: até 9 segundos;
- Lenda: até 12 segundos.

## Objetivos de treino

### Livre

Praticar por 30 segundos.

### Tai

Percorrer 1.200 unidades de distância pela arena.

### Ji

Concluir três projeções.

### Fu

Executar três aparos.

### Fantasma

Permanecer 45 segundos na corrida contra fantasma.

O HUD exibe progresso, meta e conclusão em tempo real.

## API

```text
objective_snapshot()
reset_objectives()
```

## Validação

```text
godot --headless --path . --script res://scripts/ci/combat_difficulty_training_smoke_test.gd
```
