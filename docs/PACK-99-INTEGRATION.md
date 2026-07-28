# PACK 99 — Integração dos PACKS 07–10

## Escopo

Esta integração registra no `AssetPackRegistry`:

- PACK 07 — Heroes & Masters — 48 assets;
- PACK 08 — Units & Champions — 40 assets;
- PACK 09 — Combat VFX & Skills — 58 assets;
- PACK 10 — Interface, HUD & TCG — 60 assets;
- PACK 99 — manifesto consolidado — 206 assets.

## Runtime

A cena `res://scenes/pack_99_integration_preview.tscn` valida os cinco manifestos e tenta carregar uma amostra de cada família visual.

Enquanto os PNGs completos permanecerem no ZIP de produção externo, o preview usa placeholders seguros. A ausência temporária dos binários não impede o carregamento do projeto nem invalida o registro dos packs.

## Publicação dos binários

Os arquivos devem ser copiados para:

```text
assets/packs/pack_07_heroes_masters/runtime/{hd,mobile}
assets/packs/pack_08_units_champions/runtime/{hd,mobile}
assets/packs/pack_09_combat_vfx_skills/runtime/{hd,mobile}
assets/packs/pack_10_ui_hud_tcg/runtime/{hd,mobile}
```

O pacote externo consolidado é `TAIJIFU_MASTERS_PACK_99_CONSOLIDATED.zip`.

## Validação

Execute no Godot 4.3:

```text
godot --headless --path . --script res://scripts/ci/pack_99_integration_smoke_test.gd
```

O gate verifica registro, assinatura, contagens, dependências e o total consolidado de 206 assets.

## Estado

A integração de código, manifestos, dependências, preview e gate está completa. A publicação dos PNGs binários continua separada por causa do fluxo externo de entrega de assets.
