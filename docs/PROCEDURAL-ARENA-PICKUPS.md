# Pickups procedurais da arena

## Objetivo

Adicionar disputa territorial e transformação temporária de builds durante a batalha.

## Spawn

- primeiro spawn após aproximadamente 4,5 segundos;
- novos itens entre 6 e 10 segundos;
- no máximo três pickups ativos;
- duração de 16 segundos antes de desaparecer;
- posições distribuídas pela região útil da arena.

## Raridades

- comum — 58%;
- raro — 28%;
- épico — 11%;
- lendário — 3%.

A raridade modifica potência e duração dos efeitos.

## Itens

- Orbe Vital — recupera vida e fôlego;
- Talismã de Foco — aumenta foco temporariamente;
- Guarda de Ferro — aumenta defesa;
- Passo do Vento — aumenta agilidade;
- Força Titânica — aumenta força;
- Pergaminho de Eco — concede uma técnica Fu emprestada.

## Coleta

O pickup é disputado por proximidade. O primeiro lutador a entrar no raio de coleta recebe o efeito.

## Buffs

Os atributos são alterados na instância da build durante o combate e restaurados automaticamente ao final da duração.

## Integração visual

- cores por raridade;
- rótulo do item e raridade;
- animação de flutuação e rotação;
- VFX de spawn e coleta via PACK 09;
- fallback gerado em runtime.

## Validação

```text
godot --headless --path . --script res://scripts/ci/procedural_arena_pickups_smoke_test.gd
```
