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
* **Ottimizzazione RAM per AI**: zRAM configurata a 16GB (algoritmo `zstd`) per comprimere il sistema operativo e lasciare la memoria fisica (32GB) libera per i modelli LLM.
* **Audio a Bassa Latenza**: Tuning avanzato del kernel Fedora (`threadirqs`, `preempt=full`) combinato con priorità real-time (`realtime-setup` e `tuned`) per prestazioni ottimali nella registrazione audio e uso DAW.
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
   sudo nixitos-home-restore
   ```
4. **Abilita Audio a Bassa Latenza** (Obbligatorio per produzione audio):
   Aggiungi il tuo utente ai gruppi corretti per sfruttare i privilegi `rtprio`:
   ```bash
   sudo usermod -aG realtime,audio $USER
   ```
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
* **`nixitos-home-backup`**: Utility TUI basata su `btrfs send` per esportare in sicurezza la `/var/home` in un file zstd.
* **`nixitos-home-restore`**: Utility TUI basata su `btrfs receive` per ripristinare il backup su installazioni pulite.

## 📖 Documentazione

Per i dettagli tecnici, i vincoli architetturali completi, la pipeline GitOps e le istruzioni esclusive per gli agenti IA, consulta il file **[AGENTS.md](AGENTS.md)**. Costituisce la vera "Source of Truth" tecnica del progetto NixitOS.
