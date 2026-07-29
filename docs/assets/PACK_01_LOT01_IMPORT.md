# PACK 01 — Lian Wu — Importação física do Lote 01

O Lote 01 aceita somente arquivos de produção. Pranchas, posters, mockups e imagens com texto não contam como assets finais.

## Entradas obrigatórias

Crie uma pasta local contendo:

```text
master.png
idle.png
walk.png
run.png
```

Requisitos:

- `master.png`: PNG RGBA transparente, personagem completo, mínimo 128 × 128 px;
- `idle.png`: 6 frames horizontais de 128 × 128 px; total 768 × 128 px;
- `walk.png`: 8 frames horizontais de 128 × 128 px; total 1024 × 128 px;
- `run.png`: 8 frames horizontais de 128 × 128 px; total 1024 × 128 px;
- nenhum arquivo pode conter cenário, moldura, legenda ou fundo opaco.

## Execução

```bash
python -m pip install Pillow
python scripts/import_lian_wu_lot01.py --input incoming/lian_wu_lot01
python scripts/prepare_lian_wu_pack.py
python scripts/validate_game_asset_pack.py assets/pack_01_characters/lian_wu
```

## Saídas

O importador gera:

```text
source/char_lian_wu__master.png
frames/idle/*.png
frames/walk/*.png
frames/run/*.png
metadata/idle.json
metadata/walk.json
metadata/run.json
atlases/char_lian_wu__lot01.png
atlases/char_lian_wu__lot01.json
production-status.json
```

## Validação obrigatória

O lote é rejeitado quando:

- uma spritesheet possui dimensão incorreta;
- algum frame não tem transparência real;
- existe frame totalmente transparente;
- o arquivo não é PNG;
- a quantidade de frames não corresponde ao contrato;
- os hashes não podem ser calculados;
- algum caminho esperado permanece ausente.

Mesmo após o Lote 01 ser aceito, `promotion_blocked` permanece ativo até todos os 163 arquivos do PACK 01 estarem presentes, aprovados e integrados ao runtime.
