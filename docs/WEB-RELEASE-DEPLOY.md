# Taijifu Masters — Web Release e deploy

**Produto desenvolvido por Tehkné Solutions**

## Arquitetura escolhida

A versão atual é publicada como aplicação estática:

```text
Godot 4.3
→ exportação Web single-threaded
→ HTML + JavaScript + WebAssembly + PCK
→ PWA
→ Vercel CDN
```

Nesta etapa não é necessário Render Web Service, servidor Node ou backend permanente.

O Render continua sendo uma alternativa válida como **Static Site**, mas a configuração oficial deste repositório usa Vercel.

---

## Por que single-threaded

O preset Web mantém:

```text
variant/thread_support=false
variant/extensions_support=false
```

Benefícios:

- melhor compatibilidade com Safari e dispositivos móveis;
- menor dependência de `SharedArrayBuffer`;
- menos risco de incompatibilidade com integrações externas;
- execução adequada para o protótipo atual.

Os headers `COOP` e `COEP` continuam configurados na Vercel para preparar o projeto para uma futura versão com threads.

---

## Progressive Web App

O export ativa PWA com:

- ícone vetorial;
- modo standalone;
- orientação paisagem;
- service worker;
- cache offline após o primeiro carregamento;
- página offline própria;
- identidade Tehkné Solutions.

Arquivos-fonte:

```text
web/taijifu-web-icon.svg
web/offline.html
```

Os dados de `user://` são armazenados pelo navegador usando IndexedDB.

Perfis, histórico, presets, temporadas e torneios permanecem no navegador/dispositivo até existir sincronização em nuvem.

---

## Build local

Em Linux, macOS, WSL ou Git Bash:

```bash
bash scripts/build-web.sh
```

O script:

1. baixa o Godot 4.3 stable quando necessário;
2. instala os templates oficiais de exportação;
3. importa os recursos;
4. executa o preset `Web`;
5. gera `web-build/index.html`;
6. valida HTML, WASM, PCK e PWA;
7. grava `web-build/build-info.json`.

O primeiro build realiza downloads maiores. Builds seguintes reutilizam o cache local.

### Servir localmente

```bash
python3 -m http.server 4173 --directory web-build
```

Abra:

```text
http://127.0.0.1:4173
```

Não abra `index.html` diretamente por `file://`, pois WebAssembly, service workers e IndexedDB dependem de um servidor HTTP.

---

## GitHub Actions

Workflow:

```text
.github/workflows/web-release.yml
```

Em cada pull request relevante e em cada push para `main`, o workflow:

1. restaura o cache do Godot;
2. exporta a versão Web;
3. valida os artefatos;
4. inicia um servidor local;
5. abre o jogo no Chromium com Playwright;
6. valida o canvas 1280 × 720;
7. verifica falhas de rede e exceções JavaScript;
8. salva uma captura de tela;
9. publica o build como artefato do GitHub Actions.

Artefatos ficam disponíveis por 14 dias.

---

## Publicação na Vercel

O arquivo `vercel.json` já define:

```text
Build Command: bash scripts/build-web.sh
Output Directory: web-build
Framework: Other / nenhum framework
```

### Primeira publicação

1. Entre na Vercel.
2. Escolha **Add New → Project**.
3. Importe `Tehkne-Solutions/taijifu-masters`.
4. Mantenha o diretório raiz como `.`.
5. Confirme que a Vercel reconheceu `vercel.json`.
6. Clique em **Deploy**.

Não são necessárias variáveis de ambiente para a versão atual.

Após conectar o GitHub:

- branches e pull requests geram Preview Deployments;
- merges na `main` geram a versão de produção;
- HTTPS e CDN são automáticos;
- um domínio próprio pode ser conectado posteriormente.

---

## Headers configurados

A Vercel envia:

```text
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
Cross-Origin-Resource-Policy: same-origin
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
```

O service worker e o `index.html` usam revalidação para evitar que uma versão antiga permaneça presa no cache após novos deploys.

---

## Arquivos gerados

O conteúdo exato pode variar conforme o Godot, mas o gate exige no mínimo:

```text
web-build/
├── index.html
├── index.js
├── index.wasm
├── index.pck
├── *.service.worker.js
├── *.manifest.json ou *.webmanifest
├── *.offline.html
└── build-info.json
```

Os arquivos gerados não são versionados no Git. Eles são produzidos pelo CI e pela Vercel.

---

## Limitações atuais do navegador

- gamepads só aparecem depois que algum botão é pressionado;
- áudio pode exigir primeiro clique ou tecla do jogador;
- persistência depende de IndexedDB e pode ser limitada no modo anônimo;
- exportações para arquivos usam as regras de download do navegador;
- clipboard depende de HTTPS e permissões do navegador;
- desempenho varia conforme WebGL 2.0 e hardware disponível;
- multiplayer online ainda exigirá backend e servidor autoritativo.

---

## Evolução futura

```text
Vercel
├── jogo Web
├── landing page
└── páginas públicas de ranking/torneio

Supabase
├── autenticação
├── inventário
├── progressão
├── histórico sincronizado
└── rankings

Servidor dedicado
├── salas
├── matchmaking
├── simulação autoritativa
└── multiplayer em tempo real
```

Render, Fly.io ou serviço equivalente poderá hospedar a camada multiplayer quando ela existir. O cliente Web continuará na Vercel.

---

**Tehkné Solutions**
