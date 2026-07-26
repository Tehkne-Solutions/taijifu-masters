# Taijifu Masters

Jogo de luta e plataforma 2D baseado no sistema Taijifu, com combate técnico, builds estratégicas, domínio Tai/Ji/Fu, elementos interativos, espólio temporário e arenas móveis.

## Estado

O repositório contém a fundação executável do **Protótipo Zero — Ruínas do Caminho Triplo**.

A implementação atual valida:

- dois jogadores locais ou P1 contra bot tático;
- preparação com quatro builds e quatro elementos;
- kits técnicos definidos pela arma realmente equipada;
- Bastão Adaptativo e Manoplas Sísmicas;
- troca imediata de repertório ao roubar uma arma;
- quatro dificuldades de IA;
- quatro personalidades de IA;
- navegação por pontos estratégicos Tai, Ji e Fu;
- objetivos de engajar, controlar, transicionar, disputar e escapar;
- prevenção contra bloqueio de navegação;
- heatmap acumulado de posições e quedas;
- dashboard visual pós-rodada;
- movimento, wall slide, wall jump e recuperação aérea;
- defesa, aparo, postura, agarrões e projeções;
- hurtboxes regionais;
- desarmamento e armas temporárias;
- ecos de técnica utilizáveis uma vez;
- Observação Marcial persistente em sete estágios;
- fogo, água, terra e ar com interações situacionais;
- arena horizontal e vertical com fechamento lateral;
- Manifestações do Fluxo disputáveis.

## Tecnologia

- Godot 4.3+
- GDScript
- simulação a 60 Hz
- primeiro alvo: Windows e Linux

## Executar

1. Clone o repositório.
2. Abra a pasta no Godot 4.3 ou superior.
3. Importe o projeto.
4. Execute com **F5**.
5. Escolha build e elemento e pressione `Enter`.

O P2 começa controlado pelo bot.

## Controles de sistema e depuração

- `Tab`: alternar bot e P2 local;
- `F2`: abrir ou fixar o relatório da última rodada;
- `F3`: mostrar ou ocultar o heatmap;
- `F4`: avançar o nível de dificuldade do bot;
- `F7`: avançar a personalidade do bot.

## Preparação

### Jogador 1

- `A/D`: escolher build;
- `Q/E`: escolher elemento.

### Jogador 2

- setas esquerda/direita: escolher build;
- `Num 4/Num 5`: escolher elemento.

## Controles de batalha

### Jogador 1

- `A/D`: mover;
- `W`: saltar ou escolher projeção vertical;
- `S`: queda rápida, técnica baixa ou projeção baixa;
- `Q`: esquiva;
- `F`: técnica contextual do kit;
- `G`: empurrão de Fundação;
- `E`: agarrão Ji ou reforço de controle;
- `C`: técnica elemental;
- `H`: executar eco;
- `R`: defender e aparar.

### Jogador 2 local

- setas esquerda/direita: mover;
- seta para cima: salto ou projeção vertical;
- seta para baixo: queda rápida, técnica baixa ou projeção baixa;
- `Num 0`: esquiva;
- `Num 1`: técnica contextual;
- `Num 2`: empurrão;
- `Num 4`: agarrão ou reforço;
- `Num 6`: técnica elemental;
- `Num 5`: executar eco;
- `Num 3`: defender e aparar.

## Kits técnicos

### Bastão Adaptativo

- Estocada do Horizonte;
- Arco de Alavanca;
- Varrida de Eixo;
- Gancho de Haste;
- Círculo de Retorno.

Prioriza alcance, varredura e redirecionamento Fu.

### Manoplas Sísmicas

- Entrada de Obsidiana;
- Ruptura Ascendente;
- Rasteira Sísmica;
- Prensa do Centro;
- Giro de Fundação.

Priorizam entrada pesada, postura e desarmamento.

## Dificuldades do bot

### Aprendiz

- reação lenta;
- mais hesitações;
- defesa inconsistente;
- menor eficiência em fuga e navegação.

### Discípulo

- nível padrão;
- comportamento equilibrado;
- erros legíveis.

### Adepto

- decisões mais frequentes;
- defesa consistente;
- menos erros táticos.

### Mestre

- maior consistência e leitura;
- atraso mínimo preservado;
- nenhuma vantagem de dano, vida, fôlego ou atributos.

## Personalidades do bot

### Agressivo

Busca contato Ji, agarrões e pressão contínua.

### Guardião

Prioriza defesa, controle territorial e recuperação de postura.

### Técnico

