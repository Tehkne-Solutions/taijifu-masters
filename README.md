# Taijifu Masters

Jogo de luta e plataforma 2D baseado no sistema Taijifu, com combate técnico, preparação estratégica de builds, domínio Tai/Ji/Fu, elementos interativos e arenas móveis.

## Estado

O repositório contém a fundação executável do **Protótipo Zero — Ruínas do Caminho Triplo**.

A implementação atual valida:

- dois jogadores locais ou P1 contra bot tático;
- preparação de batalha com quatro builds;
- kits técnicos ligados à arma realmente equipada;
- Bastão Adaptativo com alcance, varredura e redirecionamento;
- Manoplas Sísmicas com pressão, postura e desarmamento;
- troca imediata de repertório ao roubar uma arma;
- bot com decisões de aproximação, defesa, magia, agarrão e rotas Tai/Ji/Fu;
- seleção independente entre fogo, água, terra e ar;
- técnica elemental própria para cada elemento;
- estados de queimadura, molhado, ancoragem, lama, desequilíbrio e vapor;
- interações fogo + água, fogo + ar, água + terra e ar + terra;
- movimento, salto variável, wall slide e wall jump;
- esquiva, defesa e aparo;
- técnicas orientadas a dados com fases de startup, atividade e recuperação;
- caminhos Tai, Ji e Fu;
- hurtboxes de cabeça, tronco e pernas;
- agarrões, projeções direcionais e fuga ativa;
- disputa de controle baseada em Ji, Fu, Controle, Técnica e fôlego;
- desarmamento por pressão acumulada;
- armas temporárias coletáveis;
- ecos de técnica utilizáveis uma vez;
- Observação Marcial persistente em sete estágios;
- telemetria de rotas, técnicas, elementos, agarrões e resultados;
- arena horizontal e vertical com fechamento lateral;
- Manifestações do Fluxo disputáveis;
- câmera dinâmica e reinício completo de rodada.

## Tecnologia

- Godot 4.3+
- GDScript
- Simulação a 60 Hz
- Primeiro alvo: Windows e Linux

## Executar

1. Clone o repositório.
2. Abra a pasta no Godot 4.3 ou superior.
3. Importe o projeto.
4. Execute o projeto com **F5**.
5. Escolha build e elemento e pressione `Enter`.

O P2 começa controlado pelo bot. Pressione `Tab` para alternar entre bot e controle local.

## Preparação

### Jogador 1

- `A/D`: escolher build;
- `Q/E`: escolher elemento.

### Jogador 2

- setas esquerda/direita: escolher build;
- `Num 4/Num 5`: escolher elemento.

## Controles de batalha

### Jogador 1

- `A` / `D`: mover;
- `W`: saltar ou escolher projeção vertical;
- `S`: queda rápida, técnica baixa ou projeção baixa;
- `Q`: esquiva;
- `F`: técnica contextual do kit equipado;
- `G`: empurrão de Fundação;
- `E`: agarrão Ji ou reforço de controle;
- `C`: técnica elemental preparada;
- `H`: executar eco de técnica;
- `R`: defender e aparar.

### Jogador 2 local

- setas esquerda/direita: mover;
- seta para cima: saltar ou escolher projeção vertical;
- seta para baixo: queda rápida, técnica baixa ou projeção baixa;
- `Num 0`: esquiva;
- `Num 1`: técnica contextual do kit equipado;
- `Num 2`: empurrão de Fundação;
- `Num 4`: agarrão Ji ou reforço de controle;
- `Num 6`: técnica elemental preparada;
- `Num 5`: executar eco de técnica;
- `Num 3`: defender e aparar.

## Kits técnicos por arma

A técnica contextual não depende apenas da build inicial. Ela é resolvida pela arma equipada naquele momento.

### Bastão Adaptativo

- **Estocada do Horizonte:** entrada Tai de longo alcance;
- **Arco de Alavanca:** controle aéreo Tai;
- **Varrida de Eixo:** pressão baixa Ji;
- **Gancho de Haste:** controle de centro Ji;
- **Círculo de Retorno:** redirecionamento Fu.

### Manoplas Sísmicas

- **Entrada de Obsidiana:** aproximação pesada Tai;
- **Ruptura Ascendente:** resposta aérea Tai;
- **Rasteira Sísmica:** alto dano de postura Ji;
- **Prensa do Centro:** pressão curta e desarmamento Ji;
- **Giro de Fundação:** reposicionamento Fu.

Ao coletar uma arma derrubada, o lutador recebe imediatamente o kit correspondente até o fim da rodada.

## Bot tático

O bot usa as mesmas ações, custos, atributos e técnicas disponíveis para um jogador.

Ele observa apenas estados legíveis da luta, como:

