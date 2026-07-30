# Taijifu Asset Forge — Fase 4

A Fase 4 adiciona um comando único para executar a esteira completa de um pack.

## Fluxo

```text
init
→ image processing
→ validation
→ Godot runtime
→ bundle
```

O orquestrador preserva o estado real. Quando as imagens de intake não existem, a etapa `images` fica `blocked`; as demais etapas ainda produzem diagnósticos quando possível. Nenhum placeholder é criado.

## Pack 01

```bash
python tools/asset_forge/orchestrator.py \
  asset-forge/orchestration/pack_01_lian_wu_base.json
```

Modo de release:

```bash
python tools/asset_forge/orchestrator.py \
  asset-forge/orchestration/pack_01_lian_wu_base.json \
  --strict
```

O modo estrito retorna código 5 enquanto qualquer etapa estiver bloqueada ou falhar.

## Intake obrigatório

```text
asset-forge/intake/pack_01_lian_wu_base/char_lian_wu__master_raw.png
asset-forge/intake/pack_01_lian_wu_base/turnaround_raw.png
asset-forge/intake/pack_01_lian_wu_base/portraits_raw.png
asset-forge/intake/pack_01_lian_wu_base/icons_raw.png
```

## Relatório

```text
artifacts/asset-forge/pack_01_lian_wu_base__orchestration.json
```

Schema:

```text
taijifu/asset-forge-orchestration/v1
```

A próxima evolução deve adicionar intake por diretório/ZIP, validação dos nomes das células e geração do pacote de revisão humana antes da promoção.
