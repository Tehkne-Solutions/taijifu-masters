# TGAP Runtime Exclusive

## Objetivo

Operar o jogo com `TgapAssetLoader` como único autoload de assets.

## Estado aplicado

- `AssetPackRegistry` removido de `[autoload]` em `project.godot`;
- `TgapAssetLoader` permanece como entrada global oficial;
- o adaptador legado continua no repositório apenas para importação manual emergencial e testes de transição;
- orçamento de referências legadas em produção permanece igual a zero.

## Garantias

1. Cenas e scripts de produção não podem depender do singleton `AssetPackRegistry`.
2. Assets instalados são resolvidos pelo catálogo TGAP.
3. Aliases e fallback controlado continuam concentrados em `TgapAssetLoader`.
4. A auditoria estrita bloqueia novas referências legadas.
5. A retirada física do arquivo adaptador pode ocorrer após a janela de estabilidade definida pela política de sunset.

## Validação

```bash
python -m pytest tests/tgap/test_legacy_autoload_removed.py
python scripts/tgap_audit_legacy_usage.py --fail-on-findings
```

## Rollback emergencial

O rollback exige reintrodução explícita do autoload em uma PR dedicada. Não existe reativação silenciosa em runtime.
