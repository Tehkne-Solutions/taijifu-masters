# Taijifu Masters

Jogo de luta e plataforma 2D baseado no sistema Taijifu, com combate técnico, preparação estratégica de builds, domínio Tai/Ji/Fu, elementos interativos e arenas móveis.

## Estado

O repositório contém a fundação executável do **Protótipo Zero — Ruínas do Caminho Triplo**.

A implementação atual valida:

- dois jogadores locais;
- preparação de batalha com quatro builds;
- seleção independente entre fogo, água, terra e ar;
- técnica elemental própria para cada elemento;
- estados de queimadura, molhado, ancoragem, lama, desequilíbrio e vapor;
- interações fogo + água, fogo + ar, água + terra e ar + terra;
- movimento, salto variável, wall slide e wall jump;
- esquiva, defesa e aparo;
- técnicas orientadas a dados com fases de startup, atividade e recuperação;
- caminhos Tai, Ji e Fu;
- hurtboxes de cabeça, tronco e pernas;
- agarrões e projeções direcionais;
- desarmamento por pressão acumulada;
- armas temporárias coletáveis;
- ecos de técnica utilizáveis uma vez;
- vida, postura, fôlego e resistência a knockback;
- arena horizontal e vertical;
- fechamento lateral em quatro fases;
- plataforma central e elevador vertical móveis;
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
- `S`: queda rápida, varredura ou projeção baixa;
- `Q`: esquiva;
- `F`: técnica contextual;
- `G`: empurrão de Fundação;
- `E`: agarrão Ji;
- `C`: técnica elemental preparada;
- `H`: executar eco de técnica;
- `R`: defender e aparar.

### Jogador 2

- setas esquerda/direita: mover;
- seta para cima: saltar ou escolher projeção vertical;
- seta para baixo: queda rápida, varredura ou projeção baixa;
- `Num 0`: esquiva;
- `Num 1`: técnica contextual;
- `Num 2`: empurrão de Fundação;
- `Num 4`: agarrão Ji;
- `Num 6`: técnica elemental preparada;
- `Num 5`: executar eco de técnica;
- `Num 3`: defender e aparar.

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
5. o confronto final ocorre em espaço menor e com maior risco de expulsão.

A borda causa pressão intervalada, move a câmera e nunca deve causar dano a cada frame.

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
- Elementos geram estados e decisões, não dano gratuito.
- Itens da arena geram disputa territorial, não vantagem gratuita.
- Espólios são temporários no núcleo competitivo.
- A arte permanece provisória até a validação da jogabilidade.

## Documentação

- [`docs/SPRINT-10.5-ESTRATEGIA-TAIJIFU.md`](docs/SPRINT-10.5-ESTRATEGIA-TAIJIFU.md)
- [`docs/PROTOTYPE-ZERO-TEST-PLAN.md`](docs/PROTOTYPE-ZERO-TEST-PLAN.md)
- [`docs/COMBAT-REGIONAL-GRAPPLE-LOOT.md`](docs/COMBAT-REGIONAL-GRAPPLE-LOOT.md)
- [`docs/ELEMENTS-MOVING-ARENA.md`](docs/ELEMENTS-MOVING-ARENA.md)
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

## Próxima implementação

- Observação Marcial persistente;
- fuga e disputa ativa de agarrões;
- armas com kits técnicos próprios;
- bot de teste;
- telemetria de rotas e elementos;
- arte e animações provisórias mais expressivas.

---

**Tehkné Solutions**