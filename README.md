# 🏨 NixitOS

**Un sistema operativo immutabile, minimale e ottimizzato per workload AI locali.**

---

## ⚠️ Disclaimer Importante

**ATTENZIONE**: Questa repository **NON** è intesa per l'uso pubblico o generale. NixitOS è una configurazione (basata su `bootc` e `blue-build`) creata in modo sartoriale esclusivamente per uno specifico hardware locale. Contiene script e regole che potrebbero causare instabilità su macchine diverse. **Non installare questa immagine sul tuo computer.**

---

## ✨ Caratteristiche Principali

* **Immutabilità & GitOps**: Ogni modifica al sistema operativo è tracciata in questa repository (nel `Containerfile` o in `build_files/`) e "buildata" in un'immagine container.
* **Gestione Hardware Asimmetrica**:
  * **Intel Arc (Lunar Lake)**: Supporto nativo integrato tramite `intel-compute-runtime` e `intel-level-zero` per l'accelerazione hardware (SYCL/Vulkan) a basso consumo.
  * **NVIDIA eGPU (On-Demand)**: Driver NVIDIA bloccati all'avvio (`blacklist`). Attivazione manuale tramite script dedicato che carica l'intero stack (incluso DRM). Richiede disconnessione "fredda" (Log-Out/Riavvio) per il rilascio.
* **Minimalismo Estremo**: Pruning dei pacchetti ingombranti (mantenendo solo il supporto essenziale En/It). Rimozione di GNOME Software e uso esclusivo di CLI per pacchetti e Flatpak.
* **Storage GitOps (Subvolumi Dinamici)**: Utilizzo nativo di `systemd-tmpfiles` per creare automaticamente subvolumi Btrfs per i dati pesanti (es. `llms`, `games`) in `/var`. Questi vengono poi collegati alla `/var/home` via symlink, garantendo che i backup della Home tramite snapshot siano leggerissimi ed escludano automaticamente questi enormi file. Il filesystem Btrfs utilizza compressione nativa trasparente (`zstd:1`) per prolungare la vita dell'SSD, insieme a task periodici e automatizzati in background (scrub e bilanciamento tramite `btrfsmaintenance`) per prevenire il *bit-rot* e garantire l'integrità dei dati a lungo termine.
* **Ottimizzazione CPU Avanzata**: Disattivazione dell'NMI Watchdog (`nowatchdog`) per permettere ai core di raggiungere i C-states di sonno più profondi.
* **Ottimizzazione RAM per AI**: zRAM configurata a 16GB (algoritmo `zstd`) per comprimere il sistema operativo e lasciare la memoria fisica (32GB) libera per i modelli LLM.
* **Audio a Bassa Latenza (Dynamic Tuning)**: Abbandono dei parametri kernel energivori in favore di uno script wrapper (`nixitos-daw-launcher`) che massimizza le frequenze e riduce le latenze tramite `tuned` **solo** durante l'uso della DAW, preservando la batteria nell'uso quotidiano.
* **Sicurezza & Cifratura TPM 2.0**: Supporto nativo LUKS2 automatizzato tramite chip TPM 2.0 usando Discoverable Partitions Specification (DPS).

## 🚦 Avvio Rapido

Per passare da un'installazione pulita di Fedora a NixitOS con tutti i dati:

1. **Installa Fedora (Silverblue/Kinoite/Base)**: Assicurati di creare un subvolume Btrfs separato per `/home` e spunta **"Encrypt my data"** durante l'installazione.
2. **Rebase su NixitOS**: Apri il terminale nel nuovo sistema ed esegui il rebase:
   ```bash
   sudo bootc switch ghcr.io/holden093/nixitos:latest
   ```
   *(Attendi il completamento e riavvia il sistema).*
3. **Ripristino della Home (TUI)**: Al riavvio, prima del login grafico, passa a una TTY (`Ctrl+Alt+F3`), collega il disco USB di backup e lancia:
   ```bash
   sudo restore
   ```
4. **Abilita Audio a Bassa Latenza** (Obbligatorio per produzione audio):
   Affinché le ottimizzazioni in tempo reale e lo script `nixitos-daw-launcher` funzionino, devi aggiungere il tuo utente ai gruppi `realtime` e `audio`:
   ```bash
   sudo usermod -aG realtime,audio $USER
   ```
   > **Nota Importante:** Dopo aver eseguito il comando, è **obbligatorio** effettuare un Logout e Login (o riavviare il sistema) affinché le modifiche ai gruppi abbiano effetto.
5. **Associa la chiave LUKS al TPM 2.0** (Opzionale per Zero-Config):
   ```bash
   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/nvme0n1p3
   ```
