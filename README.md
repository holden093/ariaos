# AriaOS

AriaOS è un sistema operativo personale, immutabile e dichiarativo basato su Fedora Sway Atomic 44 e `bootc`.

> [!WARNING]
> Questa immagine è progettata per uno specifico laptop Intel Lunar Lake. Non è una distribuzione generica e può essere inadatta su hardware diverso.

## Obiettivi

- Sistema riproducibile: ogni modifica persistente vive nel repository.
- Base nativa essenziale, con Flatpak e Distrobox per applicazioni non critiche.
- Sway e Intel Arc come unico stack desktop e GPU previsto.
- Calcolo locale tramite Vulkan, OpenCL e Level Zero, senza motori preinstallati.
- Backup giornalieri e ripristino bare-metal indipendenti.
- Buona autonomia nell'uso normale e tuning dinamico per sessioni audio.

## Piattaforma

| Area | Configurazione |
|---|---|
| Base | Fedora Sway Atomic 44, `bootc` |
| Desktop | Sway con configurazione Fedora |
| GPU primaria | Intel Arc Lunar Lake (display + Vulkan) |
| Calcolo GPU | Intel Arc (Vulkan, OpenCL e Level Zero) |
| Storage | Btrfs con compressione `zstd:1` |
| Cifratura | LUKS2, TPM 2.0 e Discoverable Partitions Specification |
| Memoria | 32 GB RAM, zRAM disattivato, swapfile Btrfs da 32 GiB su `/var/swapfile` |

## Funzionalità principali

### GPU e calcolo

Intel Arc dispone di `intel-compute-runtime`, `intel-level-zero`, OpenCL e strumenti Vulkan per desktop, media e calcolo, senza alcun motore LLM host-side. La sessione usa Sway, SDDM e `xdg-desktop-portal-wlr` forniti direttamente da Fedora.

### Toolchain GPU e llama.cpp

L'immagine contiene gli strumenti per compilare manualmente `llama.cpp`, ma non
contiene il motore, i modelli, sorgenti o launcher preconfigurati. Sono inclusi
la toolchain CMake/Ninja/C++ e gli header Vulkan. Sorgenti,
build e modelli vanno conservati in `/var/home`.

Esempio di build con Vulkan:

```bash
git clone https://github.com/ggml-org/llama.cpp.git ~/src/llama.cpp
cmake -S ~/src/llama.cpp -B ~/src/llama.cpp/build \
  -G Ninja \
  -DGGML_VULKAN=ON \
  -DCMAKE_BUILD_TYPE=Release
cmake --build ~/src/llama.cpp/build --target llama-server
```

### Backup e storage

- **Pika Backup**: backup incrementali quotidiani. È l'unica applicazione critica autorizzata come Flatpak (`org.gnome.World.PikaBackup`).
- **`backup`**: esporta `/var/home` come stream Btrfs compresso su un disco esterno.
- **`restore`**: valida e riceve lo stream, conserva la home precedente e tenta il rollback se l'attivazione fallisce.
- **`/var/games`**: subvolume separato dagli snapshot della home, gestito tramite `systemd-tmpfiles` e gruppo `aria-games`.

### Audio

`ariaos-daw-launcher` applica il profilo `latency-performance` soltanto durante la sessione DAW e ripristina automaticamente il profilo precedente. Non vengono usati kernel realtime di terze parti né parametri realtime permanenti.

### Kubernetes

L'immagine include:

- `kubectl`
- Helm
- Minikube
- `kubectx`
- `kubens`
- completamento Bash per kubectl e Minikube

Minikube è destinato al driver Podman rootless già presente. Non viene installato Docker e non viene avviato alcun cluster permanente.

### Node.js

Node.js 24 LTS (con `npm`, `npx` e `corepack`) viene installato dal tarball ufficiale di nodejs.org, con versione e SHA-256 fissati in `versions/external-tools.env`. I pacchetti Fedora sono rimasti indietro rispetto ai requisiti minimi dei tool usati; per aggiornare Node cambiare insieme `NODEJS_VERSION` e `NODEJS_SHA256` (da `SHASUMS256.txt` della release).

## Installazione

Partendo da un sistema Fedora Atomic installato con Btrfs e LUKS2:

```bash
sudo bootc switch ghcr.io/holden093/ariaos:latest
sudo reboot
```

Dopo il primo avvio, aggiungere l'utente ai gruppi richiesti:

```bash
sudo usermod -aG wheel,realtime,audio,aria-games,libvirt "$USER"
```

Terminare la sessione o riavviare affinché i nuovi gruppi siano applicati.

Per associare il volume root al TPM usando PCR 7, sostituire il device con quello reale verificato tramite `lsblk`:

```bash
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/nvme0n1p3
```

PCR 8 e 9 non sono adatti a questo sistema: aggiornamenti `bootc` modificano kernel, riga di comando e initramfs e causerebbero richieste ricorrenti della passphrase di recupero.

## Struttura del repository

```text
Containerfile                 orchestrazione degli stage di build
build_files/                  filesystem finale dichiarativo
scripts/build/                mutazioni temporanee eseguite durante la build
scripts/validate/             controlli statici e contratto dell'immagine
tests/                        test operativi isolati con comandi simulati
versions/external-tools.env   versioni e checksum degli artefatti upstream
.github/workflows/            build e pubblicazione dell'immagine
AGENTS.md                     invarianti tecnici per gli agenti
```

I moduli in `scripts/build/` vengono montati da uno stage `scratch` e non rimangono nell'immagine finale.

## Sviluppo e validazione

Controlli rapidi:

```bash
./scripts/validate.sh
```

Validazione completa obbligatoria dopo modifiche a `Containerfile`, `build_files/`, moduli di build o dipendenze esterne:

```bash
./scripts/preflight.sh
```

Il preflight:

1. esegue controlli statici e test operativi non distruttivi;
2. costruisce l'intera immagine con Podman;
3. verifica pacchetti, sessione Sway, strumenti, completamenti, servizi e permessi;
4. conferma che componenti ritirati e file di build non siano presenti.

GitHub Actions applica lo stesso contratto `scripts/validate/image.sh` all'immagine costruita.

## Licenza

AriaOS è distribuito secondo GNU GPL v3.0. Consultare [LICENSE](LICENSE).
