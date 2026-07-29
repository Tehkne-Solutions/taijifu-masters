# TGAP Runtime Asset Loader

O `TgapAssetLoader` conecta o catálogo instalado pelo instalador transacional ao runtime Godot.

## Fonte de verdade

```text
user://tgap/tgap-catalog.json
user://tgap/tgap-current/packs/<pack_id>/...
```

O loader aceita somente `tgap/install-catalog/v1` e usa `generation` para controlar atualização e invalidação de cache.

## Resolução

```gdscript
var texture_path := TgapAssetLoader.resolve(
    "pack_01_lian_wu",
    "frames/idle/char_lian_wu__idle__f00.png",
    "0.1.0"
)
```

O terceiro argumento é opcional. Quando informado, impede que um consumidor carregue silenciosamente uma versão diferente da esperada.

Para recursos reconhecidos pelo Godot:

```gdscript
var frames := TgapAssetLoader.load_resource(
    "pack_01_lian_wu",
    "runtime/lian_wu_spriteframes.tres"
)
```

## Cache

A chave de cache inclui:

```text
<pack_id>@<version>:<relative_path>
```

Quando a geração do catálogo aumenta, o loader compara as versões antigas e novas e invalida apenas os packs alterados ou removidos.

## Hot reload

O hot reload fica desabilitado por padrão. Para ambientes de desenvolvimento:

```gdscript
TgapAssetLoader.hot_reload_enabled = true
TgapAssetLoader.poll_interval_seconds = 1.0
TgapAssetLoader.set_process(true)
```

A atualização só é aceita quando:

- o arquivo mudou;
- o JSON é válido;
- o schema corresponde;
- a nova geração é maior que a geração ativa.

## Sinais

- `catalog_reloaded(previous_generation, current_generation)`;
- `pack_invalidated(pack_id, version)`;
- `asset_resolved(pack_id, relative_path, absolute_path)`;
- `reload_rejected(reason)`.

## Segurança

A resolução rejeita caminhos absolutos, segmentos vazios, barras invertidas ambíguas e travessia por `..`. O loader nunca procura arquivos fora de `tgap-current/packs/<pack_id>`.

## Integração

O loader é registrado em `project.godot` como autoload `TgapAssetLoader`, ficando disponível para cenas e sistemas de runtime sem dependência direta do instalador ou dos scripts Python.
