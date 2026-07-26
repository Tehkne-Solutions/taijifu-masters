# Kits técnicos por arma e bot tático

## Objetivo

Validar duas ideias centrais do Protótipo Zero:

1. a arma equipada muda o repertório e a forma de lutar;
2. um bot pode oferecer pressão estratégica sem ler comandos ou quebrar as regras do jogador.

## Kits por arma

O repertório contextual é resolvido por `WeaponKitCatalog` com base em:

- arma realmente equipada;
- estado aéreo;
- entrada em movimento;
- comando baixo;
- predominância Ji ou Fu da build.

Isso significa que o espólio temporário passa a mudar o combate imediatamente. Roubar o bastão concede alcance e redirecionamento; roubar as manoplas concede pressão curta e dano de postura.

### Bastão Adaptativo

| Contexto | Técnica | Caminho | Função |
|---|---|---|---|
| Avanço | Estocada do Horizonte | Tai | alcance e entrada |
| Ar | Arco de Alavanca | Tai | cobertura vertical |
| Baixo | Varrida de Eixo | Ji | atacar pernas e postura |
| Neutro Ji | Gancho de Haste | Ji | controle de centro |
| Neutro Fu | Círculo de Retorno | Fu | transição e redirecionamento |

### Manoplas Sísmicas

| Contexto | Técnica | Caminho | Função |
|---|---|---|---|
| Avanço | Entrada de Obsidiana | Tai | aproximação pesada |
| Ar | Ruptura Ascendente | Tai | resposta vertical |
| Baixo | Rasteira Sísmica | Ji | alto dano de postura |
| Neutro Ji | Prensa do Centro | Ji | pressão e desarmamento |
| Neutro Fu | Giro de Fundação | Fu | reposicionamento |

### Regras

- a build mantém técnicas como fallback;
- a arma coletada substitui o kit imediatamente;
- ser desarmado ativa o kit de mãos livres;
- multiplicadores de dano e postura pertencem ao kit;
- elementos continuam independentes da arma;
- empurrão e agarrão-base continuam universais nesta etapa.

## Bot tático

O `TacticalBotRuntime` controla as mesmas ações registradas para o P2.

Ele não altera diretamente:

- vida;
- postura;
- fôlego;
- velocidade;
- janelas de aparo;
- recargas;
- dano;
- resistência.

### Informações permitidas

O bot utiliza apenas informações que poderiam ser percebidas durante a luta:

- posição e distância;
- altura e rota ocupada;
- arma equipada;
- postura e fôlego;
- fase visível do ataque adversário;
- fechamento da arena;
- estado de agarrão.

Ele não consulta qual botão o jogador pressionou nem conhece ações futuras.

### Decisões

O bot pode:

- aproximar-se;
- controlar distância;
- recuar para recuperar postura;
- defender;
- tentar aparo;
- esquivar;
- atacar com o kit equipado;
- usar elemento;
- agarrar;
- reforçar o controle;
- escolher projeção;
- alternar direções durante fuga;
- avançar para escapar da borda móvel.

### Rotas

A rota preferida é derivada do maior índice da build:

- Tai favorece altura e distância;
- Ji favorece aproximação e contato;
- Fu favorece transição e adaptação.

A navegação atual é heurística. Ela não utiliza pathfinding e deverá ser evoluída para pontos de navegação específicos da arena.

## Controle

- `Tab`: alterna entre bot P2 e jogador local P2.
- O bot começa ativado.
- Ao ser desativado, todas as ações simuladas são liberadas.

## Telemetria esperada

A camada existente deve registrar normalmente as ações do bot como P2:

- rota predominante;
- técnicas utilizadas;
- elementos;
- agarrões;
- fugas;
- resultado.

Isso permite comparar builds e comportamentos sem criar um formato de telemetria separado.

## Testes obrigatórios

### Kits

1. Bastão usa as cinco técnicas exclusivas nos contextos corretos.
2. Manoplas usam as cinco técnicas exclusivas.
3. Roubar uma arma troca o repertório durante a rodada.
4. Ser desarmado ativa mãos livres.
5. A rodada seguinte restaura o kit da build.
6. Lama e vapor ainda modificam os multiplicadores corretos.
7. Observação Marcial registra as novas técnicas.

### Bot

1. `Tab` alterna controle sem manter ações pressionadas.
2. Bot aproxima quando está distante.
3. Bot recua com postura crítica.
4. Bot reage apenas após atraso perceptível.
5. Bot não possui recursos infinitos.
6. Bot usa magia somente com fôlego suficiente.
7. Bot disputa e escapa de agarrões.
8. Bot avança com o fechamento da arena.
9. P2 local funciona após desativar o bot.
10. Telemetria inclui ações do bot.

## Bloqueadores de merge

- erro de parser;
- técnica inexistente no catálogo;
- arma roubada não altera kit;
- bot mantém comandos após ser desativado;
- bot reage no mesmo frame a todo ataque;
- bot atravessa o limite da arena por ação simulada;
- agarrão deixa ação direcional presa;
- P2 local fica inutilizável;
- regressão de elementos, loot ou Observação Marcial.

## Próximos passos

- pontos de navegação por arena;
- perfis de bot iniciante, intermediário e avançado;
- relatório visual da telemetria;
- arma secundária e troca manual;
- integração de domínio da arma com Observação Marcial.

---

**Tehkné Solutions**
