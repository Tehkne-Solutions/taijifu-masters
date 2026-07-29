# Baseline visual oficial TGAP

O baseline visual usa somente packs registrados em `tgap-registry.json`. Ele não converte um pack ainda bloqueado em pack integrado e não oculta arquivos ausentes.

## Pack oficial inicial

O registro atual contém `pack_01_lian_wu`, versão `0.1.0`. O manifesto permanece no estado `specified`, com promoção bloqueada até que todos os gates e a aprovação sejam concluídos.

## Evidências coletadas

Para cada pack registrado, o relatório preserva:

- versão e estado do manifesto;
- identidade visual declarada;
- presença dos arquivos de runtime;
- tamanho em bytes;
- SHA-256 de atlas, metadados, SpriteFrames e manifesto de runtime;
- condição objetiva de promoção.

## Execução

```bash
pytest -q tests/tgap/test_official_visual_baseline.py
python scripts/tgap_official_visual_baseline.py
```

O modo estrito deve ser ativado somente quando os packs selecionados estiverem em `approved`, `integrated` ou `released`:

```bash
python scripts/tgap_official_visual_baseline.py --strict
```

## Saída

```text
artifacts/tgap/official-visual-baseline.json
```

A comparação visual posterior deverá combinar estes hashes com capturas determinísticas de preparação, arena e resultado. Alterações intencionais exigirão atualização revisada do baseline; alterações não explicadas bloquearão a promoção.
