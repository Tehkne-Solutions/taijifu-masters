# TGAP Orchestrator

O orquestrador executa o pipeline técnico completo de um pack e produz um único resultado de promoção.

## Comando padrão

```bash
python scripts/tgap_run_pack.py assets/tgap/pack_01_lian_wu
```

## Com migração prévia

```bash
python scripts/tgap_run_pack.py assets/tgap/pack_01_lian_wu --migrate
```

## Ordem das etapas

1. migração opcional;
2. inventário físico e classificação;
3. gate visual;
4. gate de animação;
5. relatório consolidado.

## Saídas

- `validation/pipeline-report.json`
- `validation/pipeline-report.md`

O relatório registra comando, código de saída, duração, stdout, stderr e resultado de cada etapa.

## Regra de promoção

`pipeline_passed` só será verdadeiro quando todas as etapas obrigatórias retornarem sucesso. Qualquer falha define `promotion_blocked=true`.

O orquestrador não transforma protótipos em assets finais e não ignora gates ausentes ou quebrados.
