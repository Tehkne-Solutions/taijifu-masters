# Taijifu Masters — Sprint 09: rodada piloto controlada

## Objetivo

Executar a primeira rodada real do First Playable `0.2.1-playtest` com 6–12 participantes, preservando anonimato e produzindo evidência suficiente para priorizar correções antes da arte final.

Esta etapa não inventa resultados. Os dados sintéticos existem apenas nos testes automatizados.

## Tamanho recomendado

A primeira rodada deve usar **9 participantes**:

- 6 no Windows;
- 3 no Web/Chromium;
- 3 iniciando no Aprendiz;
- 3 iniciando no Discípulo;
- 3 iniciando no Mestre;
- 2 partidas em cada dificuldade por participante.

Resultado esperado: até 54 partidas. O gate mínimo continua sendo 6 participantes e 24 partidas concluídas.

## Perfis de experiência

Selecionar perfis por experiência, sem registrar identidade no projeto:

- 3 pessoas com pouca experiência em jogos de luta;
- 3 pessoas que jogam ação/luta ocasionalmente;
- 3 pessoas com experiência em jogos competitivos;
- incluir teclado e gamepad quando disponíveis;
- não armazenar nome, e-mail, telefone, IP ou redes sociais.

O coordenador mantém contatos fora dos relatórios técnicos. Dentro do projeto, cada pessoa existe apenas como `TJFP-###`.

## 1. Gerar o plano

Na raiz do repositório:

```bash
python tools/playtest/first_playable_pilot.py plan \
  --pilot-id pilot-09-r1 \
  --participants 9 \
  --windows-share 0.6666667 \
  --matches-per-difficulty 2 \
  --output-dir pilot-control/pilot-09-r1
```

PowerShell:

```powershell
python tools/playtest/first_playable_pilot.py plan `
  --pilot-id pilot-09-r1 `
  --participants 9 `
  --windows-share 0.6666667 `
  --matches-per-difficulty 2 `
  --output-dir pilot-control/pilot-09-r1
```

Arquivos gerados:

- `pilot-plan.json`: contrato da rodada;
- `pilot-roster.csv`: distribuição para coordenação;
- `pilot-plan.md`: roteiro legível;
- `pilot-observations.json`: formulário qualitativo vazio;
- `pilot-decisions.json`: registro vazio de decisões P0/P1.

## 2. Entregar o kit

Usar somente o kit auditado:

```text
Taijifu-Masters-External-Playtest-Kit-0.2.1-playtest.zip
```

Cada participante recebe:

- seu código anônimo;
- sua plataforma;
- a ordem das dificuldades;
- a instrução de jogar a primeira tentativa sem orientação;
- o protocolo `FIRST-PLAYABLE-PLAYTEST.md` contido no kit.

## 3. Receber os relatórios

Cada JSON deve ser renomeado antes do intake:

```text
TJFP-001__taijifu_1785450000-1234.json
```

Nunca editar o conteúdo para inserir o código. O vínculo fica apenas no nome do arquivo e no manifesto de intake.

Estrutura recomendada:

```text
pilot-data/
  pilot-09-r1/
    reports/
      TJFP-001__taijifu_....json
      TJFP-002__taijifu_....json
    qualitative/
      pilot-observations.json
```

Não versionar `pilot-data/` no GitHub. Relatórios reais devem permanecer em armazenamento privado controlado pela Tehkné Solutions.

## 4. Validar o lote

```bash
python tools/playtest/first_playable_pilot.py intake \
  pilot-data/pilot-09-r1/reports \
  --plan pilot-control/pilot-09-r1/pilot-plan.json \
  --output-dir pilot-control/pilot-09-r1/intake \
  --strict
```

O intake:

- valida o schema v3;
- exige build `0.2.1-playtest`;
- exige código `TJFP-###` no nome;
- calcula SHA-256;
- detecta arquivo duplicado;
- detecta `session_id` duplicado;
- bloqueia possível PII;
- não modifica o JSON original.

Um lote rejeitado não deve seguir para consolidação até ser corrigido.

