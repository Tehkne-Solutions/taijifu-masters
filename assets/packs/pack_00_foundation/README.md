# PACK 00 — Foundation

Base técnica e visual oficial dos assets do Taijifu Masters.

## Regras principais

- Engine: Godot 4.3, renderização GL Compatibility.
- Perspectiva: 2,5D isométrica.
- Terrenos modulares sem bordas laterais, molduras ou sombras externas.
- Tiles planos devem preencher 100% do canvas e conectar nos quatro lados.
- Master: PNG RGBA 1024×1024.
- Runtime HD: WebP 512×512.
- Runtime Mobile: WebP 256×256.
- Padding externo: 0 px.
- Pivô padrão de personagens: (0.5, 0.9).
- Pivô padrão de tiles: (0.5, 0.5).

## Nomenclatura

`TM_<CATEGORIA>_<FAMILIA>_<VARIANTE>_<NNN>.<ext>`

Exemplos:

- `TM_TERRAIN_GRASS_BASE_001.png`
- `TM_TRANSITION_GRASS_DIRT_N_001.png`
- `TM_OVERLAY_GRASS_FLOWERS_001.png`

## Critérios de reprovação

- bloco flutuante;
- paredes laterais;
- bordas elevadas;
- sombra externa;
- moldura ou texto;
- múltiplos tiles presos em uma única imagem de runtime;
- perspectiva incompatível;
- arquivo sem manifesto;
- nome fora do padrão.

## Assinatura

Tehkné Solutions
