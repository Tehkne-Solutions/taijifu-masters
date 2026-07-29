# TGAP Release Gate

O release de um pack TGAP somente pode ser criado quando `validation/pipeline-report.json` declarar:

```json
{
  "pipeline_passed": true,
  "promotion_blocked": false
}
```

## Comando

```bash
python scripts/tgap_release_pack.py assets/tgap/pack_01_lian_wu --version 1.0.0
```

## Saídas

O diretório `release/` recebe:

- `<pack-id>-<versão>.zip`;
- `<pack-id>-<versão>.manifest.json`;
- `<pack-id>-<versão>.sha256`.

## Determinismo

O ZIP usa:

- ordenação lexicográfica dos caminhos;
- timestamp fixo `2020-01-01T00:00:00Z`;
- permissões normalizadas;
- compressão DEFLATE nível 9;
- exclusão de `validation/`, `release/`, arquivos temporários e fontes editáveis.

Duas execuções com os mesmos arquivos devem produzir o mesmo SHA-256 do arquivo ZIP.

## Manifesto de distribuição

O manifesto registra:

- identificador e versão do pack;
- aprovação do pipeline;
- quantidade de arquivos;
- tamanho e SHA-256 de cada item;
- nome, tamanho e SHA-256 do ZIP;
- timestamp canônico usado no empacotamento.

## Modo forçado

`--force` existe apenas para diagnóstico local. Um release forçado fica marcado no manifesto e não deve ser publicado nem integrado ao runtime.
