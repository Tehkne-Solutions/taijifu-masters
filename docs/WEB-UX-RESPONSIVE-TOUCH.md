# Experiência Web responsiva e controles touch

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Esta entrega transforma a exportação Web bruta do Godot em uma experiência própria do Taijifu Masters, mantendo o runtime do jogo isolado da camada de apresentação do navegador.

A solução é aplicada depois da exportação por:

```text
scripts/prepare-web-pwa.py
```

O processo copia os arquivos do shell, injeta a interface no `index.html` e inclui todos os recursos no cache da PWA.

---

## Tela inicial Web

Antes de acessar o canvas, o jogador encontra uma tela de entrada com:

- identidade Taijifu Masters;
- conceito Tai, Ji e Fu;
- descrição curta do jogo;
- progresso de carregamento;
- estado da arena;
- botão `Entrar na arena`;
- indicação de teclado, gamepad e touch.

O botão permanece desativado até o runtime do Godot remover sua tela interna de carregamento.

Ao entrar:

1. a tela inicial desaparece;
2. o canvas recebe foco;
3. a interação libera o contexto de áudio do navegador;
4. ferramentas e controles adequados ao dispositivo aparecem.

Também é possível entrar usando `Enter` ou `Espaço` no desktop.

---

## Canvas responsivo

O canvas mantém proporção:

```text
16:9
```

Ele ocupa o maior espaço possível sem ultrapassar a largura ou altura da janela.

A configuração funciona para:

- monitores desktop;
- notebooks;
- tablets em paisagem;
- celulares em paisagem;
- modo tela cheia;
- PWA instalada.

O jogo continua renderizando internamente em 1280 × 720, enquanto o navegador adapta apenas o tamanho visual.

---

## Ferramentas Web

Após a entrada, a interface mostra:

```text
Tela cheia
Instalar
```

`Instalar` aparece somente quando o navegador disponibiliza o evento nativo de instalação da PWA.

O modo tela cheia utiliza a Fullscreen API. Em navegadores sem suporte, o jogo continua funcionando dentro da aba.

---

## Proteção de orientação

Em dispositivo touch ou tela pequena, quando a janela está em retrato, o jogo apresenta:

```text
Gire o dispositivo
```

O canvas e o estado da partida permanecem ativos por trás da proteção. Ao voltar para paisagem, a batalha reaparece imediatamente.

A orientação também está declarada como `landscape` no manifesto da PWA.

---

## Controles touch

A primeira versão touch controla o Jogador 1.

### Movimento

```text
◀      mover para esquerda
▶      mover para direita
Pulo   saltar
▼      abaixar ou executar queda rápida
```

### Combate principal

```text
Golpe      técnica contextual
Esquiva    esquiva
Push       empurrão de Fundação
Guarda     defesa e aparo
Elemento   técnica elemental
```

### Técnicas adicionais

O botão `Mais` abre:

```text
Agarra   agarrão ou reforço
Eco      executar eco técnico
Arma     trocar arma equipada
```

Os botões convertem eventos de ponteiro em eventos de teclado compatíveis com os controles P1 existentes:

```text
A D W S Q F G E C H R V
```

Movimento e guarda permanecem pressionados enquanto o dedo continua sobre o botão.

Quando a aba perde foco ou o navegador vai para segundo plano, todas as teclas virtuais são liberadas para evitar movimento preso.

---

## Arquitetura

```text
web/taijifu-web-shell.css
web/taijifu-web-shell.js
scripts/prepare-web-pwa.py
scripts/validate-web-build.py
web-tests/web-smoke.spec.cjs
```

A camada Web não altera:

- colisões;
- física;
- frame data;
- regras competitivas;
- scripts dos lutadores;
- histórico;
- torneios;
- temporadas.

---

## Validação automatizada

O pipeline Web agora testa duas experiências.

### Desktop — 1280 × 720

- shell inicial visível;
- progresso chega a 100%;
- botão de entrada é liberado;
- canvas é inicializado;
- entrada na arena funciona;
- ferramenta de tela cheia aparece;
- nenhuma requisição obrigatória falha;
- nenhuma exceção JavaScript ocorre.

### Mobile touch — 844 × 390

- jogo carrega em modo mobile;
- shell libera a entrada;
- controles touch aparecem;
- botão de movimento gera `keydown` e `keyup`;
- orientação retrato exibe a proteção;
- retorno à paisagem restaura a interface;
- nenhuma requisição obrigatória falha;
- nenhuma exceção JavaScript ocorre.

O CI salva duas capturas:

```text
taijifu-web-desktop.png
taijifu-web-mobile-touch.png
```

---

## Limites desta versão

Os controles touch são uma camada de compatibilidade sobre o mapa de teclado do P1.

Ainda não foram implementados:

- dois jogadores simultâneos no mesmo celular;
- joystick analógico virtual;
- vibração/háptica;
- remapeamento de botões;
- escala configurável dos controles;
- gestos combinados;
- tutorial específico para touch;
- otimização completa da interface interna do Godot para telas pequenas.

A recomendação para PvP local continua sendo teclado ou dois gamepads.

---

## Próxima evolução recomendada

1. menu inicial nativo dentro do jogo;
2. tutorial interativo para teclado, gamepad e touch;
3. configurações de acessibilidade;
4. escala e posição configurável dos controles;
5. vibração em impactos e aparos;
6. telemetria de tempo de carregamento;
7. sincronização de progresso em nuvem;
8. lobby e multiplayer online.

---

**Tehkné Solutions**
