# Contratos semânticos TGAP

O `tgap_semantic_gate.py` valida relações entre documentos que não podem ser garantidas por JSON Schema isoladamente.

## Ordem

```text
contract_gate
→ semantic_gate
→ inventory
→ visual_gate
→ animation_gate
→ runtime_gate
→ pipeline_contract_gate
→ pipeline_semantic_gate
→ release
```

## Regras verificadas

- `pack_id` idêntico entre manifesto, inventário, status e runtime;
- estado coerente entre `manifest.json` e `production-status.json`;
- raiz declarada compatível com a localização física;
- classes animadas possuem animações declaradas;
- arquivos de runtime fazem parte do inventário fechado;
- `entity_id` é coerente entre configuração e manifesto de runtime;
- nomes e contagens de animações coincidem entre inventário e runtime;
- estados `approved`, `integrated` e `released` exigem inventário fechado;
- assets de estados avançados precisam estar classificados como finais;
- relatório final contém todas as etapas obrigatórias;
- `pipeline_passed=true` só é aceito sem etapas falhas ou promoção bloqueada.

## Execução

```bash
python scripts/tgap_semantic_gate.py assets/tgap/pack_01_lian_wu
```

Validação final:

```bash
python scripts/tgap_semantic_gate.py \
  assets/tgap/pack_01_lian_wu \
  --include-pipeline-report
```

## Saída

```text
validation/semantic-gate-report.json
```

Uma falha semântica interrompe o pipeline antes dos gates técnicos e registra `semantic_gate_failed` nas etapas ignoradas.
