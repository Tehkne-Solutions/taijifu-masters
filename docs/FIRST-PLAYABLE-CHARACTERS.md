# First Playable — personagens iniciais

## Escopo da Sprint 02

Esta sprint coloca dois personagens nomeados e distintos dentro da vertical slice sem depender de geração visual instável ou de assets ainda não aprovados.

## P1 — Lian Wu

```text
Preset: lian_wu_first_playable
Personagem: Lian Wu
Título: Lâmina Serena
Elemento: Água
Arma principal: Katana Serena
Arma secundária: Mãos livres
Perfil: técnico, focado, ágil e equilibrado
Render atual: procedural exclusivo
```

A `Katana Serena` usa temporariamente técnicas genéricas já validadas pelo núcleo de combate. Golpes exclusivos de katana e sprites finais serão adicionados sobre o mesmo `weapon_id` e o mesmo preset, sem alterar o contrato de gameplay.

## CPU — Rival de Treino

```text
Preset: training_rival_first_playable
Personagem: Rival de Treino
Título: Punho da Fornalha
Elemento: Fogo
Arma principal: Manoplas Quebra-Fundação
Arma secundária: Mãos livres
Perfil: força, resistência, pressão frontal e dano de postura
Render atual: procedural exclusivo
```

## Identidade procedural

Os dois personagens são registrados no `CharacterVisualCatalog` com:

```text
render_mode = procedural
sheet = ""
```

Isso impede que IDs novos herdem acidentalmente o atlas de Kael.

Cada lutador recebe `FirstPlayableIdentity`, que desenha detalhes exclusivos sobre a silhueta procedural existente:

- Lian Wu: casaco branco, lapelas e faixa azuis, ferragens douradas, katana única e assinatura de água;
- Rival: armadura escura, ombreira metálica, cinto de latão, manoplas grandes e pulso de fogo.

## Separação do protótipo completo

Os presets existentes do protótipo completo continuam sendo exatamente seis. Os dois novos presets estão disponíveis apenas por:

```gdscript
BuildProfile.first_playable_presets()
```

Eles não entram automaticamente em menus, preparação, progressão, cosméticos ou torneios.

## Testes

```text
FIRST_PLAYABLE_CHARACTER_CONTRACT_OK
FIRST_PLAYABLE_SMOKE_OK
FIRST_PLAYABLE_MATCH_CYCLE_OK
```

Os testes verificam:

- IDs e nomes corretos;
- elementos e armas corretos;
- diferenças de atributos;
- kit provisório da katana completo;
- modo procedural explícito;
- ausência de atlas herdado;
- presença do overlay de identidade;
- manutenção dos seis presets do protótipo completo;
- combate, KO, revanche e timeout.

## Pendência artística controlada

A Sprint 02 não afirma que os sprites finais estejam prontos. O estado correto é:

```text
Gameplay dos personagens: funcional
Identidade visual procedural: funcional
Sprites comic/manga finais: pendentes
Animações finais: pendentes
```

Assinatura: Tehkné Solutions
