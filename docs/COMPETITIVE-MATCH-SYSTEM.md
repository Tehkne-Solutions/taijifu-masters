# Sistema competitivo de partida

**Produto desenvolvido por Tehkné Solutions**

## Fluxo

```text
PREPARAÇÃO
→ ANÁLISE VS
→ ENTRADA
→ ROUND
→ PLACAR
→ PRÓXIMO ROUND OU CAMPEÃO
```

## Configuração global

Durante a preparação, o host controla:

```text
Q / E   trocar categoria
Z / X   trocar opção
```

No gamepad 1:

```text
LB / RB       trocar categoria
LT / RT       trocar opção
```

Categorias:

- arena;
- série;
- tempo por round;
- modificador.

A configuração é salva em:

```text
user://competitive_match.json
```

## Arenas

### Ruínas do Caminho Triplo

- fechamento progressivo;
- manifestações Tai, Ji e Fu;
- plataformas móveis em velocidade padrão;
- tendência de transição Fu.

### Santuário das Quatro Correntes

- sem fechamento lateral;
- manifestações frequentes;
- plataformas mais lentas;
- maior liberdade para mobilidade Tai.

### Crisol das Cinzas

- fechamento acelerado;
- sem manifestações por padrão;
- pressão territorial elevada;
- favorece contato e controle Ji.

As três opções utilizam o blockout atual com regras ambientais diferentes. Cenas artísticas exclusivas permanecem como evolução posterior.

## Séries

- Melhor de 3: primeiro a duas vitórias.
- Melhor de 5: primeiro a três vitórias.

O placar acompanha:

- round atual;
- nomes dos personagens;
- vitórias de cada lado;
- tempo restante;
- formato da série.

## Tempo

- sem limite;
- 90 segundos;
- 60 segundos.

Quando o tempo termina, o desempate compara:

1. percentual de vida;
2. percentual de postura;
3. fôlego.

Empate exato gera uma prorrogação de 15 segundos. Nenhum vencedor é escolhido arbitrariamente.

## Modificadores

### Regras clássicas

Mantém o comportamento da arena escolhida.

### Duelo puro

- sem manifestações;
- sem fechamento lateral;
- sem pressão de borda.

### Fluxo instável

- manifestações mais rápidas;
- fechamento antecipado;
- pressão territorial ampliada.

## Tela VS

Antes da entrada, a tela analisa:

- Tai, Ji e Fu;
- alcance das armas;
- elemento;
- variante treinada;
- rota favorecida pela arena;
- vantagens prováveis;
- riscos e contrapontos.

A análise não prevê o vencedor. Ela comunica tendências para orientar a estratégia.

## Arquitetura

```text
CompetitiveMatchCatalog
CompetitiveMatchRuntime
CompetitiveArenaRuntime
VsAnalysisRuntime
competitive_main.gd
```

O `competitive_main.gd` herda o controlador principal existente e sobrescreve somente o ciclo de série. Combate, IA, telemetria, Dojo e progressão permanecem no núcleo anterior.

## Validação

O CI dedicado cobre:

- catálogo de arenas e regras;
- cálculo de melhor de 3 e melhor de 5;
- placar;
- tempo de round;
- Duelo Puro;
- configuração ambiental;
- análise VS;
- integração dos três runtimes à cena principal.

## Próximas evoluções

- cenas visuais exclusivas para cada arena;
- presets de regras nomeáveis;
- exportação e importação de loadouts;
- histórico competitivo;
- remapeamento de controles;
- reconexão automática de gamepads;
- modo torneio.

---

**Tehkné Solutions**
