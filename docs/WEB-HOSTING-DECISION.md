# Decisão de hospedagem Web

**Escolha principal:** Vercel

**Fallback:** Render Static Site

## Vercel

Usa automaticamente:

```text
vercel.json
bash scripts/build-web.sh
web-build/
```

É a opção recomendada para previews por pull request, CDN, HTTPS e domínio próprio.

## Render

O arquivo `render.yaml` permite criar o mesmo pacote como Static Site:

```text
Build Command: bash scripts/build-web.sh
Publish Directory: web-build
```

O Render deve ser usado como site estático. Não é necessário criar Web Service para o cliente Godot atual.

## Backend futuro

Render ou outro serviço de processos persistentes poderá ser usado futuramente para matchmaking e servidor autoritativo. Essa camada não faz parte do build Web estático atual.

---

**Tehkné Solutions**
