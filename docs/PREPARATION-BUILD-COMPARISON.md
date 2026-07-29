# Comparação estratégica de builds

A preparação medieval passa a recalcular e exibir três atributos consolidados para cada mestre:

- FOR — força ofensiva;
- DEF — resistência e controle defensivo;
- AGI — mobilidade, recuperação e ritmo.

## Composição

Os valores partem dos índices Tai, Fu e Ji da build e recebem modificadores da arma principal, arma secundária e elemento.

A arma secundária contribui com metade do modificador para evitar builds excessivamente empilhadas.

## Leitura na preparação

A linha de atributos de cada mestre mostra:

```text
FOR • DEF • AGI • PODER • FOCO
```

`FOCO` identifica automaticamente o atributo dominante da configuração atual.

O resumo inferior consolida build, armas e elemento, permitindo comparar os dois lados sem sair do Conselho de Guerra.

## Atualização

A comparação é recalculada sempre que personagem, build, elemento, arma ou variante muda. O runtime não altera a persistência nem as regras já existentes da preparação.

## API

```text
comparison_snapshot(preparation)
system_snapshot()
```

## Sinais

```text
comparison_refreshed
dominant_attribute_changed
```

## Validação

```text
godot --headless --path . --script res://scripts/ci/preparation_build_comparison_smoke_test.gd
```
