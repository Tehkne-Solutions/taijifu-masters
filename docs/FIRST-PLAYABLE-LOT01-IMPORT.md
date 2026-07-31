# Taijifu Masters — Importação do First Playable Lot 01

## Objetivo

Importar somente um lote aprovado de Lian Wu e gerar o recurso `SpriteFrames` consumido pelo First Playable.

## Entrada

```text
PACK_01_LIAN_WU_FIRST_PLAYABLE_LOT_01_v1.0.0.zip
```

O pacote precisa conter:

- `manifest.json` com `lot_id` canônico;
- `runtime-map.json` com as dez animações obrigatórias;
- `approval.json` com `status: approved`;
- `checksums.sha256` válido;
- frames PNG separados por animação.

## Execução

```bash
python tools/asset_forge/import_first_playable_lot01.py caminho/para/PACK_01_LIAN_WU_FIRST_PLAYABLE_LOT_01_v1.0.0.zip
```

## Saída

```text
assets/tgap/pack_01_lian_wu/first_playable_lot_01/
├── manifest.json
├── runtime-map.json
├── approval.json
├── checksums.sha256
├── lian_wu_first_playable_frames.tres
└── animations/
```

O importador:

1. bloqueia ZIP Slip;
2. exige um único manifesto;
3. valida todos os checksums;
4. bloqueia lotes não aprovados;
5. exige as dez animações do contrato;
6. exige ao menos um PNG por animação;
7. substitui atomicamente o diretório de destino;
8. gera o `SpriteFrames` canônico para o presenter.

## Validação

```bash
pytest -q tests/test_first_playable_lot01_importer.py

godot --headless --path . --script tests/first_playable_lot01_presenter_contract.gd
```

## Estado atual

O importador está pronto, mas não há lote artístico aprovado para executar a importação real. Nenhum placeholder é tratado como asset final.

Assinatura: Tehkné Solutions
