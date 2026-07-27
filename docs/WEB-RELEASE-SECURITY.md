# Segurança da hospedagem Web

## Requisitos mínimos

- HTTPS obrigatório em produção;
- WebAssembly servido como `application/wasm`;
- `X-Content-Type-Options: nosniff`;
- isolamento de origem configurado;
- nenhuma chave secreta embutida no cliente;
- nenhuma credencial versionada no repositório.

## Cliente público

Todo conteúdo exportado para `web-build/` é público. Portanto:

- não incluir tokens;
- não incluir segredos de API;
- não incluir chaves administrativas;
- não confiar no cliente para validar resultados competitivos futuros.

## Multiplayer futuro

Partidas online competitivas exigirão servidor autoritativo. O cliente Web não deverá decidir sozinho inventário, progressão, ranking ou vencedor de uma partida de rede.

---

**Tehkné Solutions**
