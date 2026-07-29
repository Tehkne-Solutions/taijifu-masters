# Instalador transacional TGAP

O instalador promove um bundle multi-pack aprovado para uma raiz de runtime sem expor estado parcialmente instalado.

## Pré-condições

- o ZIP deve possuir manifesto irmão `<bundle>.manifest.json`;
- o manifesto deve atender a `tgap/bundle/v1`;
- `publishable` deve ser `true`;
- o SHA-256 do ZIP deve coincidir com o manifesto;
- todos os caminhos internos devem ser relativos e livres de travessia de diretório.

## Instalação

```bash
python scripts/tgap_install_bundle.py \
  artifacts/tgap/bundles/taijifu-masters-tgap-1.0.0.zip \
  --runtime-root runtime/assets \
  --keep-backup
```

Fluxo:

```text
verificação do bundle
→ criação da transação
→ extração em staging
→ validação de caminhos
→ detecção de colisões
→ validação do novo catálogo
→ backup da instalação ativa
→ promoção atômica do staging
→ atualização atômica do catálogo
```

A instalação ativa fica em:

```text
<runtime-root>/tgap-current/
```

O catálogo ativo fica em:

```text
<runtime-root>/tgap-catalog.json
```

Cada operação mantém um registro em:

```text
<runtime-root>/.tgap-transactions/<transaction-id>/
```

## Colisões

Por padrão, um arquivo já instalado com conteúdo diferente bloqueia a operação. A substituição precisa ser explícita:

```bash
python scripts/tgap_install_bundle.py bundle.zip \
  --runtime-root runtime/assets \
  --allow-replace
```

Arquivos idênticos não são tratados como colisão.

## Rollback automático

Falhas depois do backup restauram a instalação anterior automaticamente. O relatório registra:

```json
{
  "status": "failed",
  "rollback_performed": true
}
```

## Rollback explícito

Quando `--keep-backup` foi usado:

```bash
python scripts/tgap_install_bundle.py \
  --runtime-root runtime/assets \
  --rollback 20260729T202800000000Z
```

## Garantias

- proteção contra Zip Slip;
- entradas duplicadas bloqueadas;
- staging isolado;
- catálogo validado antes da promoção;
- troca de diretório por rename;
- escrita atômica do catálogo;
- backup por transação;
- rollback automático em falha;
- rollback explícito auditável.

## Limite atual

A ferramenta instala o bundle em uma raiz de runtime genérica. A próxima camada deve conectar o catálogo instalado ao carregador de assets do jogo, com resolução por `pack_id`, versionamento e hot reload controlado.
