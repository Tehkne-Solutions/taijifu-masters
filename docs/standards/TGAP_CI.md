# TGAP — Integração contínua

O workflow `.github/workflows/tgap.yml` executa automaticamente o pipeline técnico dos packs alterados.

## Pull requests

Quando arquivos de `assets/tgap/`, scripts `tgap_*.py`, padrões TGAP ou `tgap.json` mudam, o workflow descobre os packs afetados e executa:

1. inventário;
2. gate visual;
3. gate de animação;
4. gate de runtime;
5. relatório consolidado.

Os relatórios da pasta `validation/` são publicados como artifacts mesmo quando o gate falha.

## Execução manual

Use `workflow_dispatch`, informe `pack_root` e deixe `release_version` vazio para validar somente o pack.

## Release

Uma release pode ser gerada manualmente com uma versão sem o prefixo `v`, ou por uma tag no padrão:

```text
tgap-<pack-id>-v<semver>
```

Exemplo:

```text
tgap-pack-01-lian-wu-v1.0.0
```

O job de release só começa quando todos os gates passam. O gerador produz ZIP determinístico, manifesto e checksums, publica os arquivos como artifact e, em tags, anexa-os à GitHub Release existente.

## Proteções recomendadas

Na proteção da branch `main`, torne obrigatório o check `TGAP / validate` para alterações nos packs. Tags de release devem ser criadas somente após aprovação artística e técnica do pack.
