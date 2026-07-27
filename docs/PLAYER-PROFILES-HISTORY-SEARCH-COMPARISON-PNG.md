# Perfis locais, busca, comparação e exportação PNG

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Esta entrega separa o jogador do personagem utilizado, amplia a consulta do histórico, permite comparar duas séries e adiciona PNG ao pacote exportável do chaveamento.

---

## Perfis locais de jogador

Atalho:

```text
F9
```

Controles:

```text
Tab      alternar P1/P2
↑/↓      selecionar perfil
Enter    ativar
N        criar
R        renomear
Delete   remover
F9       fechar
```

Os perfis são persistidos em:

```text
user://player_profiles.json
```

Cada série passa a registrar:

```text
profile_id
profile_name
character_id
character_name
build_name
loadout
```

Isso permite que o mesmo jogador utilize personagens e builds diferentes sem perder sua identidade competitiva.

Perfis padrão `JOGADOR 1` e `JOGADOR 2` são protegidos contra exclusão.

---

## Ranking por perfil

O ranking `F8` deixou de agrupar exclusivamente pelo personagem.

Agora a chave principal é:

```text
profile_id
```

O personagem mais utilizado aparece como contexto, mas a pontuação pertence ao jogador.

Séries antigas, sem `profile_id`, continuam disponíveis por meio de entradas legadas agrupadas pelo personagem.

O rating continua derivado exclusivamente de:

```text
user://match_history.json
```

Não existe arquivo paralelo de pontuação.

---

## Busca textual do histórico

No painel `F3`:

```text
Ctrl+F
```

A busca reconhece:

- nome do perfil;
- personagem;
- build;
- arena;
- configuração competitiva;
- tags;
- motivo do resultado;
- destaques técnicos;
- identificador da série.

A consulta ignora diferenças simples de maiúsculas e acentuação.

Ela pode ser combinada com:

- personagem;
- arena;
- resultado;
- curadoria.

Exemplo:

```text
Busca: aparo
Arena: Crisol das Cinzas
Curadoria: Técnica
```

---

## Comparação entre duas séries

No histórico:

```text
C   marcar ou desmarcar série
V   abrir comparação
```

No máximo duas séries ficam selecionadas. Ao selecionar uma terceira, a marcação mais antiga é removida.

A comparação apresenta:

- placar;
- rounds;
- duração;
- dano total;
- aparos;
- quebras de postura;
- desarmes;
- destaques;
- arena;
- vencedor;
- personagens;
- perfis P1 e P2;
- delta da Série B em relação à Série A.

A tela não declara uma série superior fora do contexto; apresenta diferenças mensuráveis.

Arquivo:

```text
scripts/runtime/series_comparison_runtime.gd
```

---

## Exportação PNG do chaveamento

O comando existente continua:

```text
Ctrl+E
```

A exportação agora gera três arquivos do mesmo snapshot:

```text
user://exports/taijifu-bracket-<formato>-<data>.svg
user://exports/taijifu-bracket-<formato>-<data>.png
user://exports/taijifu-bracket-<formato>-<data>.json
```

O PNG é rasterizado a partir do SVG gerado pelo próprio jogo. Assim, nomes, seeds, vencedores e campeão permanecem idênticos nos três formatos.

Dimensões:

```text
4 competidores: 1120 × 620
8 competidores: 1500 × 900
```

---

## Arquitetura

```text
scripts/profiles/player_profile_ledger.gd
scripts/runtime/player_profile_runtime.gd
scripts/runtime/series_comparison_runtime.gd
scripts/history/match_history_ledger.gd
scripts/runtime/match_history_runtime.gd
scripts/runtime/local_ranking_runtime.gd
scripts/runtime/series_statistics_runtime.gd
scripts/tournament/tournament_bracket_exporter.gd
scripts/competitive_main.gd
scenes/main.tscn
```

---

## Validação automatizada

O novo gate verifica:

- criação, sanitização e ativação de perfis;
- proteção dos perfis padrão;
- busca por perfil, arena e destaque;
- combinação de texto e filtros;
- preservação do perfil no comparador;
- construção do relatório comparativo;
- geração do PNG;
- assinatura binária PNG;
- dimensões válidas;
- integração dos runtimes na cena principal.

---

## Limites atuais

Os perfis são locais e não possuem autenticação ou sincronização entre dispositivos.

A comparação trabalha com duas séries por vez.

A próxima evolução deverá incluir:

- sincronização entre dispositivos;
- comparação entre perfis;
- temporada competitiva;
- fase de grupos;
- dupla eliminação;
- exportação de relatórios completos.

---

**Tehkné Solutions**
