# Prontidão individual, gamepads e entrada de arena

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Transformar a preparação em um fluxo completo de início de partida:

1. cada jogador monta o próprio loadout;
2. cada jogador confirma sua prontidão separadamente;
3. loadouts confirmados ficam bloqueados;
4. a partida começa somente com ambos prontos;
5. os lutadores entram na arena sem aceitar comandos;
6. a física e os controles são liberados somente após `LUTEM`.

---

## Prévia cosmética completa

Novo presenter:

```text
scripts/preparation/preparation_avatar_preview.gd
```

A prévia usa:

- o atlas real do personagem;
- animação idle;
- sockets oficiais;
- acessório de cabeça;
- item de costas;
- amuleto;
- pet;
- orientação diferente para P1 e P2.

A prévia não cria um lutador físico e não interfere na arena.

---

## Prontidão individual

Cada painel possui dois estados:

```text
AGUARDANDO CONFIRMAÇÃO
PRONTO
```

Ao confirmar:

- o loadout é persistido;
- a navegação do jogador é bloqueada;
- a ficha permanece visível;
- confirmar novamente remove a prontidão e libera a edição.

A partida não aceita início com apenas um jogador pronto.

### P1 — teclado

```text
W/S        categoria
A/D        opção
F          confirmar ou editar novamente
1          restaurar padrão
```

### P2 — teclado

```text
↑/↓        categoria
←/→        opção
Num1       confirmar ou editar novamente
2          restaurar padrão
```

---

## Gamepads na preparação

A preparação registra ações próprias por dispositivo.

### Controle 1 — P1

```text
Analógico esquerdo ou D-pad   navegar
A                             confirmar
Y                             restaurar padrão
```

### Controle 2 — P2

```text
Analógico esquerdo ou D-pad   navegar
A                             confirmar
Y                             restaurar padrão
```

Dispositivos são separados por índice:

```text
device 0 → P1
device 1 → P2
```

---

## Gamepads no combate

### Mapeamento

```text
Analógico esquerdo   movimento
A                    salto
B                    esquiva
X                    técnica contextual
Y                    empurrão
LB                   agarrão
RB                   defesa/aparo
L3                   elemento
R3                   eco de técnica
Back                 troca de arma
```

Cada jogador usa o próprio dispositivo.

---

## Entrada de arena

Novo runtime:

```text
scripts/runtime/arena_entrance_runtime.gd
```

Novo estado da partida:

```text
PREPARATION
ENTRANCE
BATTLE
```

### Sequência

1. os lutadores são instanciados;
2. o fluxo móvel da arena permanece parado;
3. a física dos lutadores é desativada;
4. as colisões corporais são temporariamente suspensas;
5. P1 entra pela esquerda;
6. P2 entra pela direita;
7. os nomes são exibidos;
8. aparece `VS`;
9. aparece a contagem `3 • 2 • 1`;
10. aparece `LUTEM`;
11. posições finais são fixadas;
12. a física é reativada;
13. a arena inicia o fluxo de batalha;
14. o estado muda para `BATTLE`.

Duração padrão:

```text
2,15 segundos
```

---

## Segurança competitiva

Durante a entrada:

- entradas de movimento não são processadas;
- ataques não são processados;
- gravidade não é processada;
- hitboxes de ataque permanecem desativadas;
- lutadores não podem colidir entre si;
- a arena não começa a fechar;
- nenhum recurso é consumido.

A entrada é uma camada de apresentação, não uma fase jogável.

---

## Arquivos centrais

```text
scripts/preparation/preparation_avatar_preview.gd
scripts/runtime/battle_preparation_runtime.gd
scripts/runtime/arena_entrance_runtime.gd
scripts/main.gd
scenes/main.tscn
scripts/ci/smoke_test.gd
```

---

## Validação automatizada

O smoke test verifica:

1. importação do presenter de prévia;
2. quatro cosméticos aplicados na prévia;
3. ações de preparação dos dois gamepads;
4. prontidão individual;
5. início somente com os dois jogadores prontos;
6. instanciação do loadout selecionado;
7. entrada ativa;
8. física bloqueada durante a entrada;
9. deslocamento intermediário;
10. encerramento da entrada;
11. física restaurada após `LUTEM`;
12. gamepads separados no combate;
13. preservação de todos os testes anteriores.

---

## Validação manual recomendada

1. editar P1 e confirmar;
2. tentar navegar com P1 pronto;
3. retirar a prontidão de P1;
4. confirmar P1 e P2 por teclado;
5. repetir usando dois gamepads;
6. conferir todos os cosméticos na prévia;
7. observar a entrada dos dois lados;
8. tentar mover e atacar antes de `LUTEM`;
9. confirmar liberação imediata após `LUTEM`;
10. verificar a câmera durante a entrada;
11. conferir o fechamento normal da arena depois da entrada;
12. testar reinício de rodada.

---

## Próxima etapa

- presets nomeáveis e exportáveis;
- seleção de arena;
- regras de partida;
- modos melhor de três e melhor de cinco;
- tela de versus com vantagens e riscos do confronto;
- suporte a reconexão de gamepad;
- remapeamento de controles.

---

**Tehkné Solutions**
