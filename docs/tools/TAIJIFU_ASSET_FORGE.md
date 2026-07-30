# Taijifu Asset Forge

O Taijifu Asset Forge é a ferramenta oficial de produção e empacotamento dos assets TGAP. O MVP não gera arte por conta própria e não cria placeholders. Ele organiza e valida arquivos físicos fornecidos, produz evidências e bloqueia bundles de release incompletos.

## Objetivos do MVP

- definir packs por contrato JSON versionado;
- criar a estrutura física de diretórios;
- enumerar um inventário fechado;
- validar PNG, dimensões, transparência e SHA-256;
- gerar metadados determinísticos de atlas;
- gerar preview HTML de diagnóstico;
- produzir ZIP auditável;
- impedir ZIP estrito enquanto houver arquivos ausentes ou inválidos;
- integrar o processo ao TGAP e ao GitHub Actions.

## Comandos

```bash
python tools/asset_forge/forge.py init asset-forge/packs/pack_01_lian_wu_base.json
python tools/asset_forge/forge.py validate asset-forge/packs/pack_01_lian_wu_base.json
python tools/asset_forge/forge.py atlas asset-forge/packs/pack_01_lian_wu_base.json
python tools/asset_forge/forge.py preview asset-forge/packs/pack_01_lian_wu_base.json
python tools/asset_forge/forge.py bundle asset-forge/packs/pack_01_lian_wu_base.json
```

Bundle de release:

```bash
python tools/asset_forge/forge.py bundle asset-forge/packs/pack_01_lian_wu_base.json --strict
```

O modo sem `--strict` cria um ZIP de diagnóstico contendo manifesto, relatórios e quaisquer arquivos existentes. Ele nunca significa que o pack está aprovado. O modo estrito só gera uma entrega válida quando o inventário estiver completo.

## Aplicação inicial: Pack 01 — Lian Wu Base

O contrato inicial possui 15 itens:

1. master transparente;
2. turnaround frontal;
3. turnaround traseiro;
4. perfil esquerdo;
5. perfil direito;
6. retrato de perfil;
7. retrato de batalha;
8. retrato derrotado;
9. ícone do personagem;
10. ícone do elemento água;
11. paleta oficial;
12. identidade visual;
13. preview 1280×720;
14. manifesto de runtime;
15. relatório de validação.

Enquanto os PNGs definitivos não existirem, o resultado esperado é `ready: false`. Isso é comportamento correto.

## Próximas fases

### Fase 2 — Processamento de imagens

- composição física do atlas PNG com Pillow;
- recorte por grade e por detecção de células;
- remoção de fundo por chroma key;
- normalização de canvas e pivot;
- detecção de bordas e conteúdo cortado;
- comparação perceptual entre frames.

### Fase 3 — Godot

- geração de `SpriteFrames.tres`;
- cena de validação automática;
- importação e smoke headless;
- integração com `TgapAssetLoader`;
- captura determinística de preview.

### Fase 4 — Orquestração visual

- fila de solicitações para geração externa de arte;
- registro do prompt e da referência usados;
- intake dos resultados;
- revisão humana obrigatória;
- promoção e abertura de PR.

## Regra operacional

Uma prancha conceitual nunca é um pack. Uma imagem que afirma mostrar um ZIP também não é evidência de ZIP. Apenas arquivos físicos verificados pelo Asset Forge podem alterar a prontidão do pack.
