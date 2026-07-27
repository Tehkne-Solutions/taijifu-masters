# Temporadas, comparação de perfis e fase de grupos

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Esta entrega adiciona uma camada competitiva persistente sem criar pontuações paralelas. Todas as classificações continuam sendo recalculadas a partir do histórico real de séries.

---

## Temporadas competitivas

Atalho:

```text
F7
```

Controles:

```text
↑/↓      selecionar temporada
Enter    ativar temporada
N        criar temporada
R        renomear temporada
C        encerrar temporada ativa
F7       fechar
```

Persistência:

```text
user://competitive_seasons.json
```

Cada série passa a registrar:

```text
season_id
season_name
```

O histórico foi migrado para a versão 4. Séries anteriores recebem:

```text
season_id = season_legacy
season_name = HISTÓRICO ANTERIOR
```

Nenhuma série antiga é descartada.

O painel sazonal mostra:

- séries;
- rounds;
- KOs;
- prorrogações;
- duração média;
- classificação por perfil;
- vitórias e derrotas;
- saldo de rounds;
- dano;
- aparos;
- quebras de postura;
- desarmes.

A temporada pode ser usada como filtro programático no histórico:

```text
{"season_id": "season_..."}
```

---

## Comparação direta entre perfis

Atalho:

```text
F6
```

Controles:

```text
↑/↓   selecionar perfil
C     marcar ou desmarcar
V     comparar dois perfis
A     alternar histórico completo / temporada ativa
F6    fechar
```

A comparação mostra:

- séries disputadas;
- vitórias;
- derrotas;
- taxa de vitória;
- rounds vencidos;
- vitórias por KO;
- dano total;
- aparos;
- quebras de postura;
- desarmes;
- personagem mais utilizado;
- confronto direto;
- vitórias no head-to-head;
- rounds no head-to-head;
- delta do Perfil B em relação ao Perfil A.

O agrupamento utiliza `profile_id`. Jogadores que usam o mesmo personagem permanecem separados.

---

## Fase de grupos

Atalho:

```text
F11
```

Formato:

```text
8 competidores
2 grupos de 4
6 séries por grupo
12 séries no total
2 classificados por grupo
```

Distribuição balanceada de seeds:

```text
Grupo A: 1, 4, 5, 8
Grupo B: 2, 3, 6, 7
```

Controles:

```text
Page Up/Down  selecionar seed
Home/End      trocar fonte/loadout
Ctrl+S        sortear
Enter         iniciar
Delete        reiniciar
F11           fechar
```

Cada vitória vale 3 pontos.

Critérios de desempate, na ordem:

1. pontos;
2. vitórias;
3. saldo de rounds;
4. rounds vencidos;
5. seed original.

A tabela mostra:

```text
posição
competidor
pontos
jogos
vitórias
Derrotas
rounds pró
rounds contra
saldo
```

---

## Transição para o mata-mata

Quando as doze séries terminam, os classificados são identificados como:

```text
A1
A2
B1
B2
```

As semifinais são montadas automaticamente:

```text
A1 × B2
B1 × A2
```

Os quatro classificados são enviados ao sistema de torneio já existente. O painel `F10` passa a mostrar as semifinais, final e campeão.

A próxima série é carregada automaticamente na preparação.

---

## Registro das partidas

Antes de iniciar cada série, o fluxo resolve:

1. contexto do perfil;
2. contexto da temporada;
3. modo atual: livre, grupos ou mata-mata;
4. loadouts dos dois competidores;
5. configuração competitiva.

O registro final preserva:

```text
match_id
season_id
season_name
profile_id
profile_name
character_id
build_name
loadout
rounds
estatísticas
destaques
resultado
```

---

## Arquitetura

```text
scripts/seasons/competitive_season_ledger.gd
scripts/runtime/competitive_season_runtime.gd
scripts/runtime/profile_comparison_runtime.gd
scripts/tournament/group_stage_ledger.gd
scripts/runtime/group_stage_runtime.gd
scripts/runtime/series_statistics_runtime.gd
scripts/history/match_history_ledger.gd
scripts/competitive_main.gd
scenes/main.tscn
```

---

## Validação automatizada

O novo gate verifica:

- criação e ativação de temporadas;
- sanitização de nomes;
- migração de registros legados;
- filtro e agregação por temporada;
- registro da temporada na série atual;
- ranking sazonal;
- comparação entre perfis;
- confronto direto;
- criação de dois grupos;
- geração dos doze confrontos;
- atualização das tabelas;
- critérios de classificação;
- quatro classificados;
- cruzamento das semifinais;
- integração dos três runtimes na cena principal.

---

## Limites atuais

As temporadas e grupos são locais.

Ainda não há:

- sincronização entre dispositivos;
- autenticação online;
- servidor autoritativo;
- dupla eliminação;
- ligas remotas;
- matchmaking online;
- temporadas com calendário automático.

---

**Tehkné Solutions**
