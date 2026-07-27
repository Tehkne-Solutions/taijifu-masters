# Torneio de oito, replay resumido e histórico filtrável

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Esta etapa amplia o modo competitivo local em três direções:

1. chaveamento eliminatório para quatro ou oito competidores;
2. replay narrativo dos momentos decisivos de cada série;
3. filtros avançados sobre o histórico local.

---

## Torneios de quatro e oito

O painel de torneio continua acessível por:

```text
F10
```

Novo controle:

```text
T — alternar entre 4 e 8 competidores
```

O formato fica bloqueado enquanto um torneio está ativo.

### Quatro competidores

```text
Seed 1 × Seed 4
Seed 2 × Seed 3
→ Final
```

### Oito competidores

```text
Seed 1 × Seed 8
Seed 4 × Seed 5
Seed 2 × Seed 7
Seed 3 × Seed 6
→ Semifinais
→ Final
```

O sistema mantém os seeds do início ao fim do chaveamento.

### Controles

```text
F10           abrir ou fechar
T             alternar formato 4/8
Page Up/Down  selecionar seed
Home/End      trocar a fonte do competidor
Enter         iniciar torneio
Delete        reiniciar
```

### Persistência

```text
user://tournament_state.json
```

A versão 2 do arquivo mantém:

- formato do torneio;
- participantes e seeds;
- todos os confrontos;
- vencedor de cada confronto;
- rodada e partida atuais;
- campeão final.

---

## Replay resumido

O jogo não grava vídeo. Em vez disso, registra uma linha do tempo compacta dos eventos técnicos mais importantes.

Eventos registrados:

- golpes com dano ou pressão de postura elevados;
- aparos;
- quebras de postura;
- desarmes;
- agarrões;
- interações elementais;
- coleta de loot.

Cada evento contém:

```text
tempo dentro do round
jogador responsável
tipo de evento
descrição
valor técnico opcional
```

O limite é de 24 destaques por round para impedir crescimento excessivo do arquivo local.

### Estrutura do replay

```text
Abertura da série
→ Round 1 e seus destaques
→ Round 2 e seus destaques
→ rounds adicionais
→ resumo estatístico final
```

Controles:

```text
Espaço — avançar card
Esc    — fechar replay
```

Arquivo:

```text
scripts/runtime/series_replay_runtime.gd
```

---

## Histórico filtrável

O histórico continua acessível com:

```text
F3
```

Filtros disponíveis:

### Personagem

- todos;
- Kael;
- Nara;
- Lyra;
- Rin.

### Arena

- todas;
- Ruínas do Caminho Triplo;
- Santuário das Quatro Correntes;
- Crisol das Cinzas.

### Resultado

- todos;
- vitória do P1;
- vitória do P2;
- série com KO;
- série decidida por tempo;
- série com prorrogação.

### Controles

```text
F3             abrir ou fechar
Tab            trocar campo de filtro
H / Y          trocar valor
Page Up/Down   selecionar série
Enter          reproduzir replay resumido
Backspace      limpar filtros
```

As estatísticas gerais passam a respeitar os filtros selecionados.

Exemplo:

```text
Personagem: Kael
Arena: Crisol das Cinzas
Resultado: Vitória P2
```

O painel apresenta somente séries que atendem simultaneamente aos três critérios.

---

## Arquitetura

### Torneio

```text
scripts/tournament/tournament_ledger.gd
scripts/runtime/tournament_runtime.gd
```

### Replay

```text
scripts/runtime/series_statistics_runtime.gd
scripts/runtime/series_replay_runtime.gd
```

### Histórico

```text
scripts/history/match_history_ledger.gd
scripts/runtime/match_history_runtime.gd
```

### Cena

```text
scenes/main.tscn
```

---

## Separação de responsabilidades

O torneio controla apenas o chaveamento entre séries completas.

O replay lê os eventos já registrados e não executa novamente a física da luta.

O histórico filtra registros persistidos e não altera resultados, progressão ou estatísticas originais.

Nenhum desses sistemas modifica:

- hitboxes;
- dano;
- postura;
- velocidade;
- arena;
- regras competitivas;
- IA;
- progressão do jogador.

---

## Validação automatizada

O novo gate do Godot CI verifica:

- início de torneio com oito participantes;
- pareamento inicial Seed 1 × Seed 8;
- quatro quartas de final;
- duas semifinais;
- final;
- sete confrontos totais;
- preservação do seed campeão;
- filtro por personagem;
- filtro por arena;
- filtro por vencedor;
- filtro por prorrogação;
- agregação filtrada;
- criação dos cards de replay;
- preservação de destaques;
- integração dos novos runtimes na cena principal.

---

## Próxima evolução

- nomes editáveis por seed;
- embaralhamento e sorteio automático;
- fase de grupos;
- dupla eliminação;
- exportação do chaveamento;
- replay com posições simplificadas dos lutadores;
- comparação entre duas séries;
- favoritos e tags no histórico;
- ranking local baseado em desempenho.

---

**Tehkné Solutions**
