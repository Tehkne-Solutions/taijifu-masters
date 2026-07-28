# Validação do painel Web de fantasmas

**Assinatura:** Tehkné Solutions

O teste Playwright `web-tests/ghost-sharing-web.spec.cjs` valida:

- montagem do painel;
- geração do código;
- preenchimento do campo;
- importação sem substituição automática;
- opção de substituição desmarcada por padrão.

O teste usa uma ponte simulada e não altera dados competitivos.
