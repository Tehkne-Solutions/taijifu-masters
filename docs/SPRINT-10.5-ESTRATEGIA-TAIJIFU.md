# Sprint 10.5 — Estratégia de Batalha e Integração Taijifu

## Objetivo

Entregar o primeiro Protótipo Zero de **Taijifu Masters**, validando movimento, combate local, builds estratégicas, índices Tai/Ji/Fu e a arena vertical/lateral Ruínas do Caminho Triplo.

## Correção conceitual oficial

- **Tai:** distância longa, predominância de pernas, alcance, entradas e perseguição.
- **Ji:** curta distância, contato, controle, agarrões, quedas e luta próxima.
- **Fu:** fluidez, adaptação, transições, esquivas, ângulos e uso do ambiente.

Os índices Tai/Ji/Fu são derivados dos atributos da build e não substituem a habilidade do jogador.

## Escopo implementado nesta fundação

- Projeto Godot 4 inicializado.
- Dois lutadores locais provisórios.
- Atributos: força, defesa, agilidade, resistência, técnica, controle, percepção e foco.
- Índices derivados Tai, Ji e Fu.
- Presets Bastão Adaptativo e Rocha Guardiã.
- Movimento horizontal, salto variável, coyote time, buffer de salto, queda rápida e esquiva.
- Vida, postura e fôlego.
- Golpe leve, empurrão provisório, defesa e knockback.
- Arena com rotas Tai, Ji e Fu.
- Plataforma móvel.
- Manifestações do Fluxo contestáveis.
- Câmera dinâmica para dois jogadores.
- HUD técnico do protótipo.

## Rotas da arena

### Rota superior — Tai

Espaços abertos, plataformas distantes, saltos e risco de queda.

### Rota inferior — Ji

Corredores, paredes, curta distância e controle de posição.

### Rota central — Fu

Plataformas de transição, mudanças de altura e manifestações.

## Próximas entregas

1. Separar golpes em dados externos.
2. Implementar hitboxes por fase e regiões de hurtbox.
3. Diferenciar golpe, empurrão e agarrão.
4. Adicionar wall jump, ledge grab e recuperação aérea.
5. Criar tela de preparo de batalha.
6. Implementar slots Tai/Ji/Fu.
7. Adicionar quatro elementos básicos.
8. Implementar desarmamento e espólio temporário.
9. Criar Observação Marcial.
10. Adicionar fechamento lateral dos setores.

## Critérios de validação do Protótipo Zero

- Dois jogadores conseguem jogar localmente.
- Movimento responde sem estados presos.
- Builds apresentam velocidade, postura e índices distintos.
- As três rotas oferecem vantagens situacionais diferentes.
- Manifestações geram disputa territorial.
- Perder uma rodada possui causa compreensível.
- O protótipo reinicia rapidamente.

## Fora do escopo atual

- Arte final.
- Multiplayer online.
- Campanha.
- Inventário persistente.
- Perda permanente de itens.
- Pets completos.
- Ranking e matchmaking.

---

**Tehkné Solutions**
