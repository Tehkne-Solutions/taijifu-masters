# Compartilhamento de fantasmas e desafios por código

**Produto:** Taijifu Masters  
**Assinatura:** Tehkné Solutions

## Objetivo

Esta evolução conecta o treino técnico individual a um ciclo social assíncrono:

```text
gravar → exportar → compartilhar → importar → comparar → superar
```

O pacote compartilhado contém somente dados de replay e métricas técnicas. Ele não transporta inventário, progresso competitivo, ranking, recompensas, perfil pessoal ou dados de autenticação.

## Runtime

Novo autoload:

```text
TaijifuGhostSharing
```

Arquivo principal:

```text
scripts/runtime/ghost_sharing_runtime.gd
```

A implementação consome o melhor replay já mantido por `TaijifuInputGhostMastery`, sem criar um segundo sistema de gravação.

## Formato do pacote

```json
{
  "kind": "taijifu-ghost",
  "version": 1,
  "game": "Taijifu Masters",
  "created_unix": 0,
  "recording": {},
  "challenge": {},
  "checksum": "sha256"
}
```

O pacote inclui:

- frames ordenados por tempo;
- posição e velocidade limitadas a faixas seguras;
- direção, fase, técnica, arma e inputs;
- resumo técnico;
- desafio derivado da pontuação;
- checksum SHA-256 contra adulteração acidental ou manual.

## Regras de segurança

A importação rejeita:

- JSON inválido;
- tipo de pacote incompatível;
- versão futura não suportada;
- checksum divergente;
- menos de dois frames;
- mais de 1.800 frames;
- frames fora de ordem;
- posições malformadas.

Eventos externos não são reproduzidos. O replay importado continua estritamente visual.

## Política de substituição

Por padrão, um fantasma importado só substitui o melhor replay local quando possui pontuação superior.

A interface pode enviar `replace_best: true` para uma substituição explícita. Essa opção deve ser apresentada ao jogador como ação consciente e reversível.

## Arquivo local

A exportação também grava:

```text
user://taijifu-ghost-export.json
```

## Ponte Web

Funções globais:

```text
taijifuGhostSharingCommand
taijifuGhostSharingState
taijifuGhostSharingStateJson
taijifuGhostSharingReady
taijifuGhostSharingVersion
```

Comandos:

```json
{"command":"get_state"}
{"command":"export_best"}
{"command":"import_code","code":"...","replace_best":false}
{"command":"import_json","payload":"{...}","replace_best":false}
```

## Desafio derivado

Cada pacote gera um desafio compacto com:

- identificador;
- pontuação-alvo;
- precisão;
- elo máximo;
- duração;
- regra de superação sob as mesmas regras físicas.

A primeira versão não concede recompensa automática. Isso evita farming, adulteração de progresso e dependência prematura de backend.

## Validação

Smoke test:

```text
scripts/ci/ghost_sharing_smoke_test.gd
```

O teste cobre:

- presença do autoload;
- criação do pacote;
- checksum SHA-256;
- preservação da pontuação do desafio;
- importação por código Base64;
- rejeição de pacote adulterado;
- rejeição de frames fora de ordem.

## Próxima etapa recomendada

- painel Web para copiar e colar códigos;
- biblioteca local de fantasmas importados;
- seleção do fantasma adversário sem substituir o recorde pessoal;
- corrida contra fantasma em arenas de percurso;
- QR Code para compartilhamento entre dispositivos;
- backend opcional com expiração e moderação de códigos.

---

**Tehkné Solutions**
