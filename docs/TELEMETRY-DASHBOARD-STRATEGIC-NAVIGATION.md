# Dashboard de Telemetria e Navegação Estratégica

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Transformar os dados do Protótipo Zero em uma leitura visual imediatamente útil e substituir a navegação puramente reativa do bot por decisões ligadas à arquitetura Tai, Ji e Fu da arena.

---

# 1. Pontos estratégicos

As Ruínas do Caminho Triplo possuem pontos de intenção classificados por:

- identificador;
- rota Tai, Ji ou Fu;
- função tática;
- posição;
- risco;
- disponibilidade diante do fechamento lateral.

## Funções disponíveis

- `high_ground`: posição superior para alcance e recuperação;
- `range`: manutenção de distância;
- `choke`: corredor estreito para pressão Ji;
- `control`: domínio de curta distância;
- `transition`: troca entre alturas e rotas;
- `resource`: disputa por Manifestação do Fluxo;
- `ascent`: avanço durante a fase vertical;
- `recovery`: posição segura para recompor recursos.

Os pontos não são caminhos obrigatórios. O bot pode abandonar o objetivo quando:

- recebe uma ameaça imediata;
- entra em um agarrão;
- uma manifestação relevante aparece;
- sua postura se torna crítica;
- a borda móvel ameaça sua posição.

---

# 2. Objetivos do bot

## Engajar

Aproxima o bot de uma zona favorável ao Ji e ao alcance de sua arma.

## Controlar

Ocupa uma posição compatível com a rota predominante da build.

## Alcance

Busca terreno Tai com separação suficiente para bastão, entrada ou magia.

## Transição

Busca pontos Fu capazes de reduzir diferenças verticais.

## Disputar

Prioriza uma Manifestação quando:

- o recurso é necessário;
- o tipo coincide com a rota predominante;
- a distância permite disputa real.

## Escapar

Ignora os demais planos e avança para uma posição segura quando a borda se aproxima ou a postura fica crítica.

---

# 3. Prevenção contra bloqueio

O runtime acompanha deslocamento real.

Quando existe comando de movimento, mas o personagem praticamente não sai do lugar:

- acumula tempo de bloqueio;
- tenta um salto controlado;
- renova o objetivo pouco depois;
- nunca mantém um ponto inválido durante toda a rodada.

Os pontos fechados pela borda são automaticamente removidos da lista de candidatos.

---

# 4. Dashboard visual

Ao concluir uma rodada, o sistema apresenta por aproximadamente dois segundos:

- vencedor;
- duração;
- tempo em Tai, Ji e Fu;
- técnicas iniciadas;
- respostas defensivas;
- agarrões;
- fugas;
- elementos conjurados;
- interações elementais;
- diagnóstico resumido de estilo.

O relatório mais recente pode ser aberto ou mantido na tela com `F2`.

---

# 5. Diagnósticos de estilo

A primeira versão utiliza regras explicáveis.

## Controlador de contato

Ativado quando existe uso recorrente de agarrões.

## Tecelão de condições

Ativado quando o jogador utiliza elementos com frequência.

## Leitor adaptativo

Ativado quando bloqueios, aparos e esquivas possuem presença relevante.

## Estratégia em formação

Utilizado quando ainda não existe comportamento dominante suficiente.

Todos os diagnósticos são combinados com a rota predominante da rodada.

---

# 6. Persistência

Os dados continuam sendo gravados em:

```text
user://telemetry/taijifu_<sessão>.json
```

O formato foi atualizado para a versão 2 e mantém:

- sessões;
- rodadas;
- jogadores;
- rotas;
- contadores;
- eventos;
- vencedor;
- duração.

---

# 7. Testes obrigatórios

## Arena

- os pontos atrás da borda deixam de ser candidatos;
- cada rota mantém ao menos um destino viável durante sua fase relevante;
- uma manifestação atrás da área segura não deve ser perseguida;
- os marcadores não afetam colisão;
- o reset restaura todos os pontos possíveis da primeira fase.

## Bot

- escolhe posições diferentes com builds Tai, Ji e Fu;
- abandona o ponto para reagir a um ataque próximo;
- procura manifestação apenas quando existe justificativa;
- avança diante do colapso;
- tenta salto quando fica bloqueado;
- não recebe teleporte ou movimento impossível;
- `Tab` libera todas as ações simuladas.

## Dashboard

- abre somente após uma rodada concluída;
- mostra os dois jogadores;
- barras somam o tempo aproximado da rodada;
- contadores correspondem ao JSON;
- some automaticamente sem impedir o próximo round;
- `F2` reabre e fecha o último relatório;
- funciona quando o arquivo não puder ser salvo;
- não cria múltiplos painéis após resets.

---

# 8. Bloqueadores antes do merge

- executar no Godot 4.3+;
- confirmar os métodos e estilos dos componentes de interface;
- verificar a ordem de `_ready()` dos runtimes;
- validar pontos superiores e descidas no blockout;
- confirmar que a exibição automática não cobre uma ação já iniciada no novo round;
- conferir o JSON de versão 2.

---

# 9. Próxima evolução

- níveis de dificuldade e personalidade do bot;
- relatório acumulado de várias rodadas;
- heatmap de posições e quedas;
- arma secundária e troca manual;
- domínio de armas conectado a mestres e treinamento;
- navegação com conexões explícitas entre plataformas.

---

**Tehkné Solutions**
