# Passe visual expressivo e sequências do Dojo

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Dar identidade visual imediata aos três caminhos e aos kits existentes sem bloquear a futura troca por sprites finais, além de permitir gravar e reproduzir sequências de entrada dentro do Dojo Técnico.

## Visual procedural provisório

O desenho original do lutador continua responsável pela silhueta-base e pelos medidores. Um novo `FighterVisualOverlay` adiciona uma camada modular acima do personagem.

Essa separação permite:

- substituir o desenho por sprites sem alterar física ou combate;
- depurar ataques e estados sem depender de assets definitivos;
- manter Tai, Ji e Fu reconhecíveis mesmo com personagens diferentes;
- visualizar imediatamente a arma realmente equipada.

## Linguagem Tai, Ji e Fu

### Tai

- azul-ciano;
- linhas de velocidade;
- formas direcionais longas;
- leitura de alcance e deslocamento;
- ênfase horizontal e aérea.

### Ji

- laranja-vermelho;
- arcos densos;
- rachaduras próximas ao solo;
- leitura de peso, contato e controle;
- maior presença junto ao centro corporal.

### Fu

- violeta;
- espirais e órbitas;
- camadas de transição;
- leitura de adaptação e mudança de eixo;
- efeitos que envolvem o corpo em vez de seguir apenas uma direção.

## Identidade das armas

### Bastão Adaptativo

- eixo longo visível;
- inclinação diferente por caminho;
- ponta destacada;
- maior extensão durante técnicas Tai;
- rotação mais acentuada durante técnicas Fu.

### Faixas do Vento

- duas fitas curvas;
- movimento oscilante;
- alcance ampliado em técnicas Tai;
- rastro secundário para leitura de recuperação e transição.

### Manoplas Sísmicas e Quebra-Fundação

- punhos maiores;
- massa visual concentrada nas mãos;
- base reforçada durante Ji;
- impacto mais próximo do solo;
- cor própria para diferenciar as duas versões.

### Desarmado

- punhos pequenos e leitura corporal limpa;
- efeito Fu secundário quando uma técnica de transição é executada.

## Estados visuais

O overlay também comunica:

- defesa frontal por arco;
- esquiva por rastros de pós-imagem;
- agarrão ativo por arco de controle;
- preparação, atividade e recuperação por intensidade do efeito;
- expressão facial simplificada por sobrancelhas e olhos.

Nenhum efeito altera hitbox, hurtbox, dano, física ou prioridade.

## Gravador de sequências do Dojo

O gravador registra mudanças de entrada do P1 e reproduz os mesmos comandos como P2.

### Controles

- `F12`: iniciar ou encerrar gravação;
- `F5`: reproduzir a última sequência;
- `F1`: apagar a sequência.

O sistema exige que o Dojo esteja ativo por `F8`.

### Ações gravadas

- esquerda e direita;
- baixo;
- salto;
- esquiva;
- técnica contextual;
- empurrão;
- agarrão;
- eco;
- defesa;
- técnica elemental;
- troca de arma.

### Funcionamento

1. o jogador entra no Dojo;
2. pressiona `F12`;
3. executa uma sequência com P1;
4. pressiona `F12` novamente ou aguarda o limite de oito segundos;
5. pressiona `F5`;
6. posições e recursos são reiniciados;
7. o boneco passa para modo passivo;
8. a sequência é reproduzida usando as ações reais do P2.

A reprodução não injeta dano, movimento ou animação diretamente. Ela somente pressiona e libera as ações de entrada existentes.

## Persistência

A última sequência é salva em:

```text
user://dojo_sequence.json
```

O arquivo registra:

- versão;
- duração;
- lista de eventos;
- tempo de cada mudança;
- ação;
- estado pressionado ou liberado.

## Limites

- duração máxima: oito segundos;
- uma sequência persistente por vez;
- reprodução disponível somente no Dojo;
- a sequência usa as builds e variantes atualmente equipadas;
- resultados podem mudar quando build, arma, elemento ou posição inicial mudam;
- o recurso é uma ferramenta de treino e depuração, não um replay determinístico de partida.

## Critérios de validação no Godot 4.3+

1. o projeto importa sem erros;
2. o overlay acompanha os dois lutadores;
3. Bastão, Faixas e Manoplas são visualmente distintos;
4. armas roubadas atualizam o overlay;
5. desarmamento remove a arma visual;
6. Tai, Ji e Fu possuem leitura diferente;
7. defesa não cria efeitos ofensivos;
8. a esquiva mostra rastros sem alterar colisões;
9. `F12` grava apenas dentro do Dojo;
10. a gravação encerra em oito segundos;
11. `F5` reinicia posições e reproduz no P2;
12. todas as ações são liberadas ao final;
13. sair do Dojo interrompe gravação e reprodução;
14. `F1` remove o arquivo persistido;
15. a sequência carregada após reiniciar mantém duração e eventos;
16. o desempenho permanece estável com dois overlays ativos.

## Próxima etapa

- sprites provisórios em folhas de poses-chave;
- efeitos de impacto com onomatopeias em estilo mangá;
- hitstop e shake calibrados por caminho;
- gravação de múltiplos slots de sequência;
- boneco repetindo automaticamente em loop;
- comparação entre técnica-base e variante com métricas lado a lado.
