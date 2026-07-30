# Taijifu Masters — First Playable Vertical Slice

## Objetivo

Entregar o menor caminho jogável e verificável do projeto:

`P1 versus CPU → contagem regressiva → combate → KO → revanche ou retorno ao protótipo completo`.

Esta vertical slice não substitui `scenes/main.tscn`. Ela isola o núcleo de combate para estabilização antes de retomarmos torneios, ranking, progressão, economia ou produção ampla de assets.

## Cena

```text
scenes/vertical_slice/first_playable.tscn
```

Composição:

```text
FirstPlayable
├── Arena
├── TacticalBotRuntime
├── Camera2D
└── HUD
```

Os dois lutadores são instanciados em runtime a partir de:

```text
scenes/fighter/fighter.tscn
```

## Escopo da Sprint 00

- arena `TriplePathArena` reutilizada sem pontos estratégicos visíveis;
- dois lutadores com presets fixos;
- jogador local no índice 1;
- IA no índice 2;
- IA inicialmente no nível `disciple` e personalidade `aggressive`;
- contagem regressiva e comando `LUTEM`;
- fluxo de KO e resultado;
- revanche com `Enter`;
- retorno ao protótipo completo com `Esc`;
- câmera dinâmica e HUD mínimo;
- smoke test headless no GitHub Actions.

## Controles

```text
A / D  mover
W      saltar
S      queda rápida
F      atacar
Q      esquivar
R      defender / aparar
G      impulso
E      agarrar
C      elemento
H      eco
T      trocar arma
Enter  reiniciar partida
Esc    voltar para scenes/main.tscn
```

## Execução local

No editor Godot, abra e execute:

```text
scenes/vertical_slice/first_playable.tscn
```

Pelo terminal, com Godot 4.3 disponível:

```bash
godot --path . scenes/vertical_slice/first_playable.tscn
```

## Validação automatizada

```bash
godot --headless --editor --path . --quit-after 3
godot --headless --path . --script tests/first_playable_scene_smoke.gd
```

Resultado esperado:

```text
FIRST_PLAYABLE_SMOKE_OK
```

O smoke confirma:

- carregamento da cena;
- presença de arena, IA, câmera e HUD;
- instanciação de exatamente dois lutadores;
- índices de jogador `[1, 2]`.

## Gate de conclusão da Sprint 00

A Sprint 00 está tecnicamente concluída quando:

1. a cena carrega sem erro de parser;
2. o smoke headless passa;
3. dois placeholders entram em combate;
4. a IA controla o segundo lutador;
5. um KO leva ao estado de resultado;
6. `Enter` inicia uma revanche;
7. a cena principal antiga permanece intacta.

## Próxima sprint

Sprint 01 — estabilização do combate:

- bloquear ações sem congelar gravidade durante a contagem regressiva;
- corrigir hitbox/hurtbox e virada lateral;
- limitar soft locks de agarrão, ataque e queda;
- adicionar timeout de partida;
- executar partidas automáticas repetidas em modo headless.

Assinatura: Tehkné Solutions
