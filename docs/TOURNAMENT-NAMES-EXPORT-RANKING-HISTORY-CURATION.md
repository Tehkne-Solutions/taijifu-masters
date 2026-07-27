# Nomes, sorteio, exportação, ranking e curadoria

**Produto desenvolvido por Tehkné Solutions**

## Torneio: nomes editáveis

No painel `F10`, cada seed pode receber um nome próprio antes do torneio começar.

```text
N      editar nome da seed selecionada
Enter  confirmar o texto
```

Regras:

- até 36 caracteres;
- espaços extras são removidos;
- quebras de linha são eliminadas;
- nomes ficam bloqueados depois do início do torneio;
- caso o campo fique vazio, o nome da fonte do loadout é utilizado.

## Sorteio automático

```text
Ctrl+S  embaralhar os competidores entre as seeds
```

O sorteio altera apenas a associação entre fonte de loadout e seed.

Os nomes personalizados continuam vinculados à seed escolhida.

O algoritmo usa Fisher–Yates e aceita seed fixa nos testes automatizados.

## Exportação visual do chaveamento

```text
Ctrl+E  exportar bracket
```

São gerados dois arquivos:

```text
user://exports/taijifu-bracket-<formato>-<data>.svg
user://exports/taijifu-bracket-<formato>-<data>.json
```

### SVG

O SVG inclui:

- título Taijifu Masters;
- assinatura Tehkné Solutions;
- quartas, semifinais e final;
- nomes e seeds;
- vencedores já definidos;
- campeão quando o torneio está concluído.

### JSON

O JSON possui a assinatura:

```text
TAIJIFU_TOURNAMENT_BRACKET
```

O conteúdo inclui o snapshot completo e pode servir como base para futuras integrações, overlays e páginas externas.

O bracket pode ser exportado antes da primeira luta, durante o torneio ou após a final.

## Ranking local

Novo atalho:

```text
F8  abrir ou fechar ranking
```

O ranking é recalculado a partir de `user://match_history.json`.

Não existe pontuação manual ou arquivo duplicado.

### Métricas consideradas

- séries vencidas e perdidas;
- rounds vencidos e perdidos;
- vitórias por KO;
- aparos;
- quebras de postura;
- desarmes.

### Base de rating

Cada lutador começa conceitualmente em 1000 pontos.

O rating aumenta ou diminui conforme resultados e execução técnica. O objetivo é formar uma leitura local de desempenho, não um ranking online oficial.

## Favoritos e tags

Dentro do histórico `F3`, a série selecionada pode ser organizada.

```text
B       favoritar ou remover favorito
Ctrl+1  tag Técnica
Ctrl+2  tag Revanche
Ctrl+3  tag Torneio
Ctrl+4  tag Destaque
```

Metadados são salvos dentro do próprio registro em:

```text
user://match_history.json
```

### Tags disponíveis

- `technical` — confronto com valor técnico;
- `rematch` — série que merece revanche;
- `tournament` — partida relevante de torneio;
- `highlight` — série com momentos especiais.

## Filtro de curadoria

O histórico recebeu um quarto campo de filtro:

```text
Curadoria
```

Opções:

- todas;
- favoritas;
- Técnica;
- Revanche;
- Torneio;
- Destaque.

Esse filtro pode ser combinado com personagem, arena e resultado.

## Arquitetura

```text
scripts/tournament/tournament_bracket_exporter.gd
scripts/runtime/tournament_runtime.gd
scripts/runtime/local_ranking_runtime.gd
scripts/history/match_history_ledger.gd
scripts/runtime/match_history_runtime.gd
scenes/main.tscn
```

## Compatibilidade

O histórico foi migrado para a versão 3.

Registros antigos recebem automaticamente:

```text
favorite = false
tags = []
```

Nenhuma série anterior é descartada.

## Validação automatizada

O novo gate verifica:

- sanitização de nomes;
- sorteio reproduzível com seed fixa;
- exportação de SVG;
- exportação de JSON assinado;
- presença dos nomes no SVG;
- ativação de favorito;
- inclusão e remoção de tags;
- filtros de curadoria;
- agregação de favoritas;
- integração do ranking;
- reação do rating às vitórias;
- presença dos runtimes na cena principal.

## Próximas evoluções

- ranking por perfil de jogador;
- exportação PNG do bracket;
- comparação direta entre duas séries;
- busca textual no histórico;
- tags personalizadas;
- fase de grupos;
- dupla eliminação;
- sincronização de rankings entre dispositivos.

---

**Tehkné Solutions**
