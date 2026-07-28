# Histórico competitivo de corridas contra fantasmas

O histórico transforma cada fantasma salvo em um rival persistente, permitindo acompanhar evolução técnica por desafio.

## Métricas registradas

- tentativas totais;
- vitórias, derrotas e empates;
- taxa de vitória;
- melhor pontuação;
- melhor precisão;
- maior elo;
- últimas 40 tentativas;
- diferença de pontos e duração de cada corrida.

## Persistência

```text
user://taijifu-ghost-race-history.json
```

## Runtime

```text
TaijifuGhostRaceHistory
scripts/runtime/ghost_race_history_runtime.gd
```

O runtime de corrida envia automaticamente cada resultado concluído ao histórico. Corridas canceladas não são registradas.

## Interface Web

```text
web/taijifu-ghost-race-history-web.js
scripts/inject-ghost-race-history-web.py
```

O painel apresenta o retrospecto de cada fantasma, melhor desempenho e taxa de vitórias.

## Ponte Web

```text
taijifuGhostRaceHistoryCommand
taijifuGhostRaceHistoryState
taijifuGhostRaceHistoryStateJson
taijifuGhostRaceHistoryReady
```

Comandos:

```json
{"command":"get_state"}
{"command":"get_record","target_id":"ghost-id"}
{"command":"clear"}
```

## Validação

```bash
godot --headless --path . --script res://scripts/ci/ghost_race_history_smoke_test.gd
```

## Próxima evolução

- filtros por arma e caminho Tai/Ji/Fu;
- ranking local de fantasmas;
- séries melhor de três e melhor de cinco;
- múltiplos fantasmas simultâneos.
