# Corrida contra fantasmas — placar ao vivo

O Taijifu Masters agora transforma um fantasma selecionado na biblioteca em um desafio assíncrono mensurável.

## Fluxo

1. O jogador seleciona um fantasma na biblioteca local.
2. Entra em uma arena.
3. Inicia a corrida.
4. O jogo grava a tentativa atual e reproduz o fantasma simultaneamente.
5. O placar mostra tempo restante, pontuação atual, alvo e diferença.
6. Ao fim do tempo, o resultado é classificado como `venceu`, `perdeu` ou `empatou`.

## Runtime

```text
TaijifuGhostRace
scripts/runtime/ghost_race_runtime.gd
```

O runtime usa a duração original do replay como limite da corrida e calcula a pontuação provisória com a mesma fórmula usada nas tentativas normais.

## Segurança

- o replay pessoal continua protegido;
- a corrida não importa ranking, inventário ou recompensas;
- cancelar ou encerrar a corrida interrompe reprodução e gravação;
- a comparação usa somente métricas técnicas do desafio.

## Interface Web

```text
web/taijifu-ghost-race-web.js
scripts/inject-ghost-race-web.py
```

O painel atualiza a cada 250 ms e apresenta:

- tempo restante;
- pontuação do jogador;
- pontuação-alvo;
- diferença atual;
- precisão e elo;
- resultado final.

## Ponte Web

```text
taijifuGhostRaceCommand
taijifuGhostRaceState
taijifuGhostRaceStateJson
taijifuGhostRaceReady
```

Comandos:

```json
{"command":"start_selected"}
{"command":"finish"}
{"command":"cancel"}
{"command":"get_state"}
```

## Validação

```bash
godot --headless --path . --script res://scripts/ci/ghost_race_smoke_test.gd
```

O teste verifica cronômetro, alvo, diferença de pontuação e exposição do resultado final.

## Próxima evolução

- histórico de tentativas por fantasma;
- melhor resultado pessoal por desafio;
- filtros por arma e caminho Tai/Ji/Fu;
- ranking local de desafios concluídos.
