# Checklist de publicação Web

**Tehkné Solutions**

## Antes do merge

- [ ] Godot CI aprovado.
- [ ] Web Release aprovado.
- [ ] `index.html`, `.wasm` e `.pck` presentes no artefato.
- [ ] PWA com manifesto, service worker e página offline.
- [ ] Canvas carregado no Chromium sem exceções JavaScript.
- [ ] Captura de tela do smoke test disponível.

## Primeira configuração na Vercel

- [ ] Importar `Tehkne-Solutions/taijifu-masters`.
- [ ] Confirmar diretório raiz `.`.
- [ ] Confirmar `vercel.json` detectado.
- [ ] Confirmar Build Command `bash scripts/build-web.sh`.
- [ ] Confirmar Output Directory `web-build`.
- [ ] Publicar o primeiro Preview Deployment.
- [ ] Testar teclado, gamepad, áudio, IndexedDB e PWA.
- [ ] Promover para produção após validação.

## Após cada lançamento

- [ ] Abrir a URL em Chromium e Firefox.
- [ ] Verificar o console do navegador.
- [ ] Testar uma série completa.
- [ ] Reiniciar a página e verificar persistência local.
- [ ] Instalar a PWA e abrir em modo standalone.
- [ ] Conferir que o service worker recebeu a versão atual.
- [ ] Validar pelo menos um gamepad real.
- [ ] Registrar limitações ou regressões no GitHub.

---

**Tehkné Solutions**
