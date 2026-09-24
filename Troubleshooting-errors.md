# Troubleshooting & Error Resolution Guide — Pirates Bay Local AI

Guide de diagnostic rapide et de résolution des erreurs courantes pour l'environnement **PiratesBayLocalAI**.

---

## 🔍 Procédure de Diagnostic IA

Lorsqu'un problème survient sur une machine cible, exécutez d'abord le script d'environnement :
```bash
./check-environment.sh
```
Identifiez ensuite l'erreur ci-dessous pour appliquer les requêtes de correction.

---

## 🛠️ Matrice des Erreurs & Requêtes de Résolution

### Erreur 1 : Démon Docker inactif ou accès refusé (`Cannot connect to the Docker daemon`)

* **Symptôme :** `docker ps` retourne `Permission denied` ou `Is the docker daemon running?`.
* **Diagnostic :**
  ```bash
  sudo systemctl status docker
  groups $USER
  ```
* **Requêtes de résolution :**
  ```bash
  # Démarrer le service Docker
  sudo systemctl enable --now docker

  # Ajouter l'utilisateur courant au groupe docker
  sudo usermod -aG docker $USER
  newgrp docker
  ```

---

### Erreur 2 : Moteur LLM Lemonade / vLLM injoignable (Port `13305` ou `8000`)

* **Symptôme :** `curl http://localhost:13305/v1/models` échoue ou retourne `Connection refused`.
* **Diagnostic :**
  ```bash
  sudo systemctl status lemonade.service || sudo systemctl status vllm.service
  journalctl -u lemonade.service -n 50 --no-pager
  ```
* **Requêtes de résolution :**
  ```bash
  # Redémarrer le service d'inférence LLM
  sudo systemctl restart lemonade.service
  
  # Vérifier que le port écoute à nouveau
  curl -s http://localhost:13305/v1/models
  ```

---

### Erreur 3 : Modèle `Qwen Coder` non détecté dans Lemonade

* **Symptôme :** Lemonade répond `200 OK`, mais la liste des modèles est vide ou ne contient pas `Qwen3-Coder-30B-A3B-Instruct-GGUF`.
* **Diagnostic :**
  ```bash
  ls -la ~/.cache/lemonade/models/ || ls -la /var/lib/lemonade/models/
  ```
* **Requêtes de résolution :**
  ```bash
  # Exécuter le script de téléchargement/préchargement des modèles
  bash download-models.sh --model Qwen3-Coder-30B-A3B-Instruct-GGUF
  ```

---

### Erreur 4 : Configuration OpenCode CLI manquante ou invalide (`~/.config/opencode/config.json`)

* **Symptôme :** `opencode` retourne une erreur d'authentification ou ne se connecte pas au bon port.
* **Diagnostic :**
  ```bash
  cat ~/.config/opencode/config.json
  ```
* **Requête de résolution :**
  ```bash
  mkdir -p ~/.config/opencode
  cat << 'EOF' > ~/.config/opencode/config.json
  {
    "$schema": "https://opencode.ai/config.schema.json",
    "provider": "openai",
    "options": {
      "baseURL": "http://localhost:13305/v1",
      "apiKey": "lemonade",
      "model": "Qwen3-Coder-30B-A3B-Instruct-GGUF"
    },
    "execution": {
      "approval": "auto",
      "timeout": 300
    }
  }
  EOF
  ```

---

### Erreur 5 : Le conteneur Sandbox Docker plante ou est interrompu (`OOMKilled` / Mémoire)

* **Symptôme :** Le conteneur `pirates-bay-sandbox` s'arrête brutalement lors de l'exécution de code IA.
* **Diagnostic :**
  ```bash
  docker inspect pirates-bay-sandbox --format='{{.State.OOMKilled}}'
  docker logs --tail 50 pirates-bay-sandbox
  ```
* **Requêtes de résolution :**
  ```bash
  # Redémarrer la sandbox Docker
  docker compose down && docker compose up -d
  ```

---

### Erreur 6 : Échec de clonage/push Git (Authentification GitHub)

* **Symptôme :** `fatal: Could not read from remote repository` ou `HTTP 403`.
* **Diagnostic :**
  ```bash
  gh auth status
  ```
* **Requêtes de résolution :**
  ```bash
  gh auth login --web
  ```
