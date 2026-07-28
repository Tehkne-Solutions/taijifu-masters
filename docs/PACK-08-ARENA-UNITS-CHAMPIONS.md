# PACK 08 — Unidades e campeões na arena

## Objetivo

O `Pack08ArenaUnitRuntime` adiciona unidades auxiliares, inimigos neutros e um campeão à batalha sem substituir os dois lutadores principais.

## Fluxo do encontro

- 3,5 s: surgem duas unidades de apoio para cada jogador;
- 12 s: uma onda neutra com Wraith e Golem entra no centro;
- 27 s: o Champion Dragon entra como evento de pressão.

## Arquétipos

- Soldier;
- Archer;
- Guardian;
- Wraith;
- Golem;
- Champion Dragon.

Cada arquétipo possui vida, velocidade, alcance, dano e dano de postura próprios.

## IA

As unidades:

- procuram o alvo hostil mais próximo;
- avançam horizontalmente;
- respeitam alcance próprio;
- atacam com cadência controlada;
- podem atingir lutadores ou outras unidades;
- podem ser atingidas durante a fase ativa de técnicas dos lutadores.

## Loot e recompensa

Ao derrotar uma unidade, o jogador responsável recupera vida e fôlego. Campeões concedem bônus maior e feedback visual de loot de técnica.

## Assets

O runtime usa os PNGs do PACK 08 quando presentes e mantém fallback visual gerado em runtime quando os binários externos ainda não foram copiados para o repositório.

## Compatibilidade

A implementação é um autoload isolado. Não modifica cenas, colisões, controles, IA dos lutadores ou regras competitivas existentes.

## Validação

```text
godot --headless --path . --script res://scripts/ci/pack_08_arena_units_smoke_test.gd
```
