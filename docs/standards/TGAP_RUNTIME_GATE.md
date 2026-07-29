# TGAP Runtime Gate

O gate de runtime impede que um pack seja integrado quando seus arquivos técnicos não correspondem ao inventário físico aprovado.

## Validações obrigatórias

- presença do atlas PNG;
- presença e leitura do atlas JSON;
- presença do recurso `SpriteFrames` do Godot;
- presença e leitura do manifesto de runtime;
- correspondência entre os 113 frames esperados e os frames do atlas;
- correspondência entre os frames esperados e o recurso `SpriteFrames`;
- detecção de frames extras;
- detecção de referências `res://` quebradas;
- confirmação de que o `.tres` declara `SpriteFrames`;
- campos obrigatórios do manifesto;
- contagem de frames por animação compatível com `expected-assets.json`.

## Execução

```bash
python scripts/tgap_runtime_gate.py assets/tgap/pack_01_lian_wu
```

## Saídas

- `validation/runtime-gate-report.json`
- `validation/runtime-gate-report.md`

## Política

O gate retorna código `1` e mantém `promotion_blocked: true` quando qualquer requisito obrigatório falhar. Frames extras são registrados como alerta, mas devem ser revisados antes da publicação do pack.

O gate valida estrutura e referências. A execução real do recurso dentro do Godot continua sendo exigida no gate de integração.
