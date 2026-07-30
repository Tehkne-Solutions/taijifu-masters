# Taijifu Asset Forge — Fase 2

A Fase 2 adiciona processamento físico de imagens ao Asset Forge. Ela não gera arte e não considera pranchas de apresentação como packs.

## Capacidades

- remoção de fundo por chroma key;
- detecção de conteúdo pelo canal alpha;
- trim transparente;
- normalização de canvas;
- alinhamento por pivot;
- recorte de spritesheets por grade;
- exportação de PNGs individuais;
- composição física de atlas PNG;
- geração de metadados de atlas;
- relatório determinístico da receita executada.

## Comando

```bash
python tools/asset_forge/image_ops.py \
  asset-forge/recipes/pack_01_lian_wu_base.example.json
```

A receita só deve ser executada depois que os arquivos reais de intake estiverem disponíveis em:

```text
asset-forge/intake/pack_01_lian_wu_base/
```

Arquivos esperados pela receita inicial:

```text
char_lian_wu__master_raw.png
turnaround_raw.png
portraits_raw.png
icons_raw.png
```

Esses arquivos são matéria-prima, não assets promovidos. A execução gera os PNGs individuais nos caminhos do contrato oficial.

## Garantias

- nenhuma imagem ausente é substituída por placeholder;
- nenhuma operação cria arte nova;
- grids incompatíveis falham com `grid_not_divisible`;
- conteúdo totalmente transparente falha com `empty_alpha_content`;
- atlas sem fontes falha com `atlas_has_no_sources`;
- o relatório enumera apenas arquivos realmente escritos;
- o bundle estrito do MVP continua sendo a autoridade para release.

## Aplicação ao Pack 01

A receita do Pack 01 processará:

1. master bruto para canvas 1024×1024;
2. turnaround 4×1 para quatro PNGs 512×768;
3. retratos 3×1 para três PNGs 512×512;
4. ícones 2×1 para dois PNGs 256×256;
5. atlas físicos separados de turnaround, retratos e ícones.

Os nomes temporários `turn_01` e `variant_01` precisam passar por mapeamento semântico antes da promoção final. Isso evita atribuir automaticamente uma posição ou expressão incorreta.

## Próxima fase

A Fase 3 deve adicionar:

- mapeamento semântico e renomeação aprovada;
- geração de `SpriteFrames.tres`;
- runtime manifest Godot;
- cena de validação;
- smoke headless;
- captura determinística de preview.
