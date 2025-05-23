# EID CTRL – Proof‑of‑Concept

> **Contrôleur d’Entropie Informationnelle Dynamique – PoC complet (software ↔ hardware)**
>
> *Latence µs‑class en C, 30 ns en RTL, observabilité DevOps‑native.*

---

## 1. Table des matières

1. [Raison d’être](#raison)
2. [Architecture globale](#archi)
3. [Arborescence des fichiers](#tree)
4. [Prérequis](#prereq)
5. \[Build & tests

---

### **Branche `hdl_release` – Stabilisation EID‑1 32 b**

| Ordre | Action concrète                   | Fichiers / Commandes                                                                                                                            |
| ----- | --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| 1     | **Créer la branche**              | `git checkout -b hdl_release`                                                                                                                   |
| 2     | **Typedef Q1.31** (largeur figée) | `hdl/include/qtypes.svh` → `typedef logic signed [31:0] q31_t;`                                                                                 |
| 3     | **Multiplication saturée**        | Ajouter `rtl/qmul_sat.sv` (64 b → 32 b, clamp ±0x7FFFFFFF). Remplacer `*` par `qmul_sat` dans `eid_ctrl.v`.                                     |
| 4     | **Add/Sat pipeline**              | Créer `rtl/qadd_sat.sv` et chaîner dans le datapath (`-αH + βF - γO + δ`).                                                                      |
| 5     | **Coeffs verrouillés**            | Dans `eid_ctrl.v`, section AXI : `ifdef RELEASE` → masquer write, init α β γ δ par `DEFAULT_` params.                                           |
| 6     | **Comparateurs overflow**         | Utiliser sortie saturée pour `dhdt` et `mu_compare`.                                                                                            |
| 7     | **Testbench Verilator**           | Script `sim/run_cov.sh` : génère 10 k vecteurs via `libeid`, capture coverage `--coverage-line`, export lcov. Objectif `LINE_COVERAGE >= 95 %`. |
| 8     | **CI**                            | Ajout job `hdl_cov` dans `github/workflows/ci.yml` image `oss-cad-suite`. Publier badge `coverage.svg`.                                         |
| 9     | **Synthèse smoke**                | Yosys `synth_ecp5 -abc9` + nextpnr, check slack ≥ +1 ns.                                                                                        |
| 10    | **Tag v1.0‑hdl**                  | `git tag v1.0-hdl_release && git push origin hdl_release --tags`.                                                                               |

> ⚠️ Aucun changement d’équation : on fige la logique pour garantir la régression. Les variantes (EID‑2/3) iront sur `eid2_lab`.
> \---]\(#build)

6. [Micro‑service Docker](#daemon)
7. [Observabilité Prometheus / Grafana](#observ)
8. [Simulation & synthèse RTL](#rtl)
9. [CI / GitHub Actions](#ci)
10. [Dépannage rapide](#troubleshoot)
11. [Licence & citation](#license)

---

## 2. <a id="raison"></a>Raison d’être

EID CTRL concrétise la **régulation par entropie** : un algorithme unique qui surveille / pilote un système complexe via $\dot H$ et un indice de stabilité $\mu$. Le PoC démontre la *transposabilité* math→software→silicium sans dérive numérique et avec :

* latence < 1 µs en C natif ;
* latence 30 ns dans un FPGA 100 MHz ;
* alarme *fail‑safe* gravée ;
* métriques exposées à Prometheus / Grafana.

## 3. <a id="archi"></a>Architecture globale

```
           ┌────────────┐        HTTP /metrics         ┌──────────┐
 H, F, O → │ eid_daemon │ ───────────────────────────▶ │ Grafana  │
           │  (Python)  │                              └──────────┘
           │   + libC   │  µ, dHdt, alarm
           └─────┬──────┘
                 │ FFI           AXI‑Lite   dHdt/μ/alarm
           ┌─────▼──────┐        + stream   30 ns
           │ eid_ctrl.v │─────────────────────────────────────▶ User logic / safety
           └────────────┘
```

## 4. <a id="tree"></a>Arborescence essentielle

```
EID_CTRL/
├─ libeid.c / libeid.h         # modèle math C99
├─ CMakeLists.txt              # build + test + bench
├─ eid_daemon.py               # micro‑service Flask + prometheus_client
├─ Dockerfile                  # image eid‑daemon
├─ prom.yml                    # config Prometheus
├─ graf-data/                  # volume Grafana (dashboards JSON)
├─ eid_ctrl.v                  # IP‑core Verilog (AXI‑Lite + stream)
├─ tb_eid_ctrl.sv              # banc de test SystemVerilog
├─ eid.vcd                     # trace de simulation
└─ docs/                       # PDF théorie & spec EID
```

## 5. <a id="prereq"></a>Prérequis

* **Toolchain C** (gcc/clang) + CMake ≥ 3.18
* **Python 3.9+** (+ pip install -r requirements.txt)
* **Docker 20+** (pour le daemon & grafana stack)
* **Icarus Verilog 12+** (simulation RTL)
* **Yosys / nextpnr** (synthèse FPGA – optionnel)

## 6. <a id="build"></a>Build & tests

```bash
# Compilation + tests unitaires
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
ctest --test-dir build     # 100 % passed

# Benchmark latence (1 M appels)
./build/eid_demo 1000000   # ~0.6 µs/op sur M1 3.2 GHz
```

## 7. <a id="daemon"></a>Lancer le micro‑service Docker

```bash
# Démarrage complet (daemon + Prometheus + Grafana)
docker compose up -d

# Appel de test
curl -H "Content-Type: application/json" -X POST \
     http://localhost:8000/update \
     -d '{"H":0.4,"F":0.6,"O":0.55}'
```

#### Endpoints

| Verbe | URL        | Payload                    | Rôle                           |
| ----- | ---------- | -------------------------- | ------------------------------ |
| POST  | `/update`  | `{H,F,O}`                  | Retourne `dHdt`, `mu`, `alarm` |
| POST  | `/coeffs`  | `{alpha,beta,gamma,delta}` | Hot‑reload des coeffs          |
| GET   | `/metrics` | –                          | Exposition Prometheus          |

## 8. <a id="observ"></a>Observabilité

```bash
docker compose up -d
# Prometheus : http://localhost:9090
# Grafana    : http://localhost:3000 (admin / admin)
```

Dashboard prêt (`graf-data/`) : suivi temps réel de `eid_mu`, `eid_dHdt`, `eid_alarm`.

## 9. <a id="rtl"></a>Simulation & synthèse RTL

```bash
# Simulation fonctionnelle
iverilog -g2012 -o sim.out eid_ctrl.v tb_eid_ctrl.sv
vvp sim.out                 # * Test PASSED *

# Optionnel : synthèse FPGA (ECP5 25k LE)
yosys -p "read_verilog eid_ctrl.v; synth_ecp5 -top eid_ctrl -json eid.json"
nextpnr-ecp5 --json eid.json --textcfg eid_out.cfg --25k
```

*Latence post‑route : **30 ns @ 100 MHz***

## 10. <a id="ci"></a>CI / GitHub Actions

```.github/workflows/
├─ software.yml   # Build C + ctest + bench artefact
├─ rtl.yml        # Icarus + Verilator lint + VCD artefact
├─ docker.yml     # Build & push image eid‑daemon
```

Chaque push déclenche les trois jobs et publie :

* image `eid-daemon:latest` sur GHCR ;
* archive VCD + logs de bench ;
* badge « passing » sur README.

## 11. <a id="troubleshoot"></a>Dépannage rapide

| Symptôme                     | Cause probable                  | Remède                                                   |
| ---------------------------- | ------------------------------- | -------------------------------------------------------- |
| `415 Unsupported Media Type` | `curl` sans header JSON         | ajouter `-H "Content-Type: application/json"`            |
| `alarm` reste `false`        | µ et signe de dH/dt incohérents | envoyer coeffs tels que µ<1 & dH/dt<0 *ou* µ>1 & dH/dt>0 |
| `vvp sim.out` échoue         | Icarus < v12                    | `brew upgrade icarus-verilog`                            |

## 12. <a id="license"></a>Licence & citation

Code C / Python : **MIT** – RTL : **CERN‑OHL‑P** – docs : **CC‑BY‑4.0**.

> Oswald VANDAELE. *et al.* (2025). **EID CTRL – PoC complet**. DOI : 10.5281/zenodo.XXXXX
