# Taijifu Masters — consolidação offline dos playtests

## Finalidade

A ferramenta `aggregate_first_playable_reports.py` consolida múltiplos relatórios locais do First Playable em uma visão única de produto e balanceamento.

Ela funciona sem banco de dados, conta, token, pacote externo ou conexão com a internet. Os arquivos originais não são alterados e nenhum dado é enviado automaticamente.

## Requisitos

- Python 3.10 ou superior;
- relatórios no schema `tehkne/taijifu-match-telemetry/v3`;
- arquivos organizados em uma ou mais pastas locais.

## Uso básico

Coloque os JSONs recebidos dos testadores em uma pasta, por exemplo:

```text
playtest-reports/
├── tester-01.json
├── tester-02.json
└── lote-b/
    ├── tester-03.json
    └── tester-04.json
```

Execute a partir da raiz do repositório:

```bash
python tools/playtest/aggregate_first_playable_reports.py \
  playtest-reports/ \
  --output-dir playtest-summary/
```

No Windows PowerShell:

```powershell
python .\tools\playtest\aggregate_first_playable_reports.py `
  .\playtest-reports\ `
  --output-dir .\playtest-summary\
```

Também é possível combinar arquivos e diretórios:

```bash
python tools/playtest/aggregate_first_playable_reports.py \
  reports/windows/ \
  reports/web/ \
  reports/manual-session.json \
  --output-dir playtest-summary/
```

## Arquivos gerados

A pasta de saída contém:

```text
first-playable-playtest-summary.json
first-playable-playtest-summary.md
```

O JSON é indicado para automações, dashboards e comparação entre versões. O Markdown é indicado para revisão em PRs, issues, reuniões e relatórios de sprint.

## Métricas consolidadas

A ferramenta calcula o total e a divisão por Aprendiz, Discípulo e Mestre:

- sessões válidas e arquivos incompatíveis;
- partidas concluídas e abandonadas;
- taxa de vitória do jogador;
- duração média e mediana;
- avaliações `fácil demais`, `equilibrado` e `difícil demais`;
- cobertura de feedback;
- pausas e retomadas;
- solicitações de revanche;
- formas de encerramento;
- versões, plataformas e localidades presentes na amostra.

## Sinais automáticos

O relatório destaca situações que merecem investigação, entre elas:

- amostra pequena demais para alterar balanceamento;
- baixa cobertura da pergunta pós-partida;
- abandono acima de 15%;
- Aprendiz percebido como difícil demais;
- taxa de vitória baixa no Aprendiz;
- Mestre percebido como fácil demais;
- taxa de vitória excessiva no Mestre.

Esses sinais não substituem observação qualitativa. Eles servem para priorizar quais partidas, vídeos e relatos devem ser revisados primeiro.

## Modo rigoroso

Para gerar os relatórios, mas retornar código de erro caso qualquer arquivo seja inválido:

```bash
python tools/playtest/aggregate_first_playable_reports.py \
  playtest-reports/ \
  --output-dir playtest-summary/ \
  --fail-on-invalid
```

Códigos de saída:

- `0`: consolidação concluída;
- `2`: nenhuma sessão válida encontrada;
- `3`: consolidação concluída, mas havia entrada inválida no modo rigoroso.

## Processo recomendado por versão

1. Criar uma pasta separada para cada build.
2. Não misturar relatórios de versões diferentes sem necessidade explícita.
3. Executar a consolidação após cada lote de playtests.
4. Comparar dificuldades e plataformas.
5. Abrir issues somente para sinais reproduzíveis ou tendências consistentes.
6. Repetir o teste após cada ajuste de combate.

Exemplo:

```text
playtests/
├── 0.2.0-first-playable/
├── 0.2.1-balance-a/
└── 0.2.2-balance-b/
```

## Privacidade

O agregador processa somente os campos técnicos presentes nos relatórios. Não adicionar nome, e-mail, IP, credenciais ou informações pessoais aos JSONs.

Processamento: offline/local  
Assinatura: Tehkné Solutions
