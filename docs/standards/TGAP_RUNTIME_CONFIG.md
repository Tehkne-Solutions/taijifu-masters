# Configuração de runtime TGAP

Cada pack que possui recursos de runtime deve declarar um bloco `runtime` no `manifest.json`.

```json
{
  "runtime": {
    "entity_id": "kaori_nami",
    "frame_prefix": "fighter_kaori_nami",
    "atlas_png": "atlases/kaori_runtime.png",
    "atlas_json": "atlases/kaori_runtime.json",
    "spriteframes": "runtime/kaori_frames.tres",
    "manifest": "runtime/kaori_runtime.json"
  }
}
```

## Campos

- `entity_id`: identificador canônico da entidade no jogo.
- `frame_prefix`: prefixo usado antes de `__<animation>__fNN`.
- `atlas_png`: textura do atlas relativa à raiz do pack.
- `atlas_json`: descrição estrutural do atlas.
- `spriteframes`: recurso `SpriteFrames` do Godot.
- `manifest`: manifesto de runtime com animações e referências.

O gate compara o inventário esperado, o atlas, o `SpriteFrames` e o manifesto sem depender do nome de um personagem específico.

A descoberta legada continua disponível temporariamente para packs antigos, mas produz alerta. Packs novos devem declarar o bloco explicitamente.
