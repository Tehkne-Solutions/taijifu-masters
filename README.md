# Taijifu Masters

Jogo de luta e plataforma 2D baseado no sistema Taijifu, com combate técnico, preparação estratégica de builds, domínio Tai/Ji/Fu, elementos interativos e arenas móveis.

## Estado

O repositório contém a primeira fundação executável do **Protótipo Zero — Ruínas do Caminho Triplo**.

Esta etapa valida:

- dois jogadores locais;
- movimento e salto variável;
- esquiva, defesa, golpe e empurrão provisórios;
- vida, postura e fôlego;
- builds com atributos diferentes;
- índices Tai, Ji e Fu;
- arena horizontal e vertical;
- rotas estratégicas;
- plataforma móvel;
- Manifestações do Fluxo disputáveis;
- câmera dinâmica e reinício de rodada.

## Tecnologia

- Godot 4.3+
- GDScript
- Simulação a 60 Hz
- Primeiro alvo: Windows e Linux

## Executar

1. Clone o repositório.
2. Abra a pasta no Godot 4.3 ou superior.
3. Importe o projeto.
4. Execute o projeto com **F6/F5**.

## Controles

### Jogador 1 — Kael / Bastão Adaptativo

- `A` / `D`: mover;
- `W`: saltar;
- `S`: queda rápida;
- `Q`: esquiva;
- `F`: golpe;
- `G`: empurrão provisório;
- `R`: defender.

### Jogador 2 — Nara / Rocha Guardiã

- setas esquerda/direita: mover;
- seta para cima: saltar;
- seta para baixo: queda rápida;
- `Num 0`: esquiva;
- `Num 1`: golpe;
- `Num 2`: empurrão provisório;
- `Num 3`: defender.

## Tai, Ji e Fu

- **Tai:** distância longa, pernas, alcance, entradas e perseguição.
- **Ji:** curta distância, contato, controle, agarrões e quedas.
- **Fu:** adaptação, transição, esquiva, mudança de rota e uso do ambiente.

## Princípios do protótipo

- Técnica e leitura permanecem decisivas.
- Builds mudam possibilidades, não garantem vitória.
- Atributos devem alterar comportamento, não apenas números.
- Itens da arena geram disputa territorial, não vantagem gratuita.
- Espólios são temporários no núcleo competitivo.
- A arte permanece provisória até a validação da jogabilidade.

## Documentação

- [`docs/SPRINT-10.5-ESTRATEGIA-TAIJIFU.md`](docs/SPRINT-10.5-ESTRATEGIA-TAIJIFU.md)
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

## Próxima implementação

- técnicas externas classificadas como Tai/Ji/Fu;
- hitboxes por fase;
- agarrões e lançamentos;
- wall jump e recuperação aérea;
- tela de preparação;
- elementos;
- desarmamento;
- espólio temporário;
- Observação Marcial;
- fechamento lateral da arena.

---

**Tehkné Solutions**
