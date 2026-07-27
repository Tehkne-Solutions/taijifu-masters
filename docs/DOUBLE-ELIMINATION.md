# Dupla eliminação

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Adicionar um formato competitivo em que cada participante precisa perder duas séries para ser eliminado.

A primeira derrota envia o competidor para a chave inferior. A segunda encerra sua participação.

O modo funciona de forma independente dos sistemas existentes:

```text
F10 — mata-mata simples
F11 — fase de grupos
F12 — dupla eliminação
```

---

## Acesso

```text
F12
```

Controles:

```text
T               alternar entre 4 e 8 competidores
Page Up/Down    selecionar seed
Home/End        trocar perfil, preset ou convidado
Ctrl+S          sortear os seeds
Enter           iniciar
Delete          reiniciar
F12             fechar
```

O modo só pode ser iniciado na tela de preparação.

---

## Persistência

O estado é salvo em:

```text
user://double_elimination_state.json
```

São preservados:

- formato de quatro ou oito participantes;
- seeds;
- perfis;
- nomes;
- loadouts;
- confrontos concluídos;
- placares;
- vencedores e perdedores;
- quantidade de derrotas;
- competidores eliminados;
- confronto atual;
- necessidade de reset da final;
- campeão e vice-campeão.

O torneio pode ser retomado depois que o jogo for fechado.

---

# Regras competitivas

## Duas vidas

Cada competidor começa com:

```text
0 derrotas — chave superior
```

Após a primeira derrota:

```text
1 derrota — chave inferior
```

Após a segunda derrota:

```text
2 derrotas — eliminado
```

A interface mostra permanentemente a situação de cada participante.

---

## Chave superior

A chave superior reúne os jogadores que ainda não perderam.

O vencedor da chave superior chega à Grande Final invicto e ainda possui uma vida competitiva adicional.

---

## Chave inferior

A chave inferior reúne participantes com uma derrota.

Qualquer nova derrota nessa chave elimina o participante.

O vencedor da chave inferior avança para enfrentar o campeão da chave superior.

---

# Formato com quatro competidores

Ordem dos confrontos:

```text
U1     semifinal superior 1 — seed 1 × seed 4
U2     semifinal superior 2 — seed 2 × seed 3
L1     eliminatória inferior — perdedor U1 × perdedor U2
UF     final superior — vencedor U1 × vencedor U2
LF     final inferior — vencedor L1 × perdedor UF
GF     Grande Final — vencedor UF × vencedor LF
RESET  confronto opcional
```

O torneio possui seis séries obrigatórias e uma sétima série opcional.

---

# Formato com oito competidores

## Primeira rodada superior

```text
UQ1 — seed 1 × seed 8
UQ2 — seed 4 × seed 5
UQ3 — seed 2 × seed 7
UQ4 — seed 3 × seed 6
```

## Primeira rodada inferior

```text
L1 — perdedor UQ1 × perdedor UQ2
L2 — perdedor UQ3 × perdedor UQ4
```

## Semifinais superiores

```text
US1 — vencedor UQ1 × vencedor UQ2
US2 — vencedor UQ3 × vencedor UQ4
```

## Segunda rodada inferior

Os cruzamentos evitam uma revanche imediata sempre que possível:

```text
L3 — vencedor L1 × perdedor US2
L4 — vencedor L2 × perdedor US1
```

## Finais

```text
UF — final da chave superior
LS — semifinal da chave inferior
LF — final da chave inferior
GF — Grande Final
RESET — confronto opcional
```

O torneio possui 14 séries obrigatórias e uma décima quinta série opcional.

---

# Grande Final e reset

A Grande Final recebe:

```text
P1 — campeão da chave superior
P2 — campeão da chave inferior
```

## Vitória do campeão superior

Quando o jogador invicto vence a primeira Grande Final:

- o adversário recebe sua segunda derrota;
- o torneio termina imediatamente;
- não existe reset.

## Vitória do campeão inferior

Quando o campeão da chave inferior vence:

- o campeão superior recebe sua primeira derrota;
- os dois finalistas passam a ter uma derrota;
- o confronto `RESET` é habilitado;
- a próxima série decide definitivamente o campeão.

O reset não é uma série extra arbitrária. Ele garante que os dois finalistas precisem perder duas vezes sob as mesmas regras.

---

# Integração com as batalhas

Quando o torneio está ativo:

1. o confronto atual fornece os dois loadouts;
2. os perfis são associados à série;
3. ambos os jogadores confirmam a preparação;
4. a série acontece com as regras competitivas configuradas;
5. o vencedor e o perdedor são registrados;
6. a derrota é contabilizada;
7. o competidor é enviado à chave inferior ou eliminado;
8. o próximo confronto é carregado automaticamente.

A temporada ativa continua sendo registrada pelo sistema existente.

---

# Identidade dos jogadores

Cada participante preserva:

```text
participant_id
profile_id
profile_name
name
seed
loadout
source
qualification
group_id
```

Isso impede que jogadores que utilizam o mesmo personagem sejam agrupados incorretamente.

---

# Arquitetura

```text
scripts/tournament/double_elimination_ledger.gd
scripts/runtime/double_elimination_runtime.gd
scripts/competitive_main.gd
scenes/main.tscn
scripts/ci/double_elimination_smoke_test.gd
.github/workflows/godot-ci.yml
```

---

# Validação automatizada

O gate dedicado verifica:

- formato de quatro competidores;
- formato de oito competidores;
- seed 1 × seed 8;
- movimentação para a chave inferior;
- eliminação após duas derrotas;
- seis séries obrigatórias no formato de quatro;
- 14 séries obrigatórias no formato de oito;
- vitória direta do invicto na Grande Final;
- ausência de reset indevido;
- ativação correta do reset;
- decisão do campeão no reset;
- campeão e vice-campeão;
- persistência das derrotas;
- preservação de `profile_id`;
- restauração do próximo confronto;
- integração do runtime à cena principal.

---

# Limites atuais

Esta versão é local.

Ainda não inclui:

- sincronização entre dispositivos;
- salas online;
- espectadores;
- seed automática pelo ranking da temporada;
- exportação visual específica da chave dupla;
- transmissão de resultados para servidor competitivo.

---

# Próximas evoluções

1. exportação SVG, PNG e JSON da chave dupla;
2. seed automática pelo ranking sazonal;
3. integração opcional da fase de grupos com dupla eliminação;
4. calendário competitivo;
5. matchmaking e ligas online;
6. sincronização de perfis e temporadas.

---

**Tehkné Solutions**
