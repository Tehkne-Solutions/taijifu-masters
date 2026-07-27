# Elenco animado e Inspetor Visual de Assets

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Esta entrega transforma o primeiro pacote de poses estáticas em um pipeline inicial de animação por atlas, adiciona Lyra e Rin como personagens selecionáveis e cria uma ferramenta interna para revisar recursos visuais dentro do próprio jogo.

---

## Elenco inicial

### Kael — Discípulo do Fluxo

Builds:

- Bastão Adaptativo;
- Fluxo Aéreo.

Perfil visual:

- movimentos leves;
- cachecol de fluxo;
- animações Tai e Fu mais rápidas;
- atlas com 5 a 13 FPS conforme o estado.

### Nara — Guardiã da Rocha

Builds:

- Rocha Guardiã;
- Quebra-Fundação.

Perfil visual:

- silhueta pesada;
- manoplas grandes;
- deslocamento mais lento;
- ataques e guarda com leitura de massa.

### Lyra — Tecelã Elemental

Build:

- Tecelã da Corrente.

Perfil de combate:

- Foco elevado;
- controle elemental;
- transições Fu;
- Faixas do Vento como catalisador inicial;
- Bastão como arma secundária.

### Rin — Rival da Chama

Build:

- Chama Rival.

Perfil de combate:

- pressão ofensiva;
- perseguição Tai;
- contato Ji;
- Bastão como arma principal;
- Manoplas Sísmicas como arma secundária.

---

## Formato dos atlases

Cada personagem possui um atlas SVG de 512 × 512 px.

```text
4 colunas × 4 linhas
128 × 128 px por quadro
16 quadros por personagem
```

Linhas:

| Linha | Estado |
|---:|---|
| 0 | idle |
| 1 | movimento e salto |
| 2 | ataque |
| 3 | guarda, dano e controle sofrido |

Arquivos:

```text
assets/characters/kael/kael_animated_sheet.svg
assets/characters/nara/nara_animated_sheet.svg
assets/characters/lyra/lyra_animated_sheet.svg
assets/characters/rin/rin_animated_sheet.svg
```

---

## CharacterVisualCatalog

Arquivo:

```text
scripts/visual/character_visual_catalog.gd
```

O catálogo é a fonte única de:

- nome;
- função;
- caminho do atlas;
- colunas;
- linhas;
- escala;
- FPS por estado;
- ordem dos estados.

Também valida:

- existência do personagem;
- importação do SVG;
- dimensões reais da textura;
- compatibilidade entre grade e estados.

Isso evita configurações diferentes entre gameplay, inspetor e CI.

---

## Animação no lutador

O `ProvisionalSpritePresenter` foi mantido por compatibilidade, mas agora funciona como presenter animado.

Responsabilidades:

- resolver personagem pela build;
- carregar o atlas do catálogo;
- selecionar linha conforme o estado;
- avançar quadro conforme FPS;
- resetar a animação ao trocar de estado;
- espelhar horizontalmente;
- preservar reação de dano;
- reduzir opacidade durante esquiva;
- manter fallback procedural.

FPS são diferentes por personagem. Nara não utiliza a mesma velocidade visual de Rin, e o ataque não utiliza a mesma cadência do idle.

---

## Builds com identidade explícita

`BuildProfile` agora possui:

```text
character_id
character_name
```

A identidade deixou de ser inferida exclusivamente pelo nome da build.

Builds disponíveis:

1. Bastão Adaptativo — Kael;
2. Fluxo Aéreo — Kael;
3. Rocha Guardiã — Nara;
4. Quebra-Fundação — Nara;
5. Tecelã da Corrente — Lyra;
6. Chama Rival — Rin.

O HUD acompanha o personagem escolhido durante preparação e batalha.

---

## Inspetor visual

Arquivo:

```text
scripts/runtime/asset_inspector_runtime.gd
```

Controle principal:

```text
O — abrir ou fechar
```

Com o inspetor aberto:

- `←/→`: personagem;
- `↑/↓`: estado;
- `Espaço`: autoplay;
- `,/.`: quadro manual.

Ao abrir:

1. o estado anterior de pausa é armazenado;
2. a simulação é pausada;
3. o inspetor continua processando por `PROCESS_MODE_ALWAYS`;
4. os controles da luta deixam de interferir;
5. ao fechar, o estado anterior é restaurado.

O painel mostra:

- personagem;
- função;
- integridade do atlas;
- tamanho da grade;
- estado;
- quadro atual;
- FPS;
- modo manual ou autoplay;
- caminho do recurso.

---

## Sincronização do HUD

Arquivo:

```text
scripts/runtime/roster_hud_runtime.gd
```

O runtime corrige os títulos fixos antigos e exibe o nome real do personagem em:

- preparação;
- combate;
- P1;
- P2 local ou bot.

Ele altera apenas a primeira linha dos painéis existentes, preservando os dados já produzidos pelo runtime principal.

---

## Validação automatizada

O smoke test agora:

1. valida os quatro atlases;
2. confirma dimensões 512 × 512;
3. confirma seis builds;
4. verifica `character_id` e `character_name`;
5. instancia cada build;
6. confirma presenter ativo;
7. confirma personagem esperado;
8. instancia a cena principal;
9. confirma Inspetor Visual e Roster HUD;
10. preserva as validações do ImpactDirector e Dojo.

---

## Arquivos centrais

```text
scripts/visual/character_visual_catalog.gd
scripts/visual/provisional_sprite_presenter.gd
scripts/runtime/asset_inspector_runtime.gd
scripts/runtime/roster_hud_runtime.gd
scripts/core/build_profile.gd
scripts/ci/smoke_test.gd
scenes/main.tscn
```

---

## Validação manual

1. Ciclar pelas seis builds na preparação.
2. Confirmar Kael, Nara, Lyra e Rin no HUD.
3. Iniciar uma luta com Lyra e Rin.
4. Confirmar idle, movimento, ataque e guarda.
5. Confirmar diferenças de FPS percebidas.
6. Abrir o inspetor com `O`.
7. Confirmar pausa da luta.
8. Ciclar personagens e estados.
9. Pausar autoplay e percorrer quadros.
10. Fechar o inspetor e confirmar retomada da luta.
11. Confirmar que armas e VFX continuam acima do sprite.
12. Confirmar fallback caso um atlas seja removido em ambiente de desenvolvimento.

---

## Limites atuais

Esta é a primeira passagem animada. Os quadros ainda são provisórios e priorizam:

- pipeline;
- silhueta;
- estado;
- velocidade;
- integração;
- inspeção;
- validação automatizada.

A próxima passagem deverá adicionar:

- animações específicas por técnica;
- sincronização do quadro ativo com startup/active/recovery;
- retratos e expressões ampliadas;
- offset de arma por personagem e quadro;
- hit flashes por região;
- editor de pivôs e pontos de encaixe.

---

**Tehkné Solutions**
