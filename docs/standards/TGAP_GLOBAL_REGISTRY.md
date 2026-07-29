# Registro global TGAP

O arquivo `tgap-registry.json` é a fonte única para relações entre packs.

## Responsabilidades

- registrar versão e classe de cada pack;
- declarar dependências obrigatórias e opcionais;
- definir ordem determinística de integração;
- declarar compatibilidade com TGAP, runtime e projeto;
- impedir ciclos, dependências ausentes e versões incompatíveis;
- verificar que o registro corresponde ao `manifest.json` real.

## Execução

```bash
python scripts/tgap_registry_gate.py
pytest -q tests/tgap/test_registry_gate.py
```

O relatório é escrito em:

```text
artifacts/tgap/registry-gate-report.json
```

## Dependências

```json
{
  "pack_id": "pack_02_arena_core",
  "version": ">=1.0.0",
  "optional": false
}
```

Operadores aceitos: `=`, `>`, `>=`, `<`, `<=`, `~` e `^`.

## Ordem de integração

Uma dependência obrigatória deve possuir `integration_order` menor que o pack dependente. Valores repetidos são proibidos. O gate também executa detecção de ciclos no grafo global.

## Publicação conjunta

Antes de gerar um bundle de múltiplos packs, execute o registry gate. O campo `integration_plan` do relatório fornece a ordem canônica dos packs habilitados.
