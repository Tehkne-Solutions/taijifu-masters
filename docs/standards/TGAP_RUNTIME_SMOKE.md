# TGAP Runtime Smoke

## Objetivo

Validar em Godot headless que o jogo inicializa com `TgapAssetLoader` como único autoload de assets, lê um catálogo instalado, resolve e carrega um recurso real e instancia a cena principal.

## Cobertura

O harness `tests/tgap/runtime_smoke_test.gd` cria um fixture isolado em `user://tgap-smoke` com:

- catálogo `tgap/install-catalog/v1`;
- geração `1`;
- pack integrado de smoke;
- recurso `.tres` real;
- versão esperada e cenário de versão incompatível.

Depois valida:

1. `TgapAssetLoader` registrado;
2. `AssetPackRegistry` ausente do autoload;
3. catálogo carregado;
4. geração correta;
5. resolução de caminho por pack e versão;
6. rejeição de versão incompatível;
7. carregamento real pelo `ResourceLoader`;
8. existência, carregamento e instanciação de `res://scenes/main.tscn`.

## Execução local

```bash
python -m pytest tests/tgap/test_runtime_smoke_contract.py tests/tgap/test_legacy_autoload_removed.py
godot --headless --editor --path . --quit-after 2
godot --headless --path . --script tests/tgap/runtime_smoke_test.gd
python scripts/tgap_audit_legacy_usage.py --fail-on-findings
```

Sucesso do smoke Godot:

```text
TGAP_RUNTIME_SMOKE_OK
```

## Falhas bloqueantes

- autoload TGAP ausente;
- singleton legado registrado;
- catálogo inválido ou não carregado;
- recurso instalado não resolvido;
- versão incompatível aceita;
- recurso real não carregado;
- cena principal ausente, inválida ou não instanciável;
- referência legada encontrada em produção.

## Próxima etapa

Expandir a matriz de smoke para as cenas de preparação, arena e resultado, usando packs reais do bundle instalado e verificando aliases lógicos, animações e invalidação por geração.
