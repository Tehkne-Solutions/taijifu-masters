# TGAP — Auditoria de uso legado

A auditoria identifica consumidores que ainda dependem do `AssetPackRegistry`, de `res://assets/packs/`, de `pack.json` ou de caminhos diretos dentro de packs TGAP.

## Executar

```bash
python scripts/tgap_audit_legacy_usage.py
```

Relatório:

```text
artifacts/tgap/legacy-usage-report.json
```

## Migração segura

```bash
python scripts/tgap_audit_legacy_usage.py --migrate-safe
```

A migração automática é limitada a chamadas com equivalência direta:

```text
AssetPackRegistry.load_asset  → TgapAssetLoader.load_resource
AssetPackRegistry.resolve_asset → TgapAssetLoader.resolve
```

O adaptador `scripts/runtime/asset_pack_registry.gd` nunca é alterado automaticamente.

## Gate estrito

```bash
python scripts/tgap_audit_legacy_usage.py --fail-on-findings
```

Use o modo estrito apenas depois da migração progressiva. Enquanto houver consumidores antigos autorizados, a CI publica o relatório sem bloquear o PR.

## Classificações

- `legacy_registry`: referência ao autoload legado;
- `legacy_pack_root`: acesso direto ao diretório histórico;
- `legacy_pack_json`: dependência de manifesto antigo;
- `direct_tgap_path`: consumidor acoplado à estrutura física do pack.

A meta final é zerar todas as categorias fora do adaptador de compatibilidade.