Prioriza Fu, transições, leitura e adaptação. É o perfil padrão.

### Caótico

Usa mais elementos, manifestações e mudanças de rota, sem ignorar ameaças imediatas.

O bot utiliza as mesmas ações, custos, técnicas, recursos e colisões dos jogadores. Ele observa apenas estados legíveis da luta e nunca lê diretamente o botão pressionado pelo adversário.

## Pontos estratégicos

A arena contém posições classificadas por rota, função e risco:

- **Tai:** terreno elevado, alcance e entradas;
- **Ji:** corredores, contato e controle;
- **Fu:** transições, recursos, plataformas móveis e ascensão.

Pontos atrás da borda móvel são descartados. A IA pode abandonar qualquer plano diante de ataque, agarrão, postura crítica ou colapso.

## Elementos

- **Fogo:** pressão, queimadura e combustão com ar;
- **Água:** empurrão, extinção, aderência e lama com terra;
- **Terra:** postura, ancoragem e resistência a rajadas;
- **Ar:** interrupção, deslocamento e amplificação de fogo.

As relações alteram condições da luta, não usam um multiplicador universal de vantagem.

## Observação Marcial

O conhecimento de uma técnica evolui por ações reais:

1. vista;
2. reconhecida;
3. compreendida;
4. defendida;
5. reproduzida;
6. adaptada;
7. dominada.

O registro é salvo em:

```text
user://martial_observation.json
```

## Telemetria e dashboard

Cada rodada registra:

- ocupação Tai, Ji e Fu;
- técnicas;
- respostas defensivas;
- elementos;
- interações;
- agarrões e fugas;
- vencedor e duração.

`F2` abre o relatório visual. O JSON completo é gravado em:

```text
user://telemetry/taijifu_<sessão>.json
```

## Heatmap

O heatmap acumula células de permanência separadas para P1 e P2 e marca pontos de queda.

- azul: P1;
- laranja: P2;
- maior opacidade: maior ocupação;
- X: queda.

`F3` alterna a visualização. O arquivo é gravado em:

```text
user://telemetry/heatmap_<sessão>.json
```

## Espólio do protótipo

- armas derrubadas são temporárias;
- o antigo dono não pode recolher imediatamente o próprio item;
- a primeira quebra de postura pode liberar um eco;
- o eco é consumido após uma execução;
- itens originais retornam na rodada seguinte;
- não existe perda persistente de inventário.

## Princípios do protótipo

- técnica e leitura permanecem decisivas;
- builds mudam possibilidades, não garantem vitória;
- atributos alteram comportamento, não apenas números;
- armas mudam repertório e risco;
- dificuldade altera consistência, não poder oculto;
- personalidade altera prioridades, não regras;
- elementos geram estados e decisões;
- pontos estratégicos orientam, mas não aprisionam a IA;
- conhecimento exige observação, defesa, reprodução e adaptação;
- espólios são temporários no núcleo competitivo.

## Documentação

- [`docs/SPRINT-10.5-ESTRATEGIA-TAIJIFU.md`](docs/SPRINT-10.5-ESTRATEGIA-TAIJIFU.md)
- [`docs/PROTOTYPE-ZERO-TEST-PLAN.md`](docs/PROTOTYPE-ZERO-TEST-PLAN.md)
- [`docs/COMBAT-REGIONAL-GRAPPLE-LOOT.md`](docs/COMBAT-REGIONAL-GRAPPLE-LOOT.md)
- [`docs/ELEMENTS-MOVING-ARENA.md`](docs/ELEMENTS-MOVING-ARENA.md)
- [`docs/MARTIAL-OBSERVATION-GRAB-TELEMETRY.md`](docs/MARTIAL-OBSERVATION-GRAB-TELEMETRY.md)
- [`docs/WEAPON-KITS-TACTICAL-BOT.md`](docs/WEAPON-KITS-TACTICAL-BOT.md)
- [`docs/TELEMETRY-DASHBOARD-STRATEGIC-NAVIGATION.md`](docs/TELEMETRY-DASHBOARD-STRATEGIC-NAVIGATION.md)
- [`docs/BOT-DIFFICULTY-PERSONALITY-HEATMAP.md`](docs/BOT-DIFFICULTY-PERSONALITY-HEATMAP.md)
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

## Próxima implementação

- arma secundária e troca manual;
- domínio de arma baseado em uso real;
- integração entre Observação Marcial, mestres e treinamento;
- comparação de heatmaps entre sessões;
- arte e animações provisórias mais expressivas.

---

**Tehkné Solutions**
