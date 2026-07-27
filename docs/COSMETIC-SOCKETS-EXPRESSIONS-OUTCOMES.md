# Sockets cosméticos, expressões e resultados visuais

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Esta entrega cria a primeira infraestrutura visual para pets, acessórios e amuletos, sincroniza expressões faciais com o contexto do combate e representa o encerramento da rodada com queda, derrota e vitória.

Nenhum recurso desta camada altera:

- dano;
- defesa;
- hitboxes;
- hurtboxes;
- alcance competitivo;
- fôlego;
- postura;
- física;
- prioridade de técnicas.

---

## Catálogo de sockets

Arquivo:

```text
scripts/visual/cosmetic_socket_catalog.gd
```

Sockets disponíveis:

| Socket | Uso |
|---|---|
| `head` | coroas, diademas, chifres e halos |
| `back` | cachecóis, mantos, fitas e estandartes |
| `chest` | amuletos |
| `pet` | companheiro flutuante ou terrestre |

As posições consideram:

- Kael, Nara, Lyra e Rin;
- idle, movimento, ataque e guarda;
- quatro quadros por estado;
- direção do personagem;
- transformação de queda, derrota ou vitória.

## Itens iniciais

### Cabeça

- Diadema do Vento;
- Coroa de Pedra;
- Chifres de Brasa;
- Halo Lunar.

### Costas

- Cachecol do Fluxo;
- Estandarte Guardião;
- Manto de Brasa;
- Fitas da Maré.

### Amuletos

- Amuleto de Jade;
- Amuleto de Brasa;
- Amuleto da Maré;
- Amuleto da Terra.

### Pets

- Nimbo;
- Raposa Espiritual;
- Espírito de Pedra;
- Salamandra de Fogo.

Cada personagem possui um loadout padrão coerente com sua identidade, mas qualquer combinação pode ser escolhida.

---

## Editor de loadout cosmético

Arquivo:

```text
scripts/runtime/cosmetic_loadout_runtime.gd
```

Atalho:

```text
J — abrir ou fechar
```

Controles com o painel aberto:

```text
Tab       alternar P1/P2
← / →     trocar socket
↑ / ↓     trocar item
R         restaurar padrão do personagem
Enter     salvar
J         fechar e salvar
```

O editor:

1. exige que uma batalha tenha sido iniciada;
2. pausa a simulação;
3. mantém a interface ativa;
4. aplica o item imediatamente;
5. salva por perfil de jogador;
6. restaura o estado anterior de pausa ao fechar.

Persistência:

```text
user://cosmetic_loadout.json
```

O ledger sanitiza itens inválidos e impede que um item de um tipo seja aplicado no socket errado.

---

## Presenter cosmético

Arquivo:

```text
scripts/visual/cosmetic_socket_presenter.gd
```

Responsabilidades:

- seguir personagem, estado e quadro;
- acompanhar direção;
- acompanhar queda, derrota e vitória;
- animar balanço de mantos e fitas;
- animar pulso dos amuletos;
- animar flutuação dos pets;
- renderizar somente apresentação visual.

Os pets não possuem colisão nem participam do sistema de loot nesta etapa.

---

## Expressões faciais

Arquivo:

```text
scripts/visual/fighter_expression_overlay.gd
```

Expressões disponíveis:

- neutra;
- determinada — ataques Tai;
- feroz — ataques Ji;
- fluxo — ataques Fu;
- foco — defesa;
- dor — dano recente;
- choque — agarrão ou queda;
- exaustão — vida crítica;
- vitória;
- derrota.

As expressões utilizam:

- sobrancelhas;
- abertura dos olhos;
- boca;
- gotas de suor;
- marcas de choque;
- brilho de vitória.

O overlay acompanha a rotação e a escala do corpo durante o resultado da rodada.

---

## Resultado visual do lutador

Arquivo:

```text
scripts/visual/fighter_outcome_runtime.gd
```

Estados:

```text
normal
fall
defeat
victory
```

### Queda

- duração de 0,42 segundo;
- rotação progressiva;
- deslocamento para baixo;
- compressão vertical;
- expressão de choque.

### Derrota

- pose caída estável;
- opacidade reduzida;
- expressão derrotada;
- física do lutador congelada até o reset.

### Vitória

- elevação leve;
- pulsação de escala;
- oscilação controlada;
- expressão de vitória;
- física congelada após o resultado.

`reset_outcome()` restaura transformação, velocidade e processamento físico.

---

## Coordenação da rodada

Arquivo:

```text
scripts/runtime/match_outcome_runtime.gd
```

O runtime observa os lutadores já criados pelo fluxo oficial.

Quando ocorre derrota:

1. identifica o derrotado;
2. aciona queda e derrota;
3. identifica o oponente;
4. aciona vitória;
5. aguarda o reset oficial de `main.gd`;
6. confirma vida restaurada e `_resetting_round = false`;
7. limpa os estados;
8. devolve o processamento físico.

O arquivo principal da batalha não foi alterado.

---

## Integração de cena

### Lutador

```text
OutcomeRuntime
SpritePresenter
WeaponTrail
VisualOverlay
CosmeticSockets
ExpressionOverlay
RegionalHitFlash
```

### Cena principal

```text
CosmeticLoadoutRuntime
MatchOutcomeRuntime
```

O HUD passa a exibir:

```text
J cosméticos
```

---

## Validação automatizada

O smoke test verifica:

1. importação de todos os scripts;
2. quatro sockets por personagem;
3. primeiro item de cada socket como `none`;
4. loadout padrão completo;
5. sanitização de itens inválidos;
6. presenter cosmético nas seis builds;
7. expressão de vitória em prévia;
8. rotação durante queda;
9. reset do resultado;
10. editor cosmético na cena principal;
11. coordenador de resultado na cena principal;
12. preservação dos testes de técnicas, trilhas, hit flash e editor de encaixes.

---

## Validação visual manual

1. iniciar batalha com personagens diferentes;
2. abrir o editor com `J`;
3. alternar P1 e P2;
4. testar todos os sockets;
5. fechar e reabrir o projeto;
6. confirmar persistência;
7. atacar com Tai, Ji e Fu;
8. bloquear, receber dano e ficar com vida crítica;
9. observar expressões diferentes;
10. concluir uma rodada;
11. verificar queda do derrotado;
12. verificar vitória do oponente;
13. confirmar reset e retorno dos controles;
14. confirmar ausência de colisão em pets e acessórios.

---

## Próxima etapa

- sockets editáveis por quadro;
- presets cosméticos exportáveis para o repositório;
- pets com reações a impacto e vitória;
- expressões ampliadas em retratos de HUD;
- animações específicas de entrada na arena;
- trilhas elementais combinadas;
- tela de seleção completa de personagem, build e cosméticos.

---

**Tehkné Solutions**
