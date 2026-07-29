# TGAP Scene Matrix Smoke

## Objetivo

Validar o carregamento de assets durante o fluxo principal do jogo sem reintroduzir o `AssetPackRegistry`.

## Matriz

| Fase | Alias lógico | Tipo validado |
| --- | --- | --- |
| Preparação | `preparation_ui` | `Resource` |
| Arena | `arena_animation` | `SpriteFrames` com animação `idle` |
| Resultado | `result_ui` | `Resource` |

O fixture usa o alias de pack `smoke`, resolvido para `taijifu_smoke`.

## Troca de geração

O teste inicia com `generation = 1`, carrega o recurso da preparação, substitui o catálogo e o recurso pelo conteúdo da geração 2 e chama `reload_catalog()`.

A validação exige que o segundo carregamento retorne `v2-preparation`, demonstrando que a troca de geração invalida o cache anterior.

## Cena

A cena `res://scenes/main.tscn` deve existir, carregar como `PackedScene` e ser instanciável em modo headless.

## Execução

```bash
python -m pytest tests/tgap/test_scene_matrix_smoke_contract.py
godot --headless --editor --path . --quit-after 2
godot --headless --path . --script tests/tgap/runtime_scene_matrix_smoke.gd
python scripts/tgap_audit_legacy_usage.py --fail-on-findings
```

O marcador de sucesso é:

```text
TGAP_SCENE_MATRIX_SMOKE_OK
```

## Próxima expansão

Substituir gradualmente os recursos sintéticos por manifests e packs instalados da linha oficial, adicionando validação visual determinística para preparação, arena e resultado.
