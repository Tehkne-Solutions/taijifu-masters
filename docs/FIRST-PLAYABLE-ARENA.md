# First Playable — Ruínas do Caminho Triplo

## Objetivo

Transformar o blockout funcional da `TriplePathArena` em um cenário completo e legível para o primeiro nível testável, sem alterar a colisão e sem depender de imagens geradas.

## Arquitetura em camadas

```text
EnvironmentArt  z = -10  fundo e atmosfera
Arena           z =   0  colisão e blockout funcional
ArenaDressing   z =   1  ruínas e acabamento visual
Fighters                  gameplay e identidade
HUD                       interface fixa
```

## Fundo reutilizado

`FirstPlayableEnvironmentArt` adapta `TriplePathEnvironmentArt` e mantém:

- lua ritual animada;
- montanhas em nanquim;
- bandas de nuvens animadas;
- três dojos distantes;
- três cachoeiras;
- cinco bandeiras;
- três glifos de rota;
- lanternas;
- linhas de impacto comic/manga.

A única mudança estrutural é o `z_index = -10`, necessário porque os personagens da vertical slice ainda usam renderização procedural.

## Camada de ruínas

`FirstPlayableArenaDressing` adiciona:

- três camadas visuais no piso principal;
- acabamento em 15 plataformas estáticas;
- acabamento em três paredes;
- acabamento em duas plataformas móveis;
- dez colunas e arcos em ruínas;
- dois santuários de spawn;
- três beacons das rotas Tai, Ji e Fu;
- musgo, rachaduras, blocos, pedras e detritos;
- cores consistentes por rota:
  - Tai: azul;
  - Ji: vermelho;
  - Fu: violeta.

## Regra de segurança

A camada visual:

```text
não cria colisores
não move plataformas
não altera spawns
não muda pontos estratégicos
não modifica regras da IA
```

Toda a jogabilidade continua pertencendo a `TriplePathArena` e `FirstPlayableArena`.

## Sincronização da luta

`FirstPlayableArena` ativa e desativa o estado visual do ambiente junto com o fluxo real da partida:

```text
countdown/result → ambiente em repouso
battle           → ambiente ativo
```

## Validação

O smoke da vertical slice confirma:

- presença de `EnvironmentArt` e `ArenaDressing`;
- fundo atrás da arena;
- dressing acima do blockout;
- pontos estratégicos de debug ocultos;
- três montanhas e três cachoeiras;
- atmosfera animada;
- 15 plataformas revestidas;
- três paredes revestidas;
- três beacons de rota;
- dois santuários de spawn;
- nenhuma mudança de colisão.

## Estado

```text
Blockout e colisão: funcionais
Fundo procedural: funcional
Ruínas e acabamento: funcionais
Assets finais de cenário: opcionais para refinamento posterior
```

Assinatura: Tehkné Solutions