6. **Riavvia** e accedi alla tua nuova sessione completamente configurata.

## 🛠️ Stack Tecnico

| Componente | Tecnologia / Ruolo |
|---|---|
| **OS Base** | Fedora Silverblue 44 |
| **Paradigma** | Immutabile via `bootc` e `blue-build` |
| **Display Server** | GNOME (Wayland) con Tema Yaru |
| **GPU Primaria** | Intel Arc (Lunar Lake) |
| **GPU Secondaria** | NVIDIA eGPU (Thunderbolt) |
| **Filesystem & Crypto** | Btrfs + LUKS2 + TPM 2.0 |
| **Memory Management** | zRAM (16GB, zstd) |

## 📁 Struttura del Progetto

* `Containerfile`
* `build_files/`
  * `etc/`
  * `usr/`
* `.github/workflows/`
* `.antigravity/skills/`
* `AGENTS.md`
* `README.md`
* `LICENSE`

## 🛡️ Moduli Amministrativi/Operativi

Gli script operativi sono installati in `/usr/bin/` e pronti all'uso:

* **`egpu-up.sh`**: Attiva la eGPU NVIDIA caricando l'intero stack di driver (inclusi `nvidia_modeset` e `nvidia_drm`) e impostando permessi aperti (`0666`). Consente l'uso sia per inferenza AI che per rendering grafico (Wayland/GNOME).
* **`egpu-down.sh`**: Rimuove i driver NVIDIA in modo pulito dal kernel. Poiché lo script di avvio carica anche i driver DRM, prima di eseguire questo script è necessario effettuare il LOG-OUT o riavviare per liberare la GPU dal display server.
* **Pika Backup (Raccomandato)**: Questa è l'app ufficiale per i backup quotidiani, incrementali e navigabili. Poiché è profondamente integrata con GNOME, è un'eccezione alla regola "Niente Flatpak per app critiche" e va installata manualmente dall'utente via Flathub (`org.gnome.World.PikaBackup`). Perfetta per eseguire il backup sul NAS (SMB/SFTP) o dischi esterni in stile Time Machine.
* **`backup`**: Utility TUI legacy per il Disaster Recovery "Bare-Metal". Esporta la `/var/home` in un file monolitico zstd sfruttando `btrfs send`. Da usare per backup integrali offline su USB prima di formattare.
* **`restore`**: Utility TUI basata su `btrfs receive` per ripristinare il backup monolitico zstd su installazioni pulite.

## 🤖 AI Locale & Motore GGUF NixitOS

NixitOS include un workflow AI locale profondamente integrato tramite container Podman di `llama.cpp`, orchestrati direttamente via `podman compose`.

Il motore rileva dinamicamente il contesto hardware:
- **Modalità iGPU:** Predefinita su Intel Arc (SYCL) per un'inferenza a basso consumo energetico.
- **Modalità eGPU:** Se la eGPU NVIDIA Thunderbolt è collegata e autorizzata, il motore riconfigura dinamicamente lo stack per usare il container CUDA e scaricare il carico sulla RTX 3060.

### Comandi AI Comuni
- `podman compose -f /usr/share/nixit-gguf-engine/compose.yaml up -d` / `... down` - Avvia/Ferma il server di inferenza.
### 💬 Chatbot Locale (aria)

`aria` è un chatbot interattivo da terminale che si connette al motore di inferenza locale. Supporta ricerca web e comandi di sistema.

- **Avvio:** `aria`.
- **Profilo locale:** il rilevamento automatico preferisce i profili `32k`, mantenendo il budget GPU condiviso entro circa 10 GiB. I contesti lunghi vanno eseguiti su `api.ai.nixit.it`.
- **Ricerca web:** Il modello chiama automaticamente DuckDuckGo quando necessario. Forzabile con `/web <query>`.
- **Stato sistema:** Il modello rileva automaticamente quando l'utente chiede informazioni sul sistema. Forzabile con `/sys [cpu|mem|disk|gpu|proc]`.
- **Comandi:** `/help`, `/new`, `/exit`

Dipende dal container `nixit-gguf-engine` in esecuzione su `127.0.0.1:8080`. La definizione del motore è centralizzata nel repo in `build_files/usr/share/nixit-gguf-engine/` e viene installata in `/usr/share/nixit-gguf-engine/`; non dipende da directory operative esterne nella home utente.

## 📖 Documentazione

Per i dettagli tecnici, i vincoli architetturali completi, la pipeline GitOps e le istruzioni esclusive per gli agenti IA, consulta il file **[AGENTS.md](AGENTS.md)**. Costituisce la vera "Source of Truth" tecnica del progetto NixitOS.
