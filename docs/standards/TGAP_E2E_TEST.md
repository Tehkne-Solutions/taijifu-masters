# Teste end-to-end TGAP

O teste `tests/tgap/test_pipeline_e2e.py` constrói, em diretório temporário, um pack canônico mínimo e executa o fluxo completo de validação e distribuição.

## Conteúdo mínimo

O pack de teste possui:

- manifesto TGAP;
- inventário fechado com todos os itens classificados como finais;
- um frame PNG RGBA de 128 × 128 com transparência;
- metadata de animação;
- atlas PNG e JSON;
- recurso `SpriteFrames` Godot;
- manifesto de runtime;
- status de produção.

Os arquivos binários são produzidos durante o teste e não ficam armazenados no repositório.

## Fluxo exercitado

```text
inventory
→ visual_gate
→ animation_gate
→ runtime_gate
→ pipeline aprovado
→ release 1.0.0
→ segunda release 1.0.0
→ comparação SHA-256 dos ZIPs
```

O teste exige que todas as etapas estejam aprovadas, que o relatório consolidado libere a promoção e que duas distribuições do mesmo conteúdo gerem ZIPs idênticos.

## Execução

```bash
pip install -r requirements-tgap.txt -r requirements-tgap-test.txt
pytest -q tests/tgap/test_pipeline_e2e.py
```

A suíte completa continua disponível por:

```bash
pytest -q tests/tgap
```

## Função do pack canônico

O pack mínimo é uma especificação executável do menor conjunto capaz de atravessar todo o TGAP. Mudanças nos validadores, no orquestrador ou no gerador de release que quebrem esse contrato são detectadas automaticamente pelo CI.
