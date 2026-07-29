# Tehkné Game Asset Pack Standard

## Objetivo

Transformar cada pack de assets em uma unidade de produção completa, verificável e pronta para integração. Pranchas, posts, conceitos e previews não contam como entrega final.

## Estados oficiais

1. `scaffold` — estrutura criada, sem assets finais.
2. `specified` — direção visual, IDs, dimensões e arquivos esperados definidos.
3. `production` — geração e recorte em andamento.
4. `validation` — arquivos físicos completos, aguardando gates.
5. `approved` — conteúdo e qualidade aprovados.
6. `integrated` — consumido pelo runtime real.
7. `released` — archive determinístico publicado e registrado.

Um pack só pode ser chamado de completo em `integrated` ou `released`.

## Estrutura obrigatória

```text
assets/packs/<pack_id>/
├── manifest.json
├── production-status.json
├── expected-assets.json
├── source/
├── assets/
│   ├── frames/
│   ├── tiles/
│   ├── sprites/
│   ├── portraits/
│   ├── icons/
│   ├── vfx/
│   ├── audio/
│   └── scenarios/
├── atlases/
├── metadata/
├── runtime/
├── previews/
├── reports/
└── README.md
```

Pastas vazias podem ser omitidas quando não se aplicam ao tipo de pack.

## Arquivos obrigatórios

### `manifest.json`

Contrato canônico do pack. Deve conter versão, status, IDs, tipos, caminhos, dimensões, formato, hash, dependências e destinos de runtime.

### `expected-assets.json`

Lista completa e fechada de arquivos esperados. Todo item precisa declarar:

- ID canônico;
- caminho relativo;
- tipo;
- dimensões esperadas;
- transparência obrigatória ou não;
- estado de aprovação;
- SHA-256 após a geração.

### `production-status.json`

Controle real de produção, com totais esperados, presentes, válidos, aprovados e integrados. O progresso deve ser calculado pelos arquivos físicos, nunca preenchido manualmente como concluído.

### `README.md`

Escopo, identidade visual, instruções de uso, dependências, comandos de validação e critérios de aceite.

## Convenção de nomes

```text
<categoria>__<asset_id>__<estado_ou_variante>__f<frame>.png
```

Exemplos:

```text
char__lian_wu__idle__f01.png
tile__grass_flat__variant_01.png
vfx__water_slash__impact__f03.png
portrait__lian_wu__defeated.png
```

Regras:

- minúsculas;
- `snake_case` nos identificadores;
- `__` separando blocos semânticos;
- sem espaços, acentos ou nomes genéricos;
- nenhum ID duplicado;
- arquivos derivados mantêm o mesmo ID-base.

## Gates obrigatórios

### Gate 1 — Integridade

- paths seguros;
- nenhum arquivo corrompido;
- nenhuma duplicidade de ID;
- nenhum arquivo esperado ausente;
- nenhum arquivo extra sem registro.

### Gate 2 — Imagem e áudio

- dimensões corretas;
- modo de cor correto;
- canal alpha quando exigido;
- bordas removidas em tiles conectáveis;
- pivôs consistentes;
- volume, duração e formato corretos para áudio.

### Gate 3 — Identidade

- paleta, silhueta, materiais e estilo aprovados;
- consistência entre frames e variantes;
- nenhuma prancha ou mockup usado como asset de runtime.

### Gate 4 — Hashes

- SHA-256 calculado para cada arquivo final;
- hash do archive final;
- relatórios versionados.

### Gate 5 — Runtime

- atlas e metadados importam sem erro;
- recursos Godot/Web resolvem por ID canônico;
- nenhum fallback silencioso no perfil final;
- cena de validação carrega todos os assets;
- smoke test passa.

### Gate 6 — Promoção

- status atualizado para `approved`;
- integração real concluída;
- archive determinístico produzido;
- registro de release ou promoção criado.

## Política de fallbacks

Fallbacks são permitidos somente nos estados `scaffold`, `specified` e `production`. Em `integrated` e `released`, cada ID canônico deve resolver para seu próprio payload físico.

## Política de previews

Previews, posters, contact sheets e pranchas:

- ficam exclusivamente em `previews/`;
- nunca substituem frames, tiles ou sprites individuais;
- não contam no total de assets obrigatórios;
- não podem ser carregados pelo runtime como asset final.

## Archive final

Nome recomendado:

```text
<game>_<pack_id>_v<version>_<target>.zip
```

O archive deve ser determinístico, incluir relatório e arquivo `.sha256`, e manter a estrutura relativa do pack.

## Definição de pronto

Um pack está pronto somente quando:

- 100% dos arquivos esperados existem;
- 100% passam nos gates técnicos;
- 100% dos itens obrigatórios estão aprovados;
- hashes estão registrados;
- o runtime real consome os IDs canônicos;
- o smoke test passa;
- não existe dependência de recorte, renomeação ou edição manual posterior.
