# TGAP — Migração de legado, lote 01

## Objetivo

Separar referências operacionais do jogo de referências mantidas apenas em documentação, testes e no adaptador de compatibilidade.

## Resultado da triagem

A busca remota do repositório não retornou consumidores diretos indexados de `AssetPackRegistry` nem de `res://assets/packs/` fora da infraestrutura TGAP. Como a busca do GitHub não substitui uma varredura completa do checkout, o resultado definitivo passa a ser produzido pelo workflow `TGAP Legacy Production Gate`.

## Escopos

- `production`: scripts, cenas e recursos executados pelo jogo;
- `allowed_infrastructure`: adaptador legado, auditor, testes, documentação e workflows;
- `non_production`: demais arquivos textuais sem participação direta no runtime.

Somente ocorrências em `production` bloqueiam a integração.

## Política

A configuração está em `config/tgap-legacy-audit-policy.json`. O adaptador `scripts/runtime/asset_pack_registry.gd` permanece permitido temporariamente como fronteira de compatibilidade.

## Gate

```bash
python scripts/tgap_audit_legacy_usage.py --fail-on-findings
```

O comando gera `artifacts/tgap/legacy-usage-report.json` no schema `tgap/legacy-audit/v2` e falha apenas quando encontra consumidores de produção.

## Migração automática segura

```bash
python scripts/tgap_audit_legacy_usage.py --migrate-safe
```

A reescrita é limitada a scripts classificados como produção e às equivalências diretas:

```text
AssetPackRegistry.load_asset   -> TgapAssetLoader.load_resource
AssetPackRegistry.resolve_asset -> TgapAssetLoader.resolve
```

## Estado do lote

O lote 01 estabelece baseline estrito e impede a introdução de novas dependências legadas. Casos futuros detectados pelo relatório serão migrados em lotes pequenos, com validação de cena e recurso antes da remoção definitiva do adaptador.
