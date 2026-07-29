# Schemas JSON TGAP

O TGAP valida contratos estruturais antes dos gates de inventário, visual, animação e runtime.

## Schemas

- `schemas/tgap/manifest.schema.json`
- `schemas/tgap/expected-assets.schema.json`
- `schemas/tgap/runtime-manifest.schema.json`
- `schemas/tgap/pipeline-report.schema.json`

Todos usam JSON Schema Draft 2020-12.

## Gate de contrato

```bash
python scripts/tgap_contract_gate.py assets/tgap/pack_01_lian_wu
```

Para validar também um relatório de pipeline já produzido:

```bash
python scripts/tgap_contract_gate.py assets/tgap/pack_01_lian_wu --include-pipeline-report
```

O relatório é gravado em:

```text
validation/contract-gate-report.json
```

## Bloqueios

O gate bloqueia promoção quando identifica, entre outros casos:

- `pack_id` fora da convenção canônica;
- versão fora de SemVer;
- classe de asset desconhecida;
- estado de lifecycle inválido;
- configuração de runtime incompleta;
- inventário sem assets, grupos ou animações;
- contagens de frames inválidas;
- relatório de pipeline contraditório.

## Ordem recomendada

```text
contract_gate
→ inventory
→ visual_gate
→ animation_gate
→ runtime_gate
→ pipeline_report
→ contract_gate --include-pipeline-report
→ release
```

## Testes

```bash
pytest -q tests/tgap/test_contract_gate.py
```
