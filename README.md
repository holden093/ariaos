<div align="center">
  <img src="logo.svg" alt="NixitOS Logo" width="200"/>
  <h1>NixitOS</h1>
  <p><em>Un sistema operativo immutabile, minimale e ottimizzato per workload AI locali.</em></p>
</div>

---

## ⚠️ Disclaimer Importante

**ATTENZIONE**: Questa repository **NON** è intesa per l'uso pubblico o generale. 

NixitOS è una configurazione (basata su `bootc` e `blue-build`) creata in modo sartoriale **esclusivamente per una specifica configurazione hardware locale**. Contiene script, regole di modprobe e ottimizzazioni di sistema (come la gestione on-demand di eGPU NVIDIA via Thunderbolt e tuning della zRAM per modelli LLM) che potrebbero causare instabilità, kernel panic o mancati avvii su macchine diverse. 

**Non installare questa immagine sul tuo computer.**

---

## 🚀 Cos'è NixitOS?

NixitOS è un'immagine derivata da Fedora Silverblue 44, strutturata seguendo il paradigma GitOps tramite `bootc`. L'obiettivo principale è massimizzare l'efficienza del sistema per il caricamento e l'esecuzione di Large Language Models (LLM) tramite `llama.cpp` e tool simili, mantenendo un ambiente di base ("host") estremamente pulito e reattivo.

### Caratteristiche Principali

*   **Immutabilità & GitOps**: Ogni modifica al sistema operativo è tracciata in questa repository (nel `Containerfile` o in `build_files/`) e "buildata" in un'immagine container.
*   **Gestione Hardware Asimmetrica**:
    *   **Intel Arc (Lunar Lake)**: Supporto nativo integrato tramite `intel-compute-runtime` e `intel-level-zero` per l'accelerazione hardware (SYCL/Vulkan) a basso consumo.
    *   **NVIDIA eGPU (On-Demand)**: Driver NVIDIA presenti ma rigorosamente bloccati all'avvio (`blacklist`). L'eGPU viene attivata e disattivata manualmente tramite script dedicati (`egpu-up.sh` e `egpu-down.sh`) solo quando è richiesta la massima potenza di calcolo, garantendo consumi nulli quando non in uso.
*   **Minimalismo Estremo**:
    *   Pruning dei pacchetti ingombranti (come `glibc-all-langpacks`, risparmiando ~220MB).
    *   **Rimozione di GNOME Software**: Per eliminare notifiche fastidiose e aggiornamenti automatici non desiderati. I Flatpak sono gestiti in modo pulito ed efficiente via terminale.
    *   Configurazione zRAM personalizzata: 16GB (50% della RAM) con algoritmo `zstd`. Questo fornisce un cuscinetto ad altissima compressione per il sistema operativo, lasciando la maggior parte della memoria fisica (32GB) libera per i pesi dei modelli LLM.
*   **Tuning di Sistema**: Regolazioni `sysctl` per massimizzare la reattività dello swap, ottimizzare i buffer di rete e supportare carichi di lavoro intensivi tramite container (Podman/Distrobox).

## 🛠 Struttura della Repository

*   `Containerfile`: La "ricetta" principale per la costruzione dell'immagine basata su `ghcr.io/blue-build/base-images/fedora-silverblue-nvidia:44`.
*   `build_files/`: Directory copiata direttamente nella root `/` del sistema. Contiene script personalizzati, configurazioni kernel (`modprobe.d`, `sysctl.d`) e temi.
*   `.github/workflows/`: Pipeline CI/CD per generare automaticamente la nuova immagine ad ogni commit.
*   `.gemini/skills/`: Contiene la skill `nixitos-optimizer`, utilizzata per l'analisi e la manutenzione automatizzata dell'efficienza della codebase.