## 5. Consolidar a telemetria

Usar apenas os relatórios aceitos pelo intake:

```bash
python tools/playtest/aggregate_first_playable_reports.py \
  pilot-data/pilot-09-r1/reports \
  --output-dir pilot-control/pilot-09-r1/summary \
  --fail-on-invalid
```

Saídas:

- `first-playable-playtest-summary.json`;
- `first-playable-playtest-summary.md`.

## 6. Registrar observações qualitativas

Editar uma cópia privada de `pilot-observations.json`.

Exemplo:

```json
{
  "schema": "tehkne/taijifu-first-playable-observations/v1",
  "pilot_id": "pilot-09-r1",
  "build_version": "0.2.1-playtest",
  "signature": "Tehkné Solutions",
  "observations": [
    {
      "participant_id": "TJFP-003",
      "title": "Defesa não ficou clara",
      "category": "combat_clarity",
      "description": "Não foi possível perceber quando o bloqueio funcionou.",
      "reproduction": "Defender três ataques consecutivos no Discípulo.",
      "severity": "major",
      "platform": "windows",
      "difficulty": "disciple"
    }
  ]
}
```

Severidades aceitas:

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

Relatos com mesmo título normalizado e categoria são agrupados e contam ocorrências e participantes.

## 7. Gerar o backlog

```bash
python tools/playtest/first_playable_pilot.py triage \
  --plan pilot-control/pilot-09-r1/pilot-plan.json \
  --intake pilot-control/pilot-09-r1/intake/pilot-intake-manifest.json \
  --summary pilot-control/pilot-09-r1/summary/first-playable-playtest-summary.json \
  --observations pilot-data/pilot-09-r1/qualitative/pilot-observations.json \
  --decisions pilot-control/pilot-09-r1/pilot-decisions.json \
  --output-dir pilot-control/pilot-09-r1/triage \
  --strict \
  --fail-on-p0
```

Saídas:

- `pilot-backlog.json`;
- `pilot-backlog.md`.

## 8. Registrar decisões

Todos os P1 precisam de decisão explícita. Copiar o `id` do item do backlog para `pilot-decisions.json`.

```json
{
  "schema": "tehkne/taijifu-first-playable-decisions/v1",
  "pilot_id": "pilot-09-r1",
  "build_version": "0.2.1-playtest",
  "signature": "Tehkné Solutions",
  "decisions": [
    {
      "backlog_item_id": "signal:abandonment_high",
      "status": "accepted",
      "rationale": "Será corrigido antes da próxima rodada.",
      "target_version": "0.2.2-playtest",
      "owner_role": "Gameplay Engineering"
    }
  ]
}
```

Status aceitos:

- `accepted`;
- `in_progress`;
- `fixed`;
- `deferred`;
- `not_reproducible`;
- `wont_fix`.

P0 só é considerado resolvido com `fixed` ou `not_reproducible`. `wont_fix` não libera P0.

## Gate para encerrar a Sprint 09

A rodada real só pode ser encerrada quando:

- existem pelo menos 6 participantes com sessão aceita;
- existem pelo menos 24 partidas concluídas;
- cada dificuldade possui pelo menos 6 partidas;
- cobertura de feedback é igual ou superior a 70%;
- não existe P0 aberto;
- todo P1 possui decisão documentada;
- observações rejeitadas foram corrigidas;
- resumo e backlog finais foram anexados à issue #152 sem dados pessoais.

## Regra de produto

Antes do gate:

- corrigir imediatamente P0 reproduzível;
- pode corrigir P1 de controles, fluxo ou clareza;
- não alterar números de balanceamento com amostra insuficiente;
- não iniciar produção em massa de animações finais para comportamentos ainda instáveis.

Depois do gate:

- congelar os controles aprovados;
- criar a versão `0.2.2-playtest` com correções;
- executar uma segunda rodada focada nos P1;
- iniciar substituição progressiva da arte procedural somente nos sistemas estáveis.

Assinatura: Tehkné Solutions
