# Importação gráfica do PACK 01

O pacote gráfico oficial foi gerado externamente com 96 assets individuais e deve ser extraído mantendo a estrutura de diretórios.

## Destino obrigatório

```text
assets/packs/pack_01_terrain_core/
├── runtime/hd/
├── runtime/mobile/
├── previews/
├── manifests/
└── docs/
```

Para a cena inicial de validação, os três arquivos abaixo devem existir em:

```text
runtime/mobile/grass/TM_TERRAIN_GRASS_BASE_001.webp
runtime/mobile/grass/TM_TERRAIN_GRASS_BASE_002.webp
runtime/mobile/grass/TM_TERRAIN_GRASS_BASE_003.webp
```

A cena `res://scenes/pack_01_terrain_preview.tscn` monta automaticamente uma grade 5×4 e alterna os três tiles para revelar emendas, bordas, sombras externas ou repetição excessiva.

## Aprovação

O pack só poderá mudar para `IMPLEMENTED` quando:

- os 96 arquivos HD existirem;
- os 96 arquivos mobile existirem;
- o inventário possuir 96 IDs únicos;
- não houver paredes laterais ou bordas externas;
- a cena de conexão carregar sem fallback;
- o teste visual não revelar linhas entre os tiles.

Assinatura: Tehkné Solutions
