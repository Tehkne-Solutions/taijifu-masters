# Preparação Completa de Batalha

**Produto desenvolvido por Tehkné Solutions**

## Objetivo

Esta entrega substitui a preparação textual por uma tela completa de loadout para dois jogadores. A estratégia passa a ser definida antes do primeiro golpe, reunindo personagem, build, elemento, armas, variante de mestre e cosméticos.

---

## Categorias

Cada jogador configura dez categorias:

1. personagem;
2. build;
3. elemento;
4. arma principal;
5. arma secundária;
6. variante de mestre;
7. acessório de cabeça;
8. item de costas;
9. amuleto;
10. pet.

## Personagens e builds

### Kael

- Bastão Adaptativo;
- Fluxo Aéreo.

### Nara

- Rocha Guardiã;
- Quebra-Fundação.

### Lyra

- Tecelã da Corrente.

### Rin

- Chama Rival.

A troca de personagem filtra automaticamente as builds compatíveis.

## Elementos

- fogo;
- água;
- terra;
- ar.

O elemento pode ser escolhido independentemente do padrão original da build.

## Armas

Opções disponíveis:

- Bastão Adaptativo;
- Faixas do Vento;
- Manoplas Sísmicas;
- Manoplas Quebra-Fundação;
- Mãos Livres.

A arma secundária não pode ser idêntica à principal. Quando uma combinação inválida é carregada, o catálogo aplica uma alternativa segura.

## Variantes de mestre

A tela mostra apenas variantes que:

1. foram desbloqueadas pelo perfil;
2. são compatíveis com a arma principal escolhida.

Exemplos:

- Círculo das Três Correntes — Bastão;
- Fundação Invertida — Manoplas;
- Asa Cruzada — Faixas do Vento.

A opção `SEM VARIANTE` permanece sempre disponível.

## Cosméticos

A preparação utiliza o mesmo catálogo dos sockets existentes:

- cabeça;
- costas;
- peito;
- pet.

As escolhas são gravadas no `CosmeticLoadoutLedger` e carregadas pelo personagem durante o spawn.

---

## Controles

### Jogador 1

```text
W / S   trocar categoria
A / D   trocar opção
1       restaurar padrão
```

### Jogador 2

```text
↑ / ↓   trocar categoria
← / →   trocar opção
2       restaurar padrão
```

### Geral

```text
Enter   iniciar batalha
```

---

## Interface

A tela possui dois painéis paralelos.

Cada painel mostra:

- nome do personagem;
- função;
- prévia real do atlas;
- categoria selecionada;
- valores do loadout;
- índices Tai, Ji e Fu;
- vida e postura estimadas;
- resumo tático da build;
- armas escolhidas;
- descrição da variante.

A prévia utiliza o primeiro quadro de idle do atlas animado do personagem.

---

## Persistência

Novo arquivo:

```text
user://battle_preparation.json
```

Ele registra os loadouts completos de P1 e P2.

A tela também sincroniza:

```text
user://master_training.json
user://cosmetic_loadout.json
```

Assim, a variante e os cosméticos continuam compatíveis com os sistemas anteriores.

## Ordem de sanitização

Ao carregar ou alterar um loadout:

1. valida personagem;
2. valida build compatível;
3. valida elemento;
4. valida armas;
5. impede armas duplicadas;
6. filtra variante pela arma e desbloqueio;
7. valida cada item cosmético;
8. substitui valores inválidos por padrões seguros.

---

## Aplicação no spawn

Ao pressionar `Enter`:

1. os três ledgers são salvos;
2. a tela é ocultada;
3. a arena inicia seu fluxo;
4. o lutador é instanciado com o preset escolhido;
5. o elemento substitui o padrão da build;
6. o kit principal/secundário é configurado;
7. as variantes desbloqueadas são mapeadas;
8. a variante selecionada é aplicada;
9. os cosméticos são carregados pelo presenter.

A build continua sendo a fonte dos atributos. As escolhas de loadout não duplicam o sistema de progressão.

---

## Arquitetura

```text
scripts/preparation/battle_loadout_catalog.gd
scripts/preparation/battle_loadout_ledger.gd
scripts/runtime/battle_preparation_runtime.gd
scripts/main.gd
scenes/main.tscn
scripts/ci/smoke_test.gd
```

### BattleLoadoutCatalog

- personagens e builds;
- categorias;
- opções;
- rótulos;
- compatibilidade;
- sanitização.

### BattleLoadoutLedger

- persistência de P1/P2;
- restauração segura;
- padrões iniciais.

### BattlePreparationRuntime

- interface;
- controles;
- prévias;
- atualização em tempo real;
- sincronização dos ledgers;
- sinal de início da batalha.

---

## Validação automatizada

O smoke test valida:

1. três novos scripts;
2. dez categorias;
3. quatro personagens;
4. seis builds;
5. filtro de variantes por arma;
6. sanitização;
7. persistência em memória;
8. integração da cena;
9. criação dos lutadores;
10. aplicação de personagem e elemento;
11. aplicação do kit de armas;
12. preservação dos testes anteriores.

---

## Validação manual

1. trocar personagem de P1 e P2;
2. conferir filtro de builds;
3. testar os quatro elementos;
4. testar armas principal e secundária;
5. confirmar bloqueio de duplicidade;
6. verificar variantes liberadas;
7. trocar os quatro sockets cosméticos;
8. iniciar a luta;
9. conferir HUD e arma equipada;
10. reiniciar o jogo e confirmar persistência.

---

## Próxima etapa

- prévia cosmética completa dentro da preparação;
- animação de entrada na arena;
- confirmação individual de prontidão;
- suporte a controle/gamepad;
- regras de banimento para partidas competitivas;
- presets nomeáveis e exportáveis;
- seleção de arena e modificadores de partida.

---

**Tehkné Solutions**
