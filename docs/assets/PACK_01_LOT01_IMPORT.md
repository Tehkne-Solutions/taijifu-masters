# PACK 01 — Lian Wu — Importação física do Lote 01

Este lote não aceita pranchas, posters, mockups ou composições com texto. As entradas devem ser PNGs de produção com fundo transparente.

## Entradas obrigatórias

Crie uma pasta local, por exemplo `incoming/lian_wu_lot01/`, contendo:

```text
master.png
idle.png
walk.png
run.png
```

### `master.png`

- PNG RGBA;
- fundo transparente;
- personagem completo;
- sem texto, moldura, cenário ou sombra cortada;
- mínimo de 128 × 128 px;
- identidade visual oficial de Lian Wu preservada.

### `idle.png`

- spritesheet horizontal;
- 6 frames;
- cada frame com 128 × 128 px;
- dimensão total: 768 × 128 px;
- fundo transparente.

### `walk.png`

- spritesheet horizontal;
- 8 frames;
- cada frame com 128 × 128 px;
- dimensão total: 1024 × 128 px;
- fundo transparente.

### `run.png`

- spritesheet horizontal;
- 8 frames;
- cada frame com 128 × 128 px;
- dimensão total: 1024 × 128 px;
- fundo transparente.

## Execução

```bash
python -m pip install Pillow
python scripts/import_lian_wu_lot01.py --input incoming/lian_wu_lot01
python scripts/prepare_lian_wu_pack.py
python scripts/validate_game_asset_pack.py assets/pack_01_characters/lian_wu
```

## Saídas geradas

```text
assets/pack_01_characters/lian_wu/
├── source/char_lian_wu__master.png
├── frames/idle/*.png
├── frames/walk/*.png
├── frames/run/*.png
├── metadata/idle.json
├── metadata/walk.json
├── metadata/run.json
├── atlases/char_lian_wu__lot01.png
├── atlases/char_lian_wu__lot01.json
└── production-status.json
```

## Gates do lote

O lote só é aceito quando:

- os 22 frames individuais existem;
- todos os frames possuem transparência real;
- todos têm exatamente 128 × 128 px;
- os nomes correspondem ao contrato;
- os três metadados possuem hashes dos frames;
- o atlas é gerado a partir dos PNGs individuais;
- o `production-status.json` é recalculado pelos arquivos físicos;
- o pack continua com promoção bloqueada enquanto os demais assets estiverem ausentes.

A imagem de referência visual pode ser mantida em `preview/`, mas nunca substitui qualquer arquivo listado em `expected-assets.json`.
