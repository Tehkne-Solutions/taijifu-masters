# Presets, histórico e identidade das Ruínas

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Esta entrega adiciona continuidade entre sessões de jogo:

- builds podem ser salvas com nomes próprios;
- presets podem ser exportados e importados;
- séries competitivas geram histórico e estatísticas;
- o resultado final apresenta métricas do confronto;
- as Ruínas do Caminho Triplo recebem uma primeira identidade visual animada.

---

# Biblioteca de presets

## Abrir

```text
F2
```

A biblioteca funciona durante a preparação.

## Controles

```text
TAB       alternar P1/P2
↑/↓       selecionar preset
ENTER     carregar
F4        salvar novo
F5        sobrescrever selecionado
N         renomear
DELETE    excluir
F7        exportar
F1        importar da caixa de entrada
F2        fechar
```

Cada perfil possui até 12 presets.

## Conteúdo salvo

Um preset inclui:

- personagem;
- build;
- elemento;
- arma principal;
- arma secundária;
- variante de mestre;
- acessório;
- item de costas;
- amuleto;
- pet;
- arena;
- formato da série;
- tempo;
- modificador competitivo.

## Persistência

```text
user://loadout_presets.json
```

## Exportação

Arquivos exportados são gravados em:

```text
user://exports/
```

Formato:

```text
<nome>-<id>.taijifu.json
```

O arquivo contém a assinatura:

```text
TAIJIFU_LOADOUT_PRESET
```

Isso impede que um JSON genérico seja aceito como preset.

## Importação

O arquivo recebido deve ser colocado em:

```text
user://imports/loadout.taijifu.json
```

Depois, pressione `F1` dentro da biblioteca.

O importador:

1. valida a assinatura;
2. valida a estrutura;
3. sanitiza personagem e armas;
4. remove variantes ainda não desbloqueadas;
5. valida os cosméticos;
6. valida regras competitivas;
7. cria uma cópia marcada como importada.

---

# Histórico local

## Abrir

```text
F3
```

O painel é acessível durante a preparação.

## Persistência

```text
user://match_history.json
```

As últimas 100 séries são mantidas.

## Dados por série

- identificador;
- início e conclusão;
- arena e regras;
- jogadores e loadouts;
- campeão;
- placar;
- rounds;
- duração;
- estatísticas totais.

## Dados por round

- vencedor;
- motivo;
- duração;
- recursos restantes;
- contatos;
- acertos;
- dano causado;
- dano de postura;
- golpes bloqueados;
- contatos aparados;
- esquivas;
- aparos realizados;
- quebras de postura;
- desarmes;
- agarrões;
- interações elementais;
- espólios coletados.

## Agregações

O painel apresenta:

- total de séries;
- total de rounds;
- média de rounds por série;
- duração média;
- vitórias por lado;
- rounds por KO;
- rounds por tempo;
- prorrogações;
- dano acumulado;
- aparos acumulados;
- vitórias por personagem;
- uso de arenas.

---

# Relatório final da série

Depois que um jogador atinge a quantidade necessária de vitórias, o jogo mostra:

- campeão;
- placar final;
- configuração da partida;
- tabela P1 versus P2;
- dano;
- postura;
- acertos;
- aparos;
- quebras de postura;
- desarmes;
- agarrões;
- interações elementais;
- resultado e duração de cada round.

O relatório é salvo antes do retorno à preparação.

---

# Ruínas do Caminho Triplo

A arena recebeu uma camada visual procedural, independente das colisões.

## Elementos visuais

- lua ritual pulsante;
- anéis orbitais;
- três camadas de montanhas em tinta;
- nuvens animadas em velocidades diferentes;
- três cascatas;
- dojos distantes;
- cinco bandeiras com oscilação;
- glifos Tai, Ji e Fu;
- lanternas;
- linhas comic nas laterais;
- intensificação visual durante o fechamento.

## Segurança competitiva

A camada artística:

- não possui colisão;
- não modifica plataformas;
- não altera spawns;
- não altera a câmera;
- não altera hitboxes;
- não altera dano;
- não altera o tempo da arena;
- fica abaixo dos sprites dos personagens.

O blockout competitivo continua sendo a fonte da geometria.

## Comportamento por arena

A camada completa aparece apenas quando a arena selecionada é:

```text
triple_ruins
```

Santuário e Crisol continuam utilizando a representação provisória até receberem suas cenas artísticas próprias.

---

# Arquitetura

```text
scripts/presets/loadout_preset_ledger.gd
scripts/history/match_history_ledger.gd
scripts/runtime/loadout_preset_runtime.gd
scripts/runtime/series_statistics_runtime.gd
scripts/runtime/match_history_runtime.gd
scripts/arena/triple_path_environment_art.gd
```

Integrações:

```text
scripts/competitive_main.gd
scripts/runtime/competitive_arena_runtime.gd
scenes/main.tscn
```

---

# Validação manual

1. salvar presets para P1 e P2;
2. renomear;
3. sobrescrever;
4. exportar;
5. copiar o arquivo para a caixa de entrada;
6. importar;
7. aplicar o preset;
8. concluir uma série por KO;
9. concluir uma série por tempo;
10. abrir o histórico;
11. conferir estatísticas;
12. reiniciar o jogo e validar persistência;
13. selecionar Ruínas;
14. observar lua, nuvens e cascatas;
15. confirmar intensificação no fechamento;
16. selecionar outra arena e confirmar que a arte específica é ocultada.

---

# Próximas etapas

- cenas artísticas do Santuário e do Crisol;
- código compacto de compartilhamento;
- perfis com nomes de jogadores;
- replay resumido de rounds;
- histórico filtrável;
- comparação entre presets;
- modo torneio.

---

**Tehkné Solutions**
