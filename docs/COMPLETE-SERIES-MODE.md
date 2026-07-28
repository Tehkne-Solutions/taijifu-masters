# Modo de série completo

## Formatos

- melhor de três: duas vitórias;
- melhor de cinco: três vitórias.

## Intervalo entre rounds

A partida pausa após cada round e mostra:

- placar da série;
- vencedor do round;
- três recompensas para o vencedor;
- inventários de P1 e P2;
- proteção de um item;
- descarte estratégico;
- botão para o próximo round.

O próximo round só pode começar depois que a recompensa for escolhida.

## Proteção e perda

Cada jogador pode proteger um item. Esse item não entra no pool de perda de 40% após derrota e não é removido automaticamente quando houver outra opção no inventário cheio.

## Encerramento

Ao alcançar a maioria necessária, o runtime mostra:

- campeão;
- placar final;
- rounds disputados;
- build final e inventário acumulado;
- opção de iniciar nova série.

## Validação

```text
godot --headless --path . --script res://scripts/ci/complete_series_mode_smoke_test.gd
```
