# Preparação contextual por modo

## Objetivo

Manter a tela completa de loadout dos dois jogadores e adicionar somente as regras e opções relevantes ao modo selecionado.

## Comportamento

A camada contextual acompanha a abertura e o fechamento do `BattlePreparationRuntime`. Quando a preparação está ativa, mostra:

- nome do modo;
- regras resumidas;
- opções específicas;
- estado de prontidão de P1 e P2;
- confirmação final antes da entrada na arena.

## Modos

### Duelo competitivo

Reforça que tropas, pickups e progressão estão desativados e que o loadout é bloqueado após a confirmação.

### Arena com loot

Resume tropas, loot temporário, raridades e sinergias.

### Série roguelite

Mostra melhor de 3/5, inventário máximo e proteção de item.

### Treino

Permite selecionar:

- treino livre;
- domínio Tai;
- controle Ji;
- precisão Fu;
- corrida contra fantasma.

### Desafio do campeão

Permite selecionar:

- Iniciado;
- Mestre;
- Lenda.

A dificuldade configura escalas de unidades, campeão e intervalo de pickups por metadados consumíveis pelos runtimes da arena.

## Validação

```text
godot --headless --path . --script res://scripts/ci/mode_aware_preparation_smoke_test.gd
```
