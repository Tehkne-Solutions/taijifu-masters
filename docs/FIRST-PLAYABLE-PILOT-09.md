# Taijifu Masters — Sprint 09: rodada piloto controlada

## Objetivo

Executar a rodada real `pilot-09-r2` com a build `0.2.2-playtest`, de 6 a 12 participantes, preservando anonimato e produzindo evidência suficiente para priorizar correções antes da arte final.

Nenhum resultado é inventado. Dados sintéticos existem somente nos testes automatizados.

O comando operacional oficial é `tools/playtest/run_first_playable_pilot.py`. O módulo `first_playable_pilot.py` é apenas o núcleo determinístico.

## Plano oficial

A primeira rodada usa 9 códigos anônimos:

- 6 participantes no Windows;
- 3 participantes no Web/Chromium;
- 3 iniciando no Aprendiz;
- 3 iniciando no Discípulo;
- 3 iniciando no Mestre;
- 2 partidas em cada dificuldade por participante;
- até 54 partidas previstas.

O plano versionado está em `playtest/pilots/pilot-09-r2/`.

## Privacidade

Dentro do projeto, cada participante existe somente como `TJFP-###`.

Não registrar:

- nome;
- e-mail;
- telefone;
- IP;
- CPF/CNPJ;
- senha, token ou credencial;
- perfis de redes sociais.

Contatos pessoais permanecem fora dos relatórios técnicos e fora do GitHub.

## Distribuição

Entregar somente o kit:

```text
Taijifu-Masters-External-Playtest-Kit-0.2.2-playtest.zip
```

O coordenador usa o pacote privado:

```text
Taijifu-Masters-Pilot-Coordinator-pilot-09-r2-0.2.2-playtest.zip
```

O pacote privado não deve ser enviado integralmente aos participantes.

Cada participante recebe apenas:

- o kit do jogador;
- o código `TJFP-###` atribuído;
- a plataforma;
- a ordem das dificuldades;
- o protocolo `FIRST-PLAYABLE-PLAYTEST.md`.

## Fluxo no jogo

1. Abrir o First Playable.
2. Informar o código anônimo no menu.
3. Confirmar que o botão `JOGAR CONTRA IA` foi liberado.
4. Selecionar a dificuldade indicada.
5. Jogar sem orientação na primeira tentativa.
6. Responder à avaliação de equilíbrio após cada partida.
7. No Web, usar `BAIXAR RELATÓRIO JSON`.
8. No Windows, usar `LOCALIZAR RELATÓRIO JSON`.
9. Usar a cópia para clipboard apenas como fallback.

O arquivo já deve nascer como:

```text
TJFP-001__taijifu_1785450000-1234.json
```

Não renomear quando o prefixo estiver correto.

## Estrutura privada recomendada

```text
pilot-data/
  pilot-09-r2/
    reports/
      TJFP-001__taijifu_....json
      TJFP-002__taijifu_....json
    qualitative/
      pilot-observations.json
```

Não versionar `pilot-data/`.

## Intake seguro

```bash
python tools/playtest/run_first_playable_pilot.py intake \
  pilot-data/pilot-09-r2/reports \
  --plan playtest/pilots/pilot-09-r2/pilot-plan.json \
  --output-dir pilot-control/pilot-09-r2/intake \
  --strict
```

O intake:

- valida schema de telemetria v3;
- exige build `0.2.2-playtest`;
- valida o código anônimo no nome e nos metadados;
- calcula SHA-256;
- bloqueia arquivos e sessões duplicadas;
- bloqueia possível PII;
- remove caminhos locais do manifesto;
- não altera o JSON original.

## Consolidação

```bash
python tools/playtest/aggregate_first_playable_reports.py \
  pilot-data/pilot-09-r2/reports \
  --output-dir pilot-control/pilot-09-r2/summary \
  --fail-on-invalid
```

Saídas:

- `first-playable-playtest-summary.json`;
- `first-playable-playtest-summary.md`.

## Observações qualitativas

Editar uma cópia privada de `playtest/pilots/pilot-09-r2/pilot-observations.json`.

Prioridades:

- `blocker` ou `critical` → P0;
- `major` ou `high` → P1;
- `minor` ou `medium` → P2;
- `polish` ou `low` → P3.

Categorias sempre P0:

- `crash`;
- `soft_lock`;
- `data_loss`;
- `cannot_start`;
- `telemetry_loss`.

## Triagem

```bash
python tools/playtest/run_first_playable_pilot.py triage \
  --plan playtest/pilots/pilot-09-r2/pilot-plan.json \
  --intake pilot-control/pilot-09-r2/intake/pilot-intake-manifest.json \
  --summary pilot-control/pilot-09-r2/summary/first-playable-playtest-summary.json \
  --observations pilot-data/pilot-09-r2/qualitative/pilot-observations.json \
  --decisions playtest/pilots/pilot-09-r2/pilot-decisions.json \
  --output-dir pilot-control/pilot-09-r2/triage \
  --strict \
  --fail-on-p0
```

O gate endurecido bloqueia:

- P0 aberto;
- observação rejeitada;
- decisão inválida;
- ID de backlog desconhecido;
- mistura entre piloto ou build.

## Gate da Sprint 09

A rodada só termina quando:

- existem pelo menos 6 participantes válidos;
- existem pelo menos 24 partidas concluídas;
- cada dificuldade possui pelo menos 6 partidas;
- a cobertura de feedback é de pelo menos 70%;
- não existe P0 aberto;
- todos os P1 possuem decisão registrada;
- não há observação ou decisão inválida;
- resumo e backlog finais foram anexados à issue #152 sem dados pessoais.

## Regra de produto

Antes do gate, corrigir imediatamente P0 reproduzível e P1 de controles, fluxo ou clareza. Não alterar números de balanceamento com amostra insuficiente e não iniciar produção em massa de animações finais para comportamentos ainda instáveis.

Assinatura: Tehkné Solutions
