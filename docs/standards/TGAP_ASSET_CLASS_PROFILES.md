# Perfis TGAP por classe de asset

O TGAP usa `asset_class` no `manifest.json` para decidir quais gates são obrigatórios e quais convenções devem ser aplicadas.

Classes iniciais:

- `character` e `unit`: animações a 12 FPS por padrão;
- `vfx`: animações a 18 FPS por padrão;
- `tile`, `prop`, `environment` e `ui`: estáticos por padrão, portanto o gate de animação é registrado como ignorado sem bloquear promoção.

Um pack pode sobrescrever o perfil:

```json
{
  "asset_class": "vfx",
  "validation_profile": {
    "animated": true,
    "frames_root": "vfx_frames",
    "metadata_root": "vfx_metadata",
    "frame_prefix": "fx_water_dragon",
    "frame_digits": 3,
    "default_fps": 24
  }
}
```

## Inventário por grupos

Além de `assets`, `expected-assets.json` aceita grupos declarativos:

```json
{
  "groups": [
    {
      "id": "terrain_tiles",
      "glob": "tiles/terrain/*.png",
      "required": 24,
      "quality": "final"
    }
  ]
}
```

O inventário bloqueia a promoção quando o total encontrado é menor que `required`, ou quando algum arquivo não está classificado como final.

Esse contrato permite validar packs de personagens, tiles, props, cenários, VFX e interface sem codificar nomes específicos nos validadores.
