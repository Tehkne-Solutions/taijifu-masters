# TGAP Pack Promotion Readiness

Este gate transforma o inventário fechado de cada pack em uma lista objetiva de bloqueios antes da promoção.

## Pack 01

O Pack 01 — Lian Wu possui inventário fechado de 163 arquivos:

- 1 fonte mestre;
- 113 frames de animação;
- 3 retratos;
- 2 ícones;
- 18 frames de VFX;
- 2 arquivos de atlas;
- 19 metadados de animação;
- 2 recursos de runtime;
- 2 arquivos de validação;
- 1 preview.

A enumeração é derivada de `expected-assets.json`. O auditor não altera o manifesto e não promove o pack automaticamente.

## Gates obrigatórios

- `all_expected_assets_present`
- `all_sha256_valid`
- `image_gate_passed`
- `animation_gate_passed`
- `runtime_gate_passed`
- `approval_signed`

Os dois primeiros gates são recalculados a partir dos arquivos reais. Evidências declaradas não podem substituir arquivos ausentes, vazios ou hashes inexistentes.

## Evidência

Os gates externos podem ser registrados em `promotion-evidence.json` dentro do pack:

```json
{
  "schema": "tgap/promotion-evidence/v1",
  "pack_id": "pack_01_lian_wu",
  "gates": {
    "image_gate_passed": false,
    "animation_gate_passed": false,
    "runtime_gate_passed": false,
    "approval_signed": false
  }
}
```

A ausência desse arquivo mantém os gates externos como falsos.

## Execução

```bash
python scripts/tgap_pack_promotion_readiness.py --pack pack_01_lian_wu
```

Modo bloqueante:

```bash
python scripts/tgap_pack_promotion_readiness.py --pack pack_01_lian_wu --strict
```

O relatório é escrito em:

```text
artifacts/tgap/promotion-readiness.json
```

A promoção só pode alterar `promotion.blocked` quando todos os seis gates estiverem verdes e o estado atual permitir a transição.
