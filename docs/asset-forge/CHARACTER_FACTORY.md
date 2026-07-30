# Taijifu Character Factory

A Character Factory transforma um único `Character DNA` em contratos técnicos consistentes para o Asset Forge e o runtime TGAP.

## Objetivo

Evitar que cada personagem seja configurado manualmente, reduzir divergências entre packs e impedir placeholders, contact sheets e arquivos fora do inventário oficial.

## Uso

Validar o DNA sem criar arquivos:

```bash
python tools/asset_forge/character_factory.py \
  asset-forge/characters/lian_wu.json \
  --check
```

Materializar os contratos:

```bash
python tools/asset_forge/character_factory.py \
  asset-forge/characters/lian_wu.json
```

O comando cria:

- especificação do pack;
- contrato de intake;
- contrato de revisão visual;
- contrato de release;
- cópia runtime do Character DNA.

Arquivos existentes não são substituídos. `--force` deve ser usado apenas em migrações controladas.

## Regras obrigatórias

- `id` e `pack_id` em snake_case;
- inventário de fontes explícito;
- animações mínimas explícitas;
- nenhuma geração de placeholder;
- nenhum asset fora do contrato;
- Character DNA versionado junto ao runtime;
- release continua bloqueada enquanto fontes reais ou aprovação estiverem ausentes.

## Lian Wu

O arquivo `asset-forge/characters/lian_wu.json` é o primeiro golden master. Ele descreve identidade, combate, paleta, personalidade, fontes visuais, animações e regras de produção.

A fábrica não gera arte. Ela prepara e valida toda a infraestrutura necessária para que a arte real seja processada de forma previsível.
