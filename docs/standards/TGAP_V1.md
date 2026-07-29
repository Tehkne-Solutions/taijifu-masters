# Tehkné Game Asset Pipeline — TGAP v1.0

## Objetivo

Padronizar a produção, validação, integração e publicação de assets para todos os jogos da Tehkné.

O TGAP trata o pack físico como produto. Posters, pranchas, previews, conceitos e relatórios nunca contam como assets finais.

## Ciclo oficial

1. `scaffold` — contrato e diretórios criados;
2. `specified` — inventário esperado e requisitos fechados;
3. `production` — arquivos físicos começaram a entrar;
4. `validation` — todos os arquivos esperados existem e passam nos gates técnicos;
5. `approved` — revisão visual e funcional registrada;
6. `integrated` — runtime real consome IDs canônicos sem fallback silencioso;
7. `released` — archive determinístico publicado com SHA-256.

Nenhum estado pode ser pulado.

## Estrutura obrigatória

```text
assets/tgap/<pack_id>/
├── manifest.json
├── expected-assets.json
├── production-status.json
├── approval.json
├── source/
├── frames/
├── atlases/
├── metadata/
├── runtime/
├── validation/
├── preview/
└── release/
```

Diretórios não aplicáveis continuam declarados no manifesto, mas podem permanecer vazios até o gate correspondente.

## Classes de assets

- `character`
- `unit`
- `terrain`
- `board`
- `vegetation`
- `prop`
- `structure`
- `resource`
- `pickup`
- `vfx`
- `ui`
- `card`
- `audio`
- `environment`

## Fonte permitida

A entrada de produção deve conter somente arquivos-fonte utilizáveis:

- PNG RGBA transparente;
- spritesheet limpa;
- imagem individual sem texto ou moldura;
- áudio bruto;
- arquivo vetorial ou 3D declarado;
- metadata estruturada.

Poster, mockup, relatório, prancha com títulos e screenshot de editor ficam apenas em `preview/` e recebem `runtime_eligible: false`.

## Identidade e nomes

IDs canônicos usam `snake_case`:

```text
<domain>.<entity>.<variant>.<state>
```

Arquivos usam:

```text
<domain>__<entity>__<variant>__<state>__f<NN>.png
```

Exemplo:

```text
character.lian_wu.default.idle
char__lian_wu__default__idle__f01.png
```

## Gates obrigatórios

### Integridade

- todos os caminhos são relativos e seguros;
- nenhum ID é duplicado;
- nenhum arquivo esperado está ausente;
- hashes SHA-256 correspondem aos arquivos;
- arquivos vazios são rejeitados.

### Imagem

- formato, dimensões e modo de cor correspondem ao contrato;
- transparência real quando exigida;
- nenhum fundo, texto, moldura ou artefato externo;
- pivô e escala consistentes;
- tiles conectáveis não têm bordas externas.

### Animação

- quantidade de frames exata;
- ordem estável;
- FPS e loop declarados;
- pivô sem jitter acima da tolerância;
- eventos, sockets, hitboxes e hurtboxes versionados quando aplicável.

### Runtime

- cada asset resolve por ID canônico;
- nenhum fallback silencioso em `integrated` ou `released`;
- cena ou teste de validação carrega o pack;
- referências ausentes bloqueiam promoção.

### Release

- archive determinístico;
- inventário final;
- relatório de validação;
- SHA-256 do archive;
- versão semântica;
- origem e licença registradas.

## Definição de pronto

Um pack só é completo quando:

- `missing_assets = 0`;
- todos os gates técnicos passam;
- aprovação visual está registrada;
- runtime usa o pack real;
- fallback está desativado;
- archive e digest existem;
- estado é `released`.

## Regra de honestidade

O status é calculado a partir dos arquivos físicos e dos relatórios. Alterar manualmente `status` não promove um pack.

## Primeiro projeto piloto

O PACK 01 — Lian Wu do Taijifu Masters será o primeiro pack migrado integralmente para o TGAP v1.0.
