# Arma secundária e domínio baseado em uso

## Objetivo

Adicionar decisões de repertório durante a luta sem transformar a troca de arma em cancelamento gratuito, e registrar domínio real separado por arma.

## Slots

Cada build possui:

- arma principal;
- arma secundária;
- slot de espólio temporário, criado somente quando uma arma adversária é coletada.

A ordem de troca é:

```text
Principal → Secundária → Espólio → Principal
```

Slots indisponíveis são ignorados.

## Regras da troca

A troca manual:

- exige que o lutador esteja no chão;
- custa 8 de fôlego;
- não pode ocorrer durante ataque, esquiva, defesa ou agarrão;
- aplica 0,32 segundo de recuperação;
- muda imediatamente o kit contextual;
- pode ser punida pelo adversário.

Controles:

- P1: `V`;
- P2: `Num 7`.

## Desarmamento e slots

Quando uma arma é derrubada:

- apenas o slot correspondente fica indisponível;
- o lutador pode trocar para outro slot preservado;
- recuperar a própria arma restaura o slot original;
- coletar uma arma adversária ocupa o slot de espólio;
- todos os slots originais retornam no reinício da rodada.

Não existe perda persistente de inventário.

## Builds do protótipo

### Bastão Adaptativo

- principal: Bastão Adaptativo;
- secundária: Faixas do Vento.

### Fluxo Aéreo

- principal: Faixas do Vento;
- secundária: Bastão Adaptativo.

### Rocha Guardiã

- principal: Manoplas Sísmicas;
- secundária: Bastão Adaptativo.

### Quebra-Fundação

- principal: Manoplas Quebra-Fundação;
- secundária: Manoplas Sísmicas.

## Domínio de arma

O domínio é persistente e separado por perfil e arma.

Estágios:

1. Desconhecida;
2. Familiar;
3. Treinada;
4. Proficiente;
5. Dominada;
6. Lendária.

O domínio recebe experiência por:

- iniciar uma técnica pertencente ao kit;
- acertar;
- atingir uma defesa;
- sofrer aparo ou evasão;
- aparar com a arma equipada;
- trocar de arma;
- acertar logo após uma troca;
- sofrer desarmamento.

Magias, agarrões genéricos e ações que não pertencem ao kit não aumentam domínio da arma.

## Adaptação após troca

Depois de trocar, o lutador possui uma janela de 2,6 segundos para acertar ou atingir a defesa adversária.

Quando consegue, registra um evento de adaptação e recebe experiência adicional.

Essa regra recompensa a troca usada com intenção, não a alternância repetitiva fora de contexto.

## Persistência

O arquivo é salvo ao final de cada rodada e ao fechar a cena:

```text
user://weapon_mastery.json
```

O registro inclui:

- XP;
- estágio;
- usos;
- acertos;
- contatos bloqueados;
- contatos aparados;
- contatos evadidos;
- aparos;
- trocas;
- acertos adaptativos;
- desarmamentos sofridos.

## Bot

O P2 controlado pela IA também utiliza a arma secundária.

A decisão considera:

- distância atual;
- alcance preferencial dos dois kits;
- personalidade do bot;
- disponibilidade dos slots;
- estado de combate;
- custo e janela de recuperação.

Perfis agressivos favorecem kits curtos. Guardiões preservam mais distância. Técnicos escolhem o kit mais coerente com o alcance, e Caóticos podem variar com maior frequência.

## Princípio de balanceamento

O domínio ainda não concede bônus oculto de dano, vida ou defesa.

Nesta etapa ele funciona como registro de experiência real e base para a futura integração com:

- mestres;
- treinamentos;
- variações de técnica;
- redução explícita de custo;
- manutenção e personalização de armas.

## Validação no Godot 4.3+

1. confirmar importação sem erros;
2. testar `V` e `Num 7`;
3. confirmar custo de fôlego;
4. confirmar recuperação vulnerável;
5. validar mudança imediata de kit;
6. desarmar a principal e trocar para a secundária;
7. recuperar a arma original;
8. coletar arma adversária como espólio;
9. percorrer os três slots;
10. reiniciar a rodada e restaurar o loadout;
11. verificar progressão separada por arma;
12. confirmar que magia não gera domínio;
13. validar acerto adaptativo após troca;
14. verificar o JSON persistido;
15. testar a troca automática do bot.

---

**Tehkné Solutions**