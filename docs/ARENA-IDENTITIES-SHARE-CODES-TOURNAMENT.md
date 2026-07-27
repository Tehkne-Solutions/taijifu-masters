# Identidades de arena, códigos compactos e torneio local

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Esta entrega completa a primeira identidade visual das três arenas competitivas, adiciona compartilhamento compacto de loadouts e introduz um torneio local eliminatório para quatro competidores.

---

## Santuário das Quatro Correntes

Identidade visual:

- quatro portais de corrente;
- ilhas flutuantes com pavilhões;
- fitas de água atravessando o cenário;
- nuvens em terraços;
- carpas celestiais;
- lanternas de lótus;
- paleta turquesa, água e jade.

A apresentação reforça:

- liberdade de movimento;
- manifestações frequentes;
- estabilidade territorial;
- tendência Tai.

Arquivo:

```text
scripts/arena/sanctuary_environment_art.gd
```

---

## Crisol das Cinzas

Identidade visual:

- céu de cinzas;
- cordilheiras negras;
- torres-forja;
- canais de lava;
- correntes suspensas;
- respiradouros de brasas;
- tempestade de partículas;
- linhas comic mais agressivas.

A apresentação reforça:

- fechamento acelerado;
- pressão territorial;
- contato direto;
- tendência Ji.

Arquivo:

```text
scripts/arena/crucible_environment_art.gd
```

---

## Separação competitiva

As três identidades visuais são `Node2D` independentes e não possuem:

- colisão;
- hitbox;
- navegação;
- modificação de plataforma;
- influência sobre spawn;
- cálculo de dano;
- alteração de câmera.

O `CompetitiveArenaRuntime` ativa apenas a identidade correspondente à arena selecionada.

---

## Códigos compactos de compartilhamento

Formato:

```text
TJF1.<tamanho>.<conteúdo compactado>.<checksum>
```

O código carrega:

- nome do preset;
- personagem e build;
- elemento;
- armas;
- variante;
- cosméticos;
- arena;
- formato da série;
- tempo;
- modificador.

### Integridade

O formato utiliza:

- JSON sanitizado;
- compactação Deflate;
- Base64 seguro para URL;
- tamanho original em base 36;
- checksum SHA-256 reduzido.

Códigos adulterados ou truncados são rejeitados.

### Controles na preparação

```text
K                 alternar destino P1/P2
Ctrl+Shift+C      copiar código atual
Ctrl+Shift+V      importar código da área de transferência
```

Arquivos:

```text
scripts/presets/loadout_share_code.gd
scripts/runtime/loadout_share_code_runtime.gd
```

---

## Torneio local

Primeira versão:

```text
4 competidores
→ Semifinal A
→ Semifinal B
→ Final
→ Campeão
```

Os participantes podem vir de:

- loadout atual do P1;
- loadout atual do P2;
- presets salvos de qualquer jogador;
- convidados padrão quando não existem presets suficientes.

### Controles

```text
F10          abrir ou fechar
Page Up/Down selecionar competidor
Home/End     trocar fonte do competidor
Enter        iniciar
Delete       reiniciar torneio
```

### Fluxo

1. O host monta quatro competidores.
2. O torneio inicia na Semifinal A.
3. Os dois loadouts são aplicados à preparação.
4. Os jogadores confirmam a partida normalmente.
5. O campeão da série avança automaticamente.
6. A Semifinal B é preparada.
7. Os dois vencedores disputam a Final.
8. O campeão permanece registrado no chaveamento.

### Persistência

```text
user://tournament_state.json
```

O arquivo guarda:

- quatro participantes;
- estágio atual;
- vencedores das semifinais;
- campeão;
- estado ativo ou concluído.

Arquivos:

```text
scripts/tournament/tournament_ledger.gd
scripts/runtime/tournament_runtime.gd
```

---

## Integração da série

O controlador competitivo notifica o torneio somente quando uma série completa termina.

Rounds individuais não alteram o chaveamento.

Ao concluir uma semifinal:

- o vencedor avança;
- o jogo retorna à preparação;
- o próximo confronto é aplicado;
- ambos os competidores precisam confirmar novamente.

Ao concluir a Final:

- o campeão é persistido;
- o torneio é encerrado;
- a preparação volta ao modo normal.

---

## Validação automatizada

O novo gate testa:

- round-trip de código compacto;
- rejeição de código corrompido;
- preservação de build e arena;
- quatro participantes;
- duas semifinais;
- formação da final;
- campeão correto;
- assinatura visual das três arenas;
- ausência de mudanças competitivas;
- ativação correta de Santuário e Crisol;
- integração dos novos runtimes na cena.

---

## Limites atuais

O modo torneio é local e eliminatório para quatro competidores.

Ainda não inclui:

- oito ou dezesseis participantes;
- fase de grupos;
- dupla eliminação;
- nomes digitados manualmente por slot;
- rede ou matchmaking;
- transmissão e overlays externos;
- seeds automáticos;
- replay da chave.

A próxima evolução deverá adicionar bracket para oito participantes, filtros avançados do histórico e replay resumido das séries.

---

**Tehkné Solutions**
