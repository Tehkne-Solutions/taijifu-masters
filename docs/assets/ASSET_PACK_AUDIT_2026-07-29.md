# Auditoria oficial dos packs de assets — 2026-07-29

## Conclusão executiva

A identidade visual aprovada está consolidada, mas a presença de manifestos e runtimes de demonstração não significa que os packs finais estejam produzidos.

O estado real encontrado na `main` é:

- PACK 00 possui especificação, manifesto e cena de validação procedural;
- PACK 01 de Lian Wu havia sido documentado em uma PR cuja base era uma branch já integrada, portanto seus arquivos não chegaram à `main`;
- não existem na `main` frames PNG individuais, atlas, retratos, VFX separados ou SpriteFrames finais de Lian Wu;
- os diretórios `assets/packs/pack_00...pack_10` representam a estrutura legada/prototipal e não comprovam conclusão visual dos novos packs;
- PACK 99 continua sendo referência e fallback, não fonte definitiva para declarar os packs novos como concluídos.

## Definição de status

| Status | Significado |
|---|---|
| `planned` | pack listado, sem especificação consolidada |
| `specified` | direção, IDs e requisitos definidos |
| `generated` | imagens mestre produzidas |
| `sliced` | arquivos individuais recortados, transparentes e nomeados |
| `validated` | dimensões, pivôs, transparência, continuidade e manifesto aprovados |
| `integrated` | assets importados e utilizados no runtime principal |
| `complete` | geração, recorte, validação, integração e documentação concluídos |

## Estado real da nova esteira

| Pack | Escopo atual | Especificado | Assets finais | Recortado | Validado | Integrado | Estado real |
|---|---|---:|---:|---:|---:|---:|---|
| PACK 00 | Visual Foundation | sim | parcial/procedural | não aplicável/parcial | parcial | cena de validação | `specified_validation` |
| PACK 01 | Lian Wu — personagem mestre | sim | não | não | não | não | `specified_assets_missing` |
| PACK 02 | Terreno/Core da nova direção | não consolidado | não | não | não | não | `planned` |
| PACK 03 | Board/Plataformas | não consolidado | não | não | não | não | `planned` |
| PACK 04 | Vegetação | não consolidado | não | não | não | não | `planned` |
| PACK 05 | Props/Estruturas | não consolidado | não | não | não | não | `planned` |
| PACK 06 | Recursos/Pickups | não consolidado | não | não | não | não | `planned` |
| PACK 07 | Unidades/Heróis adicionais | não consolidado | não | não | não | não | `planned` |
| PACK 08 | Campeões/Bosses | não consolidado | não | não | não | não | `planned` |
| PACK 09 | VFX | não consolidado | não | não | não | não | `planned` |
| PACK 10 | UI/System | direção visual aprovada | parcial/procedural | não | parcial | parcial | `prototype_integrated` |
| PACK 11 | Música/Ambiência | não auditado como pack final | — | — | — | — | `planned` |
| PACK 12 | TCG/Cartas | não auditado como pack final | — | — | — | — | `planned` |
| PACK 99 | Master Collection legado | referência/fallback | legado | variável | variável | sim | `legacy_reference` |

## Próximo pack obrigatório

A produção deve retomar no **PACK 01 — Lian Wu**, sem avançar para outro pack enquanto os seguintes gates não forem atendidos:

1. modelo mestre aprovado;
2. direções base consistentes;
3. idle, walk e run gerados em frames individuais;
4. frames transparentes, sem bordas e com nomes padronizados;
5. pivô `feet_center` estável;
6. metadados por animação;
7. atlas PNG + JSON;
8. recurso SpriteFrames do Godot;
9. cena de validação;
10. integração no runtime principal.

## Regra para evitar falso positivo

Um pack não pode ser chamado de "produzido", "implementado" ou "completo" somente por possuir:

- manifesto;
- documentação;
- placeholders;
- formas procedurais;
- uma prancha conceitual;
- um spritesheet não recortado;
- referência dentro do PACK 99.

O status `complete` exige os arquivos finais individuais, validação automatizada e uso real no jogo.
