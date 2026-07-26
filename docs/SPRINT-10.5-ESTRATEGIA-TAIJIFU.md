# Sprint 10.5 — Estratégia de Batalha e Integração Taijifu

## Objetivo

Entregar o primeiro Protótipo Zero de **Taijifu Masters**, validando movimento, combate local, builds estratégicas, índices Tai/Ji/Fu e a arena vertical/lateral Ruínas do Caminho Triplo.

## Correção conceitual oficial

- **Tai:** distância longa, predominância de pernas, alcance, entradas e perseguição.
- **Ji:** curta distância, contato, controle, agarrões, quedas e luta próxima.
- **Fu:** fluidez, adaptação, transições, esquivas, ângulos e uso do ambiente.

Os índices Tai/Ji/Fu são derivados dos atributos da build e não substituem a habilidade do jogador.

## Implementado

### Fundação

- Projeto Godot 4 inicializado.
- Dois lutadores locais provisórios.
- Atributos: força, defesa, agilidade, resistência, técnica, controle, percepção e foco.
- Índices derivados Tai, Ji e Fu.
- Vida, postura e fôlego.
- Câmera dinâmica e reinício rápido de rodada.

### Preparação de batalha

- Tela de preparação antes do confronto.
- Quatro builds selecionáveis:
  - Bastão Adaptativo;
  - Fluxo Aéreo;
  - Rocha Guardiã;
  - Quebra-Fundação.
- Resumo tático por build.
- Técnicas preparadas em slots Tai, Ji e Fu.
- Peso, atributos e especialização alterando movimento, resistência e impacto.

### Movimento

- Movimento horizontal com aceleração e desaceleração.
- Salto variável.
- Coyote time.
- Buffer de salto.
- Queda rápida.
- Esquiva terrestre.
- Recuperação aérea limitada a um uso por permanência no ar.
- Wall slide.
- Wall jump.

### Combate orientado a dados

- `TechniqueData` como recurso independente.
- Catálogo inicial de técnicas Tai, Ji e Fu.
- Fases de preparação, atividade e recuperação.
- Hitbox configurada por técnica.
- Custo de fôlego por técnica.
- Dano e dano de postura separados.
- Multiplicadores derivados do caminho da build.
- Seleção contextual:
  - corrida e ar favorecem Tai;
  - curta distância e varredura favorecem Ji;
  - builds adaptativas favorecem Fu.
- Defesa frontal.
- Janela de aparo perfeito.
- Recuo do atacante após aparo.
- Resistência de knockback derivada da build.

### Arena

- Rotas superiores Tai.
- Corredores inferiores Ji.
- Plataformas centrais Fu.
- Plataforma móvel.
- Manifestações do Fluxo contestáveis.
- Navegação horizontal e vertical.

## Técnicas iniciais

### Tai

- Passo Longo.
- Arco Ascendente.

### Ji

- Gancho de Centro.
- Varredura de Base.
- Empurrão de Fundação.

### Fu

- Golpe de Transição.
- Reversão do Fluxo.

## Próximas entregas

1. Criar regiões de hurtbox.
2. Diferenciar empurrão, agarrão e lançamento.
3. Adicionar ledge grab.
4. Implementar quatro elementos básicos.
5. Criar vantagens e consequências ambientais dos elementos.
6. Implementar desarmamento e espólio temporário.
7. Criar Observação Marcial.
8. Adicionar fechamento lateral dos setores.
9. Externalizar técnicas para arquivos `.tres` após validação do catálogo.
10. Integrar animações e eventos visuais às fases lógicas.

## Critérios de validação do Protótipo Zero

- Dois jogadores conseguem jogar localmente.
- A preparação de batalha altera perceptivelmente o comportamento.
- Movimento responde sem estados presos.
- Wall jump e recuperação aérea não garantem retorno infinito.
- Tai, Ji e Fu produzem alcances e riscos diferentes.
- A defesa não substitui aparo e movimentação.
- Técnicas apresentam preparação e recuperação puníveis.
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
