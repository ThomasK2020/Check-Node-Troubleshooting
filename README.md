# Check-Node-Troubleshooting

Toolkit centralisé d'audit, d'auto-réparation (self-healing) et de consignation des erreurs pour postes de travail et serveurs IA locaux (**Lemonade**, **vLLM**, **Qwen Coder**, **OpenCode CLI**, **Hermes Agent**).

---

## 🚀 Vue d'ensemble

**`Check-Node-Troubleshooting`** est un dépôt indépendant conçu pour être déployé sur n'importe quel nœud ou poste de travail Linux. Il permet d'auditer l'environnement, de corriger automatiquement les erreurs de configuration et de remonter les logs d'erreurs enrichis (date, nom d'hôte, utilisateur) vers un tampon Git centralisé accessible par **Hermes Agent**.

---

## 🧰 Fichiers & Outils Inclus

| Fichier / Script | Rôle & Description |
|---|---|
| `check-environment.sh` | Script d'audit rapide de l'environnement hôte (Python, Git, Docker, Lemonade/vLLM, Qwen Coder, OpenCode, Hermes). |
| `node-agent.sh` | Agent nœud polyvalent : audit JSON (`--status`), auto-réparation (`--fix`), enregistrement d'erreur (`--log-error`). |
| `Node-Troubleshooting-error.md` | Fichier tampon centralisé recevant les rapports d'erreurs poussés par les nœuds distants. |
| `Troubleshooting-errors.md` | Guide de diagnostic et matrice des commandes CLI pour résoudre les pannes courantes. |

---

## 💻 Quick Start : Déploiement sur un Nœud Cible

Sur la machine distante à vérifier ou réparer :

```bash
git clone https://github.com/ThomasK2020/Check-Node-Troubleshooting.git
cd Check-Node-Troubleshooting
chmod +x *.sh

# 1. Vérifier l'environnement hôte
./check-environment.sh

# 2. Lancer l'auto-réparation si des avertissements sont détectés
./node-agent.sh --fix

# 3. Transmettre un rapport d'erreur vers GitHub
./node-agent.sh --log-error "Description ou log du problème" --push
```

---

## 📡 Pilotage Distant & Workflow d'Assistance IA (Hermes)

```text
 ┌─────────────────────────┐               ┌──────────────────────────┐
 │  Nœud Distant (Workstation) │               │   Poste de Pilotage /    │
 │                         │               │      Hermes Agent        │
 │ ./node-agent.sh         │               │                          │
 │   └─ --log-error --push ┼──────────────►│ Inspecte & Analyse :     │
 └─────────────────────────┘  GitHub Repo  │ Node-Troubleshooting-    │
                              (Tampon Git) │ error.md                 │
 ┌─────────────────────────┐               │                          │
 │  Nœud Distant (Fix)     │               │ Émet les requêtes de    │
 │ ./node-agent.sh --fix   │◄──────────────┼─ correction à distance   │
 └─────────────────────────┘   (SSH / Git) └──────────────────────────┘
```

1. **Rapport d'Erreur :** Le nœud cible consigne l'erreur via `./node-agent.sh --log-error "log..." --push`.
2. **Inspection IA :** Hermes Agent lit `Node-Troubleshooting-error.md` sur GitHub, extrait le `hostname`, la `date`, le `user` et le message d'erreur.
3. **Résolution Distante :** Hermes ou l'administrateur déclenche `./node-agent.sh --fix` à distance (ou via SSH) pour résoudre le problème.

---

## 📖 Contenu d'une Entrée d'Erreur (`Node-Troubleshooting-error.md`)

```markdown
### 🚨 [2026-09-24 12:22:24 CEST] Node: Z2Mini-Node2 (User: hp-amd-localai)

* **Date & Heure :** `2026-09-24T10:22:24Z`
* **Machine (Hostname) :** `Z2Mini-Node2`
* **Utilisateur :** `hp-amd-localai`
* **Message / Rapport d'Erreur :**
```text
[CHECK] OpenCode CLI ... WARN (opencode CLI not found in PATH)
```
```
