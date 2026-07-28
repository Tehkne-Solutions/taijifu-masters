# Progressão de loot entre rounds

## Objetivo

Criar uma camada roguelite curta dentro de cada série de batalhas, permitindo que vitórias alterem a build dos rounds seguintes e que derrotas tenham custo parcial.

## Recompensas

Após derrotar o adversário, o vencedor recebe três opções e escolhe uma. A seleção automática usa a primeira opção após sete segundos para não travar o fluxo.

O pool inicial inclui armas, armaduras, relíquias e técnicas, com raridades rara, épica e lendária.

## Inventário da série

Cada jogador possui até cinco itens temporários. Ao exceder o limite, o item mais antigo é removido.

Os efeitos são reaplicados quando o lutador é recriado para um novo round.

## Derrota

O jogador derrotado perde 40% do inventário atual, com mínimo de um item quando houver loot armazenado. Os itens perdidos são escolhidos aleatoriamente.

## APIs

- `choose_reward(player_index, choice_index)`;
- `inventory_snapshot(player_index)`;
- `pending_choices(player_index)`;
- `round_wins(player_index)`;
- `reset_series()`.

## Validação

```text
godot --headless --path . --script res://scripts/ci/series_loot_progression_smoke_test.gd
```
