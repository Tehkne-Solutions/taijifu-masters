# Modo de série completo

## Formatos

O runtime suporta:

- melhor de três, com duas vitórias necessárias;
- melhor de cinco, com três vitórias necessárias.

O formato padrão é melhor de três e pode ser alterado antes do primeiro round.

## Intervalo entre rounds

Após cada round, a árvore é pausada e uma tela de gerenciamento mostra:

- placar da série;
- vencedor do round;
- inventário temporário de P1 e P2;
- item atualmente protegido;
- ações de proteger e descartar;
- botão para iniciar o round seguinte.

## Proteção

Cada jogador pode proteger um item. O item protegido:

- não entra no pool de perda após derrota;
- não é removido automaticamente quando o inventário está cheio, desde que exista outra opção.

A proteção pode ser trocada durante o intervalo.

## Descarte

Itens podem ser descartados manualmente para abrir espaço e corrigir uma build que ficou desequilibrada.

## Encerramento

Quando um jogador alcança a maioria necessária, a série termina e exibe:

- campeão;
- placar final;
- formato da série;
- rounds disputados;
- inventário final;
- resumo da evolução da build.

## APIs

```text
start_series(best_of)
set_series_format(best_of)
series_summary()
is_series_over()
protect_item(player_index, item_index)
discard_item(player_index, item_index)
protected_item_id(player_index)
```

## Validação

```text
godot --headless --path . --script res://scripts/ci/complete_series_mode_smoke_test.gd
```
