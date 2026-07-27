# Sprites provisórios, VFX elementais e CI

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Esta entrega substitui a silhueta procedural como apresentação principal do lutador por spritesheets SVG reais, integra os elementos ao diretor unificado de impacto e cria o primeiro gate automático do projeto no Godot 4.3.

---

## Pacote inicial de personagens

### Kael

Arquivo:

```text
assets/characters/kael/kael_provisional_sheet.svg
```

Builds associadas:

- Bastão Adaptativo;
- Fluxo Aéreo.

Identidade:

- corpo leve;
- robe azul;
- cachecol de fluxo;
- poses alongadas;
- expressão mais técnica e móvel.

### Nara

Arquivo:

```text
assets/characters/nara/nara_provisional_sheet.svg
```

Builds associadas:

- Rocha Guardiã;
- Quebra-Fundação.

Identidade:

- silhueta compacta e pesada;
- armadura terrosa;
- grandes manoplas;
- base corporal baixa;
- expressão de resistência e pressão.

## Organização dos spritesheets

Cada arquivo possui 512 × 128 px e quatro quadros de 128 × 128 px:

| Índice | Estado | Uso |
|---:|---|---|
| 0 | idle | repouso e leitura neutra |
| 1 | move | corrida, salto e queda |
| 2 | attack | startup, atividade e recuperação |
| 3 | guard | defesa, agarrão sofrido e dano recente |

O `ProvisionalSpritePresenter` utiliza `AtlasTexture` para selecionar o quadro sem duplicar texturas.

## Regras de runtime

- A build determina o personagem visual.
- A direção usa `flip_h` e não exige duplicação dos assets.
- Dano recente mantém a pose de reação por uma janela curta.
- Esquiva reduz a opacidade.
- Agarrão escurece temporariamente o personagem.
- Troca e perda de arma não substituem o corpo do personagem; armas continuam no overlay modular.

## Fallback

Quando o spritesheet não existe ou não pode ser importado:

1. o presenter é desativado;
2. um aviso é registrado;
3. o controlador volta a desenhar a silhueta procedural anterior;
4. hitboxes, hurtboxes e gameplay continuam inalterados.

Quando o spritesheet está ativo, o controlador desenha somente as barras de vida, postura e desarmamento. Isso evita duplicar a silhueta antiga atrás do asset.

---

## Diretor de impacto elemental

O `ImpactDirector` continua sendo a fonte única de apresentação para impactos físicos e agora também recebe:

- `elemental_state_changed`;
- `elemental_interaction`.

### Fogo

- cor laranja/vermelha;
- formas pontiagudas;
- onomatopeia `FWOOM!`;
- estado `BURN!`;
- combustão `BOOM!`.

### Água

- círculos e ondas;
- gotas projetadas;
- onomatopeia `SPLASH!`;
- estado `SOAK!`;
- extinção `TSH!`.

### Terra

- fragmentos angulares;
- leitura de massa;
- onomatopeia `KROOM!`;
- estado `ANCHOR!`;
- lama `SQUELCH!`.

### Ar

- arcos e linhas direcionais;
- leitura de deslocamento;
- onomatopeia `VWOOSH!`;
- estado `UNSTEADY!`;
- resistência de alvo ancorado `BRACE!`.

### Combinações

As interações existentes recebem feedback próprio:

- fogo + água → vapor;
- fogo + ar → combustão;
- água + terra → lama;
- ar contra terra/lama → resistência.

Os efeitos não alteram o resultado mecânico. Eles apenas representam estados e interações já calculados pelo controlador elemental.

---

## CI do Godot

Workflow:

```text
.github/workflows/godot-ci.yml
```

O workflow roda em:

- pull requests;
- pushes para `main`.

### Etapas

1. checkout;
2. instalação das bibliotecas mínimas do runtime;
3. download do Godot 4.3 stable;
4. importação headless do projeto;
5. validação de parser;
6. execução do smoke test;
7. publicação dos logs quando houver falha.

### Smoke test

Arquivo:

```text
scripts/ci/smoke_test.gd
```

Valida:

- cena principal;
- cena do lutador;
- spritesheets de Kael e Nara;
- presenter;
- overlay;
- diretor de impacto;
- controlador final;
- instanciação da cena principal;
- presença do `ImpactDirector`;
- presença do `DojoTrainingRuntime`.

O teste retorna código diferente de zero quando algum requisito não é atendido.

---

## Arquivos centrais

```text
assets/characters/kael/kael_provisional_sheet.svg
assets/characters/nara/nara_provisional_sheet.svg
scripts/visual/provisional_sprite_presenter.gd
scripts/visual/fighter_visual_overlay.gd
scripts/fighter/mastered_weapon_fighter_controller.gd
scripts/runtime/impact_director.gd
scripts/ci/smoke_test.gd
.github/workflows/godot-ci.yml
scenes/fighter/fighter.tscn
```

---

## Validação manual obrigatória

1. Kael aparece nas builds Bastão Adaptativo e Fluxo Aéreo.
2. Nara aparece nas builds Rocha Guardiã e Quebra-Fundação.
3. Idle, movimento, ataque e guarda alternam corretamente.
4. O sprite acompanha a direção do lutador.
5. O desenho procedural não fica visível atrás do sprite.
6. Armas e feedback Tai/Ji/Fu permanecem sobre o personagem.
7. Desarmamento não remove a identidade corporal.
8. Fogo, água, terra e ar produzem efeitos diferentes.
9. Vapor, combustão, lama, extinção e resistência aparecem uma vez por interação.
10. Hitstop e câmera retornam ao estado normal.
11. O workflow executa importação e smoke test.
12. Logs são anexados quando o CI falha.

---

## Limites desta entrega

Os sprites são provisórios e validam:

- proporção;
- silhueta;
- troca de estado;
- pipeline de asset;
- compatibilidade com armas e VFX.

Ainda não representam:

- animações quadro a quadro finais;
- sprites completos de todas as armas;
- skins;
- retratos finais;
- sprites de Rin ou Lyra;
- direção de arte definitiva.

A próxima etapa deverá evoluir os spritesheets para animações por frame e adicionar um inspetor visual de assets/personagens dentro do projeto.

---

**Tehkné Solutions**
