# PACK 01 — Importação do Lian Wu

Arquivo esperado:

```text
PACK_01_LIAN_WU_BASE_FINAL_v1.0.0.zip
```

O ZIP deve conter, na raiz:

```text
manifest.json
source/char_lian_wu__master_raw.png
source/turnaround_raw.png
source/portraits_raw.png
source/icons_raw.png
```

## Validar e executar o pipeline

```bash
python tools/asset_forge/import_lian_wu_pack.py \
  PACK_01_LIAN_WU_BASE_FINAL_v1.0.0.zip
```

Modo estrito:

```bash
python tools/asset_forge/import_lian_wu_pack.py \
  PACK_01_LIAN_WU_BASE_FINAL_v1.0.0.zip \
  --strict
```

## Garantias

O importador:

1. valida a estrutura do ZIP;
2. confirma `pack_id`;
3. valida SHA-256 das quatro fontes obrigatórias;
4. copia o conteúdo para uma área temporária de intake;
5. executa o release pipeline v3;
6. mantém o bundle bloqueado até os gates e a aprovação assinada.

## Códigos de saída

- `18`: ZIP não encontrado;
- `19`: arquivos obrigatórios ausentes;
- `20`: `pack_id` inválido;
- `21`: checksum ausente ou divergente.

## Estado esperado após a primeira execução

O intake, processamento, orçamento e Production Board podem avançar, mas o release oficial deve continuar bloqueado até a revisão visual e a aprovação assinada serem concluídas.
