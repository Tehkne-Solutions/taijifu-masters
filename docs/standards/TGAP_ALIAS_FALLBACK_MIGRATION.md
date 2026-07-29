# TGAP — Aliases, fallback e migração legada

## Objetivo

Permitir a migração progressiva do `AssetPackRegistry` para o catálogo TGAP sem interromper cenas e scripts existentes.

## Resolução

A ordem oficial é:

```text
pack_id canônico instalado
→ alias de pack
→ alias lógico de caminho
→ asset instalado TGAP
→ fallback legado permitido pelo estado
→ falha controlada
```

## Aliases

`assets/tgap/aliases.json` concentra aliases de packs e caminhos lógicos. Aliases marcados como `deprecated` emitem `deprecated_alias_used` para telemetria e remoção futura.

## Fallback

Fallbacks são opt-in e só podem existir nos estados:

- scaffold;
- specified;
- production;
- validation.

São proibidos em `approved`, `integrated` e `released`. Dessa forma, nenhum pack publicado depende silenciosamente de conteúdo legado.

## Compatibilidade

O autoload `AssetPackRegistry` permanece disponível, porém consulta primeiro o `TgapAssetLoader`. Manifestos TGAP são adaptados para o formato legado e recebem `source: tgap`.

Novos consumidores devem usar diretamente:

```gdscript
TgapAssetLoader.load_resource("lian_wu", "spriteframes", "0.1.0")
```

Consumidores antigos continuam podendo usar:

```gdscript
AssetPackRegistry.load_asset("lian_wu", "spriteframes", "0.1.0")
```

## Remoção futura

A retirada de um alias exige:

1. ausência de uso registrada;
2. consumidores migrados para o `pack_id` canônico;
3. pack em estado integrado ou lançado;
4. teste de cenas sem fallback legado.
