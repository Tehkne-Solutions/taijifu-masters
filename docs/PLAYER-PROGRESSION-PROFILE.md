# Perfil de progressão e loja de treino

## Perfil consolidado

O runtime reúne:

- nível e XP de treinamento;
- fichas disponíveis;
- medalhas;
- certificações;
- variantes de mestre liberadas;
- estatísticas de batalhas e sessões de treino;
- itens adquiridos;
- histórico de compras.

## Loja de treino

Itens disponíveis:

- Estandarte Tai — 3 fichas;
- Estandarte Ji — 3 fichas;
- Estandarte Fu — 3 fichas;
- Aura do Discípulo — 5 fichas;
- Moldura dos Mestres — 8 fichas;
- Espaço Extra de Preset — 6 fichas.

As compras validam saldo, impedem duplicidade e descontam fichas diretamente da progressão persistente.

## Persistência

```text
user://taijifu-player-profile.json
```

## API

```text
open_profile()
close_profile()
purchase(item_id)
profile_snapshot()
owns_item(item_id)
record_battle_result(won)
record_training_session()
```

## Validação

```text
godot --headless --path . --script res://scripts/ci/player_progression_profile_smoke_test.gd
```
