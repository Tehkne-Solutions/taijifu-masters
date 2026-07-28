# Séries contra fantasmas

As corridas assíncronas agora podem ser disputadas em séries completas.

## Formatos

- melhor de 3: vence quem alcançar 2 vitórias;
- melhor de 5: vence quem alcançar 3 vitórias.

Empates são registrados, mas não contam como vitória para nenhum lado.

## Fluxo

1. Selecione um fantasma na biblioteca.
2. Inicie uma série melhor de 3 ou melhor de 5.
3. Dispute a primeira corrida.
4. O resultado atualiza automaticamente o placar da série.
5. Inicie a próxima rodada até alguém alcançar o número necessário de vitórias.
6. Ao final, use a opção de revanche para repetir o formato.

## Runtime

```text
TaijifuGhostRaceSeries
scripts/runtime/ghost_race_series_runtime.gd
```

O estado ativo é preservado em:

```text
user://taijifu-ghost-race-series.json
```

## Ponte Web

```text
taijifuGhostRaceSeriesCommand
taijifuGhostRaceSeriesState
taijifuGhostRaceSeriesStateJson
taijifuGhostRaceSeriesReady
```

Comandos disponíveis:

```json
{"command":"start_best_of_3"}
{"command":"start_best_of_5"}
{"command":"next_round"}
{"command":"rematch"}
{"command":"cancel"}
{"command":"get_state"}
```

## Validação

```bash
godot --headless --path . --script res://scripts/ci/ghost_race_series_smoke_test.gd
```

## Próxima evolução

- recompensas progressivas por série;
- ranking local de rivais;
- múltiplos fantasmas simultâneos;
- torneios eliminatórios.