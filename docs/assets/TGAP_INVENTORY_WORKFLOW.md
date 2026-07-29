# TGAP — Inventário físico e qualidade

O inventário TGAP diferencia quatro estados por arquivo:

- `missing`: arquivo esperado ausente;
- `prototype`: arquivo físico de protótipo, keypose, placeholder ou mockup;
- `unverified`: arquivo presente, mas ainda sem aprovação explícita;
- `final`: arquivo declarado final e elegível aos gates de integração.

## Execução

```bash
python scripts/tgap_inventory_report.py assets/tgap/pack_01_lian_wu --write-status
```

## Saídas

```text
assets/tgap/pack_01_lian_wu/validation/inventory-report.json
assets/tgap/pack_01_lian_wu/validation/inventory-report.md
assets/tgap/pack_01_lian_wu/production-status.json
```

## Regra de promoção

A promoção permanece bloqueada quando:

- qualquer arquivo esperado estiver ausente;
- qualquer arquivo estiver classificado como protótipo;
- qualquer arquivo estiver presente, mas não verificado;
- a quantidade de arquivos finais for menor que o inventário fechado.

Ter um arquivo físico não significa que ele está aprovado. O progresso físico e o progresso final são calculados separadamente.
