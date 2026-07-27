# Offsets por técnica, Editor de Encaixes e Trilhas de Arma

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Esta entrega especializa a apresentação visual das técnicas sem alterar física, dano, hitboxes, prioridade ou alcance competitivo.

O sistema passa a distinguir visualmente:

- estocadas;
- varreduras;
- ganchos;
- golpes ascendentes;
- reversões;
- investidas;
- técnicas elementais.

Também fornece um editor persistente dentro do jogo e trilhas produzidas pela posição real da ponta da arma.

---

## Perfis visuais por técnica

Arquivo:

```text
scripts/visual/technique_attachment_catalog.gd
```

Cada técnica pode definir ajustes para quatro estágios:

```text
startup
active_early
active_late
recovery
```

Valores ajustáveis:

- posição da mão principal;
- posição da mão de apoio;
- ângulo;
- multiplicador de alcance visual;
- duração da trilha;
- largura da trilha;
- opacidade.

Os perfis são aplicados depois do encaixe-base do personagem e antes dos ajustes criados pelo editor.

### Ordem de resolução

1. personagem;
2. estado corporal;
3. quadro do atlas;
4. técnica;
5. estágio da técnica;
6. override persistente do usuário.

A resolução é apenas visual.

---

## Técnicas especializadas

O primeiro catálogo inclui perfis próprios para:

- Estocada do Horizonte;
- Arco de Alavanca;
- Varrida de Eixo;
- Gancho de Haste;
- Círculo de Retorno;
- Entrada de Obsidiana;
- Ruptura Ascendente;
- Rasteira Sísmica;
- Prensa do Centro;
- Giro de Fundação;
- Passo Longo;
- Arco Ascendente;
- Varredura de Base;
- Golpe de Transição;
- Reversão do Fluxo;
- técnicas elementais de fogo, água, terra e ar.

Quando uma técnica não possui deslocamento específico, ela continua utilizando o encaixe-base e pode receber um perfil posteriormente.

---

## Editor Persistente de Encaixes

Arquivo:

```text
scripts/runtime/attachment_editor_runtime.gd
```

Atalho principal:

```text
F6 — abrir ou fechar
```

O editor trabalha sobre o P1 durante uma batalha.

Ao abrir:

1. encontra o P1;
2. armazena o estado de pausa;
3. pausa a simulação;
4. fixa o atlas no quadro do estágio escolhido;
5. mantém o overlay processando;
6. aplica os ajustes em tempo real.

### Controles

```text
← / →       técnica anterior ou seguinte
↑ / ↓       estágio anterior ou seguinte
A / D       mão principal no eixo X
W / S       mão principal no eixo Y
Shift+A/D   mão de apoio no eixo X
Shift+W/S   mão de apoio no eixo Y
Q / E       ângulo
Z / X       alcance visual
R           restaurar estágio atual
Enter       salvar
F6          fechar e salvar
```

### Persistência

```text
user://attachment_overrides.json
```

Chave lógica:

```text
personagem|técnica|estágio
```

Exemplo:

```text
kael|staff_long_thrust|active_late
```

Os ajustes são carregados automaticamente e aplicados durante as batalhas seguintes.

---

## Prévia visual

O `ProvisionalSpritePresenter` recebeu um modo de prévia fixa.

O editor utiliza:

| Estágio | Quadro |
|---|---:|
| startup | 0 |
| active_early | 1 |
| active_late | 2 |
| recovery | 3 |

A prévia não modifica o estado de ataque do controlador e não habilita a hitbox.

---

## Timeline por contexto

O `TechniqueVisualTimeline` agora pode resolver valores a partir de um contexto explícito:

- fase;
- progresso;
- caminho Tai, Ji ou Fu.

Isso permite que o runtime normal e o editor usem a mesma lógica visual.

Funções existentes continuam disponíveis para o combate real.

---

## Ponta real da arma

O `FighterVisualOverlay` agora expõe:

```text
current_weapon_tip_global()
current_trail_profile()
current_trail_color()
current_visual_context()
current_attachment()
```

A ponta é calculada depois de considerar:

- personagem;
- quadro;
- direção;
- técnica;
- estágio;
- override do editor;
- arma equipada.

Para Faixas do Vento, a ponta corresponde ao último ponto da fita principal.

Para Manoplas, corresponde ao centro da manopla dianteira.

Para combate desarmado, corresponde ao punho principal.

---

## Trilhas de arma

Arquivo:

```text
scripts/visual/weapon_trail_runtime.gd
```

O runtime armazena posições globais recentes da ponta visual.

Características:

- máximo de 22 amostras;
- distância mínima entre amostras;
- limpeza em teletransportes;
- duração por técnica;
- largura por técnica;
- opacidade diferente em startup, atividade e recuperação;
- desaparecimento progressivo.

A trilha não possui:

- colisão;
- hurtbox;
- hitbox;
- dano;
- impulso;
- efeito sobre prioridade.

---

## Integração

### Lutador

```text
SpritePresenter
WeaponTrail
VisualOverlay
RegionalHitFlash
```

### Cena principal

```text
AttachmentEditorRuntime
```

### HUD

O atalho `F6` passa a ser exibido na ajuda inferior.

---

## Validação automatizada

O smoke test confirma:

1. importação dos novos scripts;
2. perfis de técnica válidos;
3. trilhas com campo `enabled`;
4. resolução de quatro estágios;
5. mão principal válida;
6. alcance visual positivo;
7. presença de `WeaponTrail` em todas as builds;
8. armazenamento de pontos de teste;
9. integração do editor na cena principal;
10. aplicação de override em memória;
11. preservação das validações anteriores.

---

## Validação manual

1. Iniciar uma batalha.
2. Executar Estocada do Horizonte.
3. Conferir preparação, extensão e retorno.
4. Executar Varrida de Eixo.
5. Conferir trilha baixa e circular.
6. Executar Ruptura Ascendente.
7. Conferir trilha vertical.
8. Abrir o editor com `F6`.
9. Selecionar uma técnica e um estágio.
10. Ajustar mão, apoio, ângulo e alcance.
11. Fechar e reabrir o jogo.
12. Confirmar persistência.
13. Confirmar que a hitbox não mudou.
14. Confirmar que trilhas desaparecem corretamente.
15. Confirmar limpeza após reinício do Dojo.

---

## Próxima etapa

- sockets para pets, acessórios e amuletos;
- expressões faciais sincronizadas;
- animações de queda, vitória e derrota;
- presets de editor exportáveis para o repositório;
- trilhas elementais específicas por combinação;
- editor visual de sockets e acessórios.

---

**Tehkné Solutions**
