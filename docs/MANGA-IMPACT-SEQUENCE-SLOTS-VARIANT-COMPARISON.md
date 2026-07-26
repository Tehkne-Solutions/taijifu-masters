# Taijifu Masters — Impactos, slots do Dojo e comparação técnica

**Tehkné Solutions**

## Objetivo

Esta entrega fecha três lacunas do Protótipo Zero:

1. golpes precisavam de resposta audiovisual proporcional ao caminho e à consequência;
2. o Dojo precisava guardar mais de uma situação de treino e repeti-la continuamente;
3. variantes ensinadas pelos mestres precisavam ser comparadas com suas técnicas-base por dados reais, não apenas por descrição.

---

# 1. Diretor de impacto

O `ImpactDirector` conecta-se ao sinal `impact_resolved` de cada lutador.

Cada impacto fornece:

- alvo;
- atacante;
- técnica;
- resultado;
- dano aplicado;
- postura aplicada;
- intensidade;
- posição no mundo.

## Resultados reconhecidos

- acerto;
- bloqueio;
- aparo;
- esquiva;
- quebra de postura.

## Onomatopeias

### Tai

`VUSH!`

Comunica velocidade, alcance e deslocamento.

### Ji

`DOOM!`

Comunica massa, contato e pressão de postura.

### Fu

`FLUX!`

Comunica redirecionamento, transição e adaptação.

### Respostas especiais

- bloqueio: `THOK!`;
- aparo: `CLANG!`;
- esquiva: `SWISH!`;
- quebra de postura: `KRAK!`.

## Linguagem gráfica

- Tai usa linhas horizontais de velocidade;
- Ji usa linhas radiais e impacto concentrado;
- Fu usa arcos e espirais;
- quebra de postura adiciona um anel de ruptura.

## Hitstop

O hitstop é breve e calibrado por consequência.

- Tai recebe a menor duração;
- Ji recebe maior peso e redução mais forte de `time_scale`;
- Fu permanece intermediário;
- aparo possui pausa própria;
- quebra de postura possui a pausa mais forte;
- esquiva não congela a luta.

O timer de restauração ignora o `time_scale`, evitando congelamento permanente.

## Câmera

O shake usa somente o `offset` da câmera e não altera:

- posição lógica;
- limites da arena;
- cálculo de rota;
- telemetria;
- hitboxes.

A amplitude varia por intensidade e é maior em Ji e em quebra de postura.

---

# 2. Eventos de execução e impacto

O controlador final dos lutadores agora expõe:

```text
technique_executed
impact_resolved
```

Também foi corrigida uma inconsistência anterior: uma variante desbloqueada, mas não selecionada, não gera mais custo adicional de fôlego.

O custo extra só é calculado quando:

```text
variante desbloqueada == variante selecionada
```

---

# 3. Três slots de sequência

O gravador do Dojo possui três slots persistentes.

## Controles

- `[` — slot anterior;
- `]` — próximo slot;
- `F12` — iniciar ou encerrar gravação;
- `F5` — reproduzir;
- `F1` — apagar o slot selecionado;
- `L` — ativar ou desativar loop.

A troca de slot é bloqueada durante gravação ou reprodução.

## Loop

Quando o loop está ativo:

1. a sequência termina;
2. todas as ações simuladas são liberadas;
3. o Dojo aguarda um intervalo curto;
4. posições e recursos são restaurados;
5. a sequência recomeça.

Isso permite treinar repetidamente:

- aparos;
- esquivas;
- punições;
- distância;
- respostas a troca de arma;
- interações elementais.

## Persistência e migração

Arquivo:

```text
user://dojo_sequence.json
```

Formato atual:

```text
version: 2
selected_slot
loop_enabled
slots 1, 2 e 3
```

Arquivos da versão 1 são migrados automaticamente para o slot 1.

Todos os eventos continuam sendo validados por:

- ação permitida;
- formato de dicionário;
- duração máxima;
- ordenação temporal.

---

# 4. Comparação técnica

O painel é aberto com:

```text
M
```

Para limpar os dados:

```text
K
```

Somente execuções realizadas com o Dojo ativo entram na comparação.

## Métricas registradas

- quantidade de execuções;
- taxa de contato;
- dano médio por contato;
- postura média por contato;
- custo médio de fôlego;
- startup médio;
- ciclo total médio;
- bloqueios;
- aparos sofridos;
- esquivas sofridas;
- quebras de postura.

## Separação de amostras

As entradas são separadas por:

```text
técnica-base
variante selecionada
```

O sistema utiliza a combinação entre:

- técnica;
- arma equipada;
- variante selecionada.

Portanto, desbloquear uma variante não contamina os dados da técnica-base.

## Delta

Quando existem amostras de base e variante, o painel exibe:

- diferença de custo;
- diferença de startup;
- diferença de dano por contato;
- diferença de postura por contato;
- diferença percentual de contato.

O painel não declara uma versão superior. A interpretação depende do objetivo:

- maior alcance;
- maior segurança;
- maior postura;
- maior mobilidade;
- menor custo;
- menor tempo de compromisso.

## Persistência

Arquivo:

```text
user://variant_comparison.json
```

Os dados são salvos ao:

- fechar o painel;
- sair do Dojo;
- encerrar a cena;
- limpar manualmente.

---

# 5. Arquitetura

```text
MasteredWeaponFighterController
├── technique_executed
└── impact_resolved

ImpactDirector
├── onomatopeia
├── linhas de impacto
├── hitstop
└── camera shake

DojoSequenceRuntime
├── 3 slots
├── migração
├── loop
└── reprodução por entradas reais

VariantComparisonRuntime
├── amostras base
├── amostras de variante
├── deltas
└── persistência
```

---

# 6. Validação obrigatória no Godot 4.3+

## Impactos

1. Tai exibe `VUSH!` e linhas horizontais.
2. Ji exibe `DOOM!` com maior peso de câmera.
3. Fu exibe `FLUX!` com espirais.
4. Bloqueio exibe `THOK!`.
5. Aparo exibe `CLANG!`.
6. Esquiva exibe `SWISH!` sem hitstop.
7. Quebra de postura exibe `KRAK!`.
8. `Engine.time_scale` retorna sempre para `1.0`.
9. A câmera retorna ao offset original.
10. impactos simultâneos não deixam a luta congelada.

## Slots

1. Gravar conteúdo diferente em cada slot.
2. Trocar slots com `[` e `]`.
3. Reproduzir somente o slot selecionado.
4. Apagar apenas o slot selecionado.
5. Ativar loop com `L`.
6. Confirmar liberação de ações entre ciclos.
7. Sair do Dojo durante loop.
8. Fechar e reabrir o jogo.
9. Migrar um arquivo versão 1.

## Comparação

1. Executar uma técnica sem variante.
2. Equipar a variante na próxima preparação.
3. Executar a mesma técnica novamente.
4. Abrir o painel com `M`.
5. Confirmar duas linhas separadas.
6. Conferir custo, timing, dano e postura.
7. Testar bloqueio, aparo e esquiva.
8. Limpar com `K`.
9. Reiniciar e confirmar persistência.
10. Confirmar que ações fora do Dojo não entram no relatório.

---

# 7. Próxima etapa recomendada

- primeiro pacote de sprites provisórios por personagem;
- retratos e expressões ampliadas;
- variações de pose por startup, ativo e recuperação;
- efeitos elementais ligados ao sistema de impacto;
- exportação de relatório comparativo em JSON/CSV;
- editor interno de sequências do Dojo;
- testes automatizados de parser e carregamento do projeto.

---

**Tehkné Solutions**
