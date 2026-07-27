# Menu Web, tutorial adaptativo e acessibilidade

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Esta entrega transforma a camada Web do Taijifu Masters em uma experiência de entrada e configuração completa, sem alterar as regras do combate em Godot.

A implementação cobre:

- menu inicial;
- primeiro treinamento guiado;
- tutorial adaptado ao dispositivo;
- menu acessível durante a arena;
- preferências visuais;
- personalização dos controles touch;
- persistência local;
- validação desktop e mobile em Chromium.

---

## Primeira execução

Quando o navegador ainda não possui treinamento concluído, o botão principal exibe:

```text
Começar treinamento
```

O clique abre três etapas:

1. movimento, salto, queda rápida e empurrão;
2. golpe, esquiva, guarda, aparo e agarrão;
3. elemento, eco, troca de arma e evolução por perfil.

Ao concluir a terceira etapa:

- a preferência `tutorialCompleted` é salva;
- o tutorial fecha;
- a arena recebe foco;
- o áudio pode ser liberado pela interação;
- o jogo é iniciado.

Nas visitas seguintes, o botão passa a exibir:

```text
Entrar na arena
```

---

## Tutorial adaptativo

A camada Web identifica:

- teclado e mouse;
- tela touch;
- gamepad conectado.

Os cartões mantêm a mesma ação, mas alteram a indicação de entrada.

Exemplo:

```text
Teclado: A / D
Touch: ◀ / ▶
Gamepad: Direcional
```

O tutorial pode ser reaberto a qualquer momento pelo menu ou pelas configurações.

---

## Menu durante a arena

Depois que o jogo é iniciado, a barra Web apresenta:

```text
Menu
Instalar
Tela cheia
```

O botão `Menu` abre a camada sobre o canvas e libera todas as teclas virtuais pressionadas.

A batalha em Godot continua executando ao fundo; portanto, esta camada ainda não é um sistema de pausa do jogo.

Para voltar:

```text
Voltar à arena
```

Também é possível pressionar `Esc` para fechar o menu ou o diálogo ativo.

---

## Preferências persistentes

As configurações são salvas em:

```text
localStorage: taijifu.web.preferences.v1
```

Não são enviadas a servidor e não afetam ranking, dano, atributos ou regras competitivas.

### Acessibilidade visual

- alto contraste;
- interface Web ampliada;
- movimento reduzido;
- foco visível para teclado;
- anúncios em região `aria-live`;
- estruturas de diálogo e títulos semânticos.

### Controles touch

- exibição automática;
- exibição sempre ativa;
- controles ocultos;
- escala entre 80% e 130%;
- opacidade entre 35% e 100%;
- modo canhoto;
- resposta tátil quando `navigator.vibrate` estiver disponível.

---

## Arquitetura

```text
web/taijifu-web-shell.css
web/taijifu-web-shell.js
web/taijifu-web-menu.css
web/taijifu-web-menu.js
scripts/prepare-web-pwa.py
scripts/validate-web-build.py
web-tests/web-smoke.spec.cjs
```

O Godot continua sendo exportado normalmente. O pós-processador copia e injeta os arquivos Web antes da validação e da publicação.

---

## Validação automatizada

### Desktop — 1280 × 720

O Chromium verifica:

- carregamento completo;
- botão `Começar treinamento`;
- três etapas do tutorial;
- entrada automática após conclusão;
- menu durante a arena;
- abertura das configurações;
- alto contraste;
- interface ampliada;
- movimento reduzido;
- escala e opacidade touch;
- persistência no `localStorage`;
- ausência de falhas JavaScript e de rede.

### Mobile — 844 × 390

O Chromium verifica:

- identificação de tela touch;
- bindings adaptados;
- entrada na arena;
- controles virtuais;
- modo canhoto;
- exibição sempre ativa;
- escala e opacidade;
- eventos `keydown` e `keyup`;
- proteção de orientação;
- retorno para paisagem;
- ausência de falhas JavaScript e de rede.

---

## Limites atuais

- o menu Web ainda não pausa o runtime Godot;
- as configurações ficam restritas ao navegador e dispositivo;
- os controles touch ainda representam apenas o P1;
- não existe remapeamento individual de cada ação;
- vibração depende do navegador e do sistema operacional;
- não há sincronização em nuvem.

---

## Próxima evolução recomendada

- ponte JavaScript ↔ Godot para pausa real;
- remapeamento individual de teclado e touch;
- perfis de configuração por jogador;
- tutorial prático dentro da arena;
- calibração de gamepad;
- modo daltônico com paletas específicas;
- sincronização das preferências na conta do jogador.

---

**Tehkné Solutions**
