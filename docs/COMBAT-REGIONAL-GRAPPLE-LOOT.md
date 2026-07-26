# Combate Regional, Controle Ji e Espólio Temporário

## Objetivo

Esta camada transforma o contato físico do Protótipo Zero em um sistema com consequências posicionais. O mesmo golpe pode produzir resultados diferentes conforme a região atingida, o estado de postura e a arma equipada.

## Hurtboxes regionais

O lutador possui três regiões não persistentes de dano:

| Região | Vitalidade | Postura | Desarmamento | Uso estratégico |
| --- | ---: | ---: | ---: | --- |
| Cabeça | 1,16× | 0,92× | 0,82× | dano direto e pressão ofensiva |
| Tronco | 1,00× | 1,00× | 1,28× | controle de arma e desarmamento |
| Pernas | 0,84× | 1,24× | 0,64× | desequilíbrio e quebra de postura |

Uma técnica só pode registrar um contato por alvo durante sua fase ativa.

## Controle Ji

A técnica **Laço de Centro** inicia um agarrão de curta distância.

O alvo não pode ser agarrado quando:

- está em uma esquiva válida;
- está no ar;
- já está controlando outro lutador;
- já está sendo controlado;
- está na fase ativa de um ataque.

Durante o controle, o atacante escolhe a projeção pela direção mantida no encerramento:

- frente: lançamento horizontal;
- trás: troca de lado e lançamento reverso;
- salto: lançamento vertical;
- baixo: queda de maior dano de postura.

Receber um impacto interrompe o controle e solta o alvo.

## Pressão de desarmamento

Técnicas possuem um valor próprio de pressão. A região do tronco amplifica esse valor.

A pressão:

- acumula até 100%;
- diminui gradualmente fora da pressão adversária;
- recebe bônus quando a postura é quebrada;
- remove a arma apenas ao alcançar o limite.

O desarmamento não remove itens do inventário persistente. Ele cria um objeto temporário na arena.

## Armas temporárias

A arma derrubada:

- permanece por 14 segundos;
- não pode ser recolhida imediatamente pelo antigo dono;
- pode ser tomada pelo adversário;
- substitui a arma atual até o fim da rodada;
- retorna ao proprietário original na rodada seguinte.

O personagem desarmado recebe multiplicadores menores de dano e postura.

## Eco de técnica

A primeira quebra de postura de cada personagem por rodada pode liberar um eco da última técnica que ele executou.

Ao coletar o eco:

- a técnica aparece no HUD;
- pode ser executada uma única vez;
- é consumida ao iniciar a ação;
- não é adicionada permanentemente ao personagem.

Esse sistema representa o primeiro estágio da futura **Observação Marcial**.

## Controles atuais

### Jogador 1

- `E`: agarrar;
- `H`: executar eco capturado.

### Jogador 2

- `Num 4`: agarrar;
- `Num 5`: executar eco capturado.

## Limites do protótipo

Ainda não estão incluídos:

- fuga ativa de agarrão;
- disputa de agarrões simultâneos;
- queda física no chão após projeção baixa;
- armas com kits completos próprios;
- aprendizado persistente de técnicas;
- loot de acessórios e consumíveis;
- animações finais de controle e lançamento.

---

**Tehkné Solutions**
