# Nixit GGUF Engine

Motore locale GGUF per NixitOS basato su `llama.cpp` in modalità server OpenAI-compatible.

## Percorsi

- Configurazione installata: `/usr/share/nixit-gguf-engine/`
- Compose installato: `/usr/share/nixit-gguf-engine/compose.yaml`
- Config router: `/usr/share/nixit-gguf-engine/config/models.config`
- Modelli GGUF: `/var/llms/ggufs`
- API locale: `http://127.0.0.1:8080/v1`

## Uso

```bash
nixitos-llm up
nixitos-llm health
nixitos-llm logs
nixitos-llm down
```

`nixit-chat` usa lo stesso motore. Se l'API locale non è raggiungibile, prova ad avviare automaticamente il compose centralizzato.

## Politica memoria locale

Il profilo locale del laptop espone solo sezioni `32k` e mantiene la pressione di memoria GPU/RAM condivisa entro circa 10 GiB. Per contesti lunghi usare `api.ai.nixit.it` o un server dedicato.

## Verifica

```bash
podman ps --filter name=nixit-gguf-engine
curl -fsS http://127.0.0.1:8080/health
curl -fsS http://127.0.0.1:8080/v1/models
```
