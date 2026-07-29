# Orquestração obrigatória de contratos TGAP

O `contract_gate` é a primeira etapa obrigatória de qualquer validação TGAP.

## Ordem oficial

```text
migration opcional
→ contract_gate
→ inventory
→ visual_gate
→ animation_gate
→ runtime_gate
→ pipeline-report.json
→ pipeline_contract_gate
→ release
```

## Fail-fast

Quando `manifest.json`, `expected-assets.json` ou o manifesto de runtime não atendem aos schemas:

- o pipeline é bloqueado imediatamente;
- inventário, visual, animação e runtime não são executados;
- as etapas técnicas aparecem como `skipped` no relatório;
- `skip_reason` recebe `contract_gate_failed`;
- `pipeline_passed` permanece `false`;
- nenhuma release oficial pode ser criada.

## Validação final

Depois dos gates técnicos, o orquestrador escreve um relatório consolidado provisório e executa novamente o contract gate com:

```bash
python scripts/tgap_contract_gate.py <pack> --include-pipeline-report
```

A etapa `pipeline_contract_gate` confirma que o próprio `pipeline-report.json` atende ao schema e não contém estados contraditórios.

## GitHub Actions

O workflow `.github/workflows/tgap.yml` possui três barreiras:

1. validação explícita dos contratos antes do orquestrador;
2. validação incorporada ao próprio `tgap_run_pack.py`;
3. revalidação explícita do relatório consolidado.

Alterações em `schemas/tgap/**` e `requirements-tgap.txt` também disparam o workflow.

## Relatórios

Os artifacts de CI preservam, inclusive em falhas:

- `contract-gate-report.json`;
- `pipeline-report.json`;
- `pipeline-report.md`;
- relatórios técnicos produzidos antes de uma eventual falha.
