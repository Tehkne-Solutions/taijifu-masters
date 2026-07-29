# TGAP — Sunset do AssetPackRegistry

## Estado padrão

O adaptador legado permanece registrado apenas para compatibilidade residual, mas sua leitura de packs antigos fica desativada por padrão.

```text
legacy_adapter_enabled = false
scan_legacy_packs = false
```

As chamadas ainda podem resolver conteúdo TGAP por meio do adaptador, porém cada uso gera telemetria e aviso de depreciação.

## Reativação emergencial

A reativação temporária deve ser explícita:

```text
taijifu/tgap/legacy_adapter_enabled = true
taijifu/tgap/legacy_pack_scan_enabled = true
```

Ela exige motivo documentado e não altera o orçamento de produção, que continua sendo zero.

## Telemetria

O adaptador expõe:

- `legacy_api_used(method_name, pack_id, usage_count)`;
- `legacy_fallback_used(pack_id)`;
- `legacy_disabled(method_name, pack_id)`;
- `usage_snapshot()`;
- `reset_usage_telemetry()`.

## Critério de remoção

O autoload poderá ser removido quando forem obtidas cinco execuções verdes consecutivas com:

- zero referências legadas em produção;
- zero eventos de fallback legado;
- nenhuma reativação temporária em vigor.

## Próxima etapa

Após o período de observação, remover o autoload `AssetPackRegistry` do `project.godot`, manter um shim apenas para migração offline e validar todas as cenas principais com o loader TGAP.
