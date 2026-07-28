# Séries contra fantasmas

As corridas assíncronas podem ser disputadas em séries completas com progressão persistente por rival.

## Formatos

- melhor de 3: vence quem alcançar 2 vitórias;
- melhor de 5: vence quem alcançar 3 vitórias.

Empates são registrados, mas não contam como vitória para nenhum lado.

## Progressão competitiva

Cada série concluída atualiza:

- XP competitivo total;
- fichas de rival;
- sequência atual e melhor sequência de vitórias;
- nível individual de cada fantasma;
- séries disputadas, vencidas e perdidas por rival;
- melhor placar de vitórias em uma série;
- último resultado contra o rival.

### Recompensas

- vitória: 120 XP e 3 fichas;
- derrota: 35 XP;
- melhor de 5: bônus de 60 XP e 1 ficha em caso de vitória;
- varrida sem derrotas: bônus de 80 XP e 2 fichas;
- sequência de vitórias: até 100 XP extras.

## Dificuldade adaptativa

O placar necessário para superar o fantasma aumenta conforme:

1. o nível já alcançado contra aquele rival;
2. o número da rodada dentro da série.

O multiplicador começa em `1.0` e é limitado a `1.75`. O placar-base original permanece disponível em `challenge.base_score`, enquanto o valor ajustado é publicado em `challenge.score`.

## Fluxo

1. Selecione um fantasma na biblioteca.
2. Inicie uma série melhor de 3 ou melhor de 5.
3. Dispute a primeira corrida.
4. O resultado atualiza automaticamente o placar da série.
5. A próxima rodada recebe dificuldade progressiva.
6. Continue até alguém alcançar o número necessário de vitórias.
7. Ao final, as recompensas e o registro do rival são persistidos.
8. Use a opção de revanche para repetir o formato.

## Runtime

```text
TaijifuGhostRaceSeries
scripts/runtime/ghost_race_series_runtime.gd
scripts/runtime/ghost_race_runtime.gd
```

O estado ativo e a progressão são preservados em:

```text
user://taijifu-ghost-race-series.json
```

## Estado público

O estado da série expõe:

```text
progression.total_xp
progression.rival_tokens
progression.win_streak
progression.best_win_streak
progression.rival
difficulty_multiplier
last_series.reward
last_series.sweep
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

O smoke test valida encerramento da série, varrida, XP, fichas, sequência, registro do rival e dificuldade adaptativa.

## Próxima evolução

- ranking local completo de rivais;
- múltiplos fantasmas simultâneos;
- torneios eliminatórios;
- compartilhamento por QR Code;
- sincronização em nuvem.