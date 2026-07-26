# Arquitetura inicial

## Estrutura

```text
.
├── project.godot
├── scenes/
│   ├── main.tscn
│   └── fighter/
│       └── fighter.tscn
├── scripts/
│   ├── main.gd
│   ├── arena/
│   │   └── triple_path_arena.gd
│   ├── core/
│   │   └── build_profile.gd
│   └── fighter/
│       └── fighter_controller.gd
└── docs/
```

## Responsabilidades

### `BuildProfile`

Mantém os oito atributos primários, calcula Tai/Ji/Fu e deriva valores provisórios de movimento, vitalidade, postura, dano e knockback.

### `FighterController`

Executa entrada local, movimento, recursos e o primeiro contato ofensivo. Nesta fase, lógica e apresentação ainda convivem no mesmo script para acelerar a validação. A separação em máquina de estados, CombatController, DefenseController e AbilityController será feita após confirmar a sensação do núcleo.

### `TriplePathArena`

Cria o blockout em tempo de execução, organiza rotas Tai/Ji/Fu, movimenta uma plataforma e administra as primeiras Manifestações do Fluxo.

### `Main`

Registra entradas provisórias, cria jogadores, acompanha a luta com câmera dinâmica, apresenta HUD e reinicia rodadas.

## Decisões

- O primeiro build é local e usa placeholders vetoriais.
- A simulação roda a 60 Hz.
- Atributos afetam comportamento, não apenas dano.
- As Manifestações aparecem somente em posições conhecidas e contestáveis.
- O espólio permanente não faz parte do núcleo competitivo.
- O conteúdo será migrado para Resources externos antes da expansão em escala.

## Próxima refatoração técnica

```text
FighterController
├── FighterStateMachine
├── MovementController
├── CombatController
├── DefenseController
├── ResourceController
├── EquipmentController
└── AbilityController
```

Também serão introduzidos:

- `AttackData`;
- `TechniqueData` com classificação Tai/Ji/Fu;
- `ElementData`;
- `BuildData`;
- `ManifestationData`;
- eventos desacoplados para HUD, áudio e câmera.

## Execução

1. Abrir a pasta no Godot 4.3 ou superior.
2. Importar o projeto.
3. Executar `scenes/main.tscn` ou pressionar **F6/F5**.
4. Utilizar os controles descritos no README.

---

**Tehkné Solutions**
