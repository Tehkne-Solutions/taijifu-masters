# Corrida multirrival contra fantasmas

O modo multirrival permite disputar uma única tentativa contra dois ou três fantasmas da biblioteca local.

## Seleção

Os rivais são escolhidos primeiro pela posição no ranking local e depois pela ordem da biblioteca. O limite atual é de três fantasmas.

## Execução

- o jogador grava uma nova tentativa;
- o rival melhor classificado é reproduzido visualmente;
- todos os demais rivais permanecem ativos no placar lógico;
- a duração utiliza a maior gravação entre os participantes;
- o placar é atualizado durante a tentativa;
- ao terminar, o jogador recebe uma colocação geral.

A arquitetura expõe `visual_mode = leader_only` porque o runtime de replay atual controla apenas uma reprodução visual. Os três rivais já participam simultaneamente da classificação e do resultado.

## Runtime

```text
TaijifuMultiGhostRace
scripts/runtime/multi_ghost_race_runtime.gd
```

## Persistência

```text
user://taijifu-multi-ghost-race.json
```

São preservados o último resultado e as últimas 30 corridas.

## Ponte Web

```text
taijifuMultiGhostRaceCommand
taijifuMultiGhostRaceState
taijifuMultiGhostRaceStateJson
taijifuMultiGhostRaceReady
```

Comandos:

```json
{"command":"start_2"}
{"command":"start_3"}
{"command":"finish"}
{"command":"cancel"}
{"command":"get_state"}
```

## Critérios de validação

- exige pelo menos dois fantasmas;
- limita a disputa a três rivais;
- inclui jogador e rivais na classificação;
- desempates favorecem a tentativa do jogador;
- identifica somente um rival como líder visual;
- persiste até 30 resultados.

## Validação

```bash
godot --headless --path . --script res://scripts/ci/multi_ghost_race_smoke_test.gd
```