- distância;
- posição na arena;
- fase visível do ataque;
- postura e fôlego;
- arma equipada;
- rota mais compatível com sua build.

O bot possui atraso de reação influenciado por Percepção e pode:

- aproximar ou controlar distância;
- defender e tentar aparos;
- esquivar;
- usar técnicas do kit;
- conjurar elemento;
- agarrar e reforçar controle;
- alternar direções para fugir de agarrões;
- avançar quando a borda da arena se fecha.

Ele não recebe dano reduzido, recursos infinitos ou leitura direta dos comandos do jogador.

## Fuga ativa de agarrões

Durante um agarrão, o alvo pode:

- alternar esquerda e direita para gerar progresso de fuga;
- usar esquiva para uma tentativa forte que consome fôlego;
- usar ataque ou defesa para ganhos menores;
- aproveitar um índice Fu elevado para escapar com maior eficiência.

O agarrador pode pressionar novamente o comando de agarrão para gastar fôlego e reduzir o progresso do alvo. Ji e Controle aumentam a dificuldade da fuga.

## Observação Marcial

O conhecimento de uma técnica evolui por ações reais:

1. vista;
2. reconhecida;
3. compreendida;
4. defendida;
5. reproduzida;
6. adaptada;
7. dominada.

Ver repetidamente ajuda apenas nos primeiros estágios. Para avançar, o jogador precisa defender, aparar, reproduzir o eco e adaptar a técnica em combate.

O registro é salvo em:

```text
user://martial_observation.json
```

## Telemetria do protótipo

Cada rodada registra tempo nas rotas Tai/Ji/Fu, técnicas, elementos, agarrões, fugas, resultado e duração.

Os relatórios são gravados em:

```text
user://telemetry/taijifu_<sessão>.json
```

## Elementos

- **Fogo:** pressão, queimadura e combustão com ar.
- **Água:** empurrão, extinção, perda de aderência e lama com terra.
- **Terra:** postura, ancoragem, resistência a rajadas e controle do solo.
- **Ar:** interrupção, knockback e amplificação de fogo.

Os elementos alteram condições da luta. Não existe um multiplicador universal de vantagem elemental.

## Tai, Ji e Fu

- **Tai:** distância longa, pernas, alcance, entradas e perseguição.
- **Ji:** curta distância, contato, controle, agarrões e quedas.
- **Fu:** adaptação, transição, esquiva, mudança de rota e uso do ambiente.

## Arena em movimento

A rodada começa com todas as rotas disponíveis. Depois:

1. a borda esquerda inicia o colapso;
2. o setor Ji inicial deixa de ser seguro;
3. a arena força avanço lateral;
4. a luta migra para uma ascensão vertical;
5. o confronto final ocorre em espaço menor.

## Regras de espólio do protótipo

- armas derrubadas são temporárias;
- o antigo dono não pode recolher imediatamente o próprio item;
- a primeira quebra de postura pode liberar um eco da última técnica usada;
- o eco é consumido após uma execução;
- todos os itens originais retornam na rodada seguinte;
- não existe perda persistente de inventário.

## Princípios do protótipo

- Técnica e leitura permanecem decisivas.
- Builds mudam possibilidades, não garantem vitória.
- Atributos devem alterar comportamento, não apenas números.
- Armas mudam repertório e risco, não apenas dano.
- O bot respeita as mesmas regras do jogador.
- Elementos geram estados e decisões, não dano gratuito.
- Conhecimento exige observação, defesa, reprodução e adaptação.
- Espólios são temporários no núcleo competitivo.

## Documentação

- [`docs/SPRINT-10.5-ESTRATEGIA-TAIJIFU.md`](docs/SPRINT-10.5-ESTRATEGIA-TAIJIFU.md)
- [`docs/PROTOTYPE-ZERO-TEST-PLAN.md`](docs/PROTOTYPE-ZERO-TEST-PLAN.md)
- [`docs/COMBAT-REGIONAL-GRAPPLE-LOOT.md`](docs/COMBAT-REGIONAL-GRAPPLE-LOOT.md)
- [`docs/ELEMENTS-MOVING-ARENA.md`](docs/ELEMENTS-MOVING-ARENA.md)
- [`docs/MARTIAL-OBSERVATION-GRAB-TELEMETRY.md`](docs/MARTIAL-OBSERVATION-GRAB-TELEMETRY.md)
- [`docs/WEAPON-KITS-TACTICAL-BOT.md`](docs/WEAPON-KITS-TACTICAL-BOT.md)
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

## Próxima implementação

- relatório visual da telemetria;
- bot com navegação por pontos da arena;
- integração entre Observação Marcial, mestres e treinamento;
- equipamento secundário e troca de arma;
- arte e animações provisórias mais expressivas.

---

**Tehkné Solutions**
