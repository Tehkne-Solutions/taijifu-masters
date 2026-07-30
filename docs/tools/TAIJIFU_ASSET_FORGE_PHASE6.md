# Taijifu Asset Forge — Fase 6

A Fase 6 integra o intake ao fluxo de release e exige uma aprovação humana verificável antes do bundle estrito.

## Fluxo

```text
ZIP/diretório
→ intake seguro
→ processamento
→ validação
→ integração Godot
→ aprovação humana
→ bundle estrito
```

## Criar uma aprovação

```bash
python tools/asset_forge/approval_gate.py create \
  artifacts/asset-forge/review/pack_01_lian_wu_base/approval.json \
  --pack pack_01_lian_wu_base \
  --reviewer "NOME DO REVISOR" \
  --approve-all
```

A opção `--approve-all` deve ser usada apenas após revisão visual real. O documento registra revisor, horário UTC, checklist e assinatura SHA-256 do conteúdo canônico.

## Verificar uma aprovação

```bash
python tools/asset_forge/approval_gate.py verify \
  artifacts/asset-forge/review/pack_01_lian_wu_base/approval.json \
  --pack pack_01_lian_wu_base \
  --strict
```

Alterações posteriores no documento invalidam a assinatura.

## Executar a esteira completa

```bash
python tools/asset_forge/release_pipeline.py \
  asset-forge/release/pack_01_lian_wu_base.json \
  --source caminho/para/pack-01.zip \
  --approval artifacts/asset-forge/review/pack_01_lian_wu_base/approval.json \
  --strict
```

Sem intake completo, validação técnica ou aprovação válida, a execução estrita encerra com código 7 e não produz bundle oficial.

## Regra

A aprovação humana não substitui os gates técnicos. Ela é um gate adicional e só libera o bundle quando todos os gates anteriores também estiverem aprovados.
