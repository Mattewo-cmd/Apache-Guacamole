# Documentation d'Installation : Apache Guacamole (Bastion)

**Contexte :** Mettre en place un serveur Bastion pour sécuriser les accès RDP/SSH des intervenants externes, sans divulguer les identifiants administrateurs. Le Bastion sera isolé dans une DMZ avec journalisation et captures vidéos des sessions.

---

## 1. Préparation et installation

### 1.1 Installation ISO
* **OS :** Debian 13.1 (Adapter selon la version stable actuelle(LTS)).
* Vérifier l’intégrité de l’image ISO avant installation.
* Lancer l’installation standard.

### 1.2 Paramétrages réseau
* **IP :** `{IP}/{CIDR}`
* **Gateway :** `{Adresse_IP_Gateway}`
* **Serveur DNS :** `{Windows_Server_rôle_DNS}`
* **Nom FQDN :** `{nom_DNS_du_server}.{nom_de_domaine}`

### 1.3 Configuration machine
* Joindre le poste au domaine (Domaine AD).
* Définir les utilisateurs (ex: `root`, `test`, etc.).

### 1.4 Gestion du disque
* Mise en place du partitionnement avec **LVM**.
* Points de montage recommandés : `/home`, `/var`, `/tmp` sur des partitions séparées.

### 1.5 Extension de partition
Se référer à la documentation interne : [Étendre un disque LVM](./Extend_Part.md).

### 1.6 Renommer un volume group (VG)

Se référer à la documentation interne : [Renommer un VG (Volume Groupe) LVM](./Rename_VG.md)


### 1.7 Configuration des agents et du pare-feu
* Déployer les agents machine (Veeam, Supervision, etc.).
* Ajouter les règles nécessaires au pare-feu.
* Vérifier la communication avec Internet et le Serveur DNS.

### 1.8 Renommer un volume group (VG)

Se référer à la documentation interne : [Désactiver / Réinitialiser le MFA d'un utilisateur](./Lock_TOTP.md)

---

## 2. Installation et configuration d’Apache Guacamole

### 2.1 Prérequis
* Serveur sous Linux (Debian 13).
* Accès administrateur (`root` ou `sudo`).
* Répertoire d'installation pour les conteneurs préparé.

### 2.2 Installation de Docker
1.  Installation des dépendances :
    ```bash
    sudo apt-get install apt-transport-https ca-certificates curl gnupg2 software-properties-common
    ```
2.  Ajouter le dépôt officiel Docker :
    ```bash
    curl -fsSL [https://download.docker.com/linux/debian/gpg](https://download.docker.com/linux/debian/gpg) | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] [https://download.docker.com/linux/debian](https://download.docker.com/linux/debian) $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list

    apt-get update
    ```
3.  Installation des paquets Docker :
    ```bash
    apt-get install docker-ce docker-ce-cli containerd.io
    ```
4.  Activation au démarrage :
    ```bash
    systemctl enable docker
    ```

### 2.3 Mise en place des conteneurs (Initialisation BDD)

1.  Créer le dossier d'installation :
    ```bash
    mkdir -p /opt/guacamole
    cd /opt/guacamole
    ```
2.  Récupérer les images Docker (Versions : Guacamole v1.6.0, MySQL v9.4.0) :
    ```bash
    docker pull guacamole/guacamole:latest
    docker pull guacamole/guacd:latest
    docker pull mysql:latest
    ```
3.  Générer le script d'initialisation SQL :
    ```bash
    docker run --rm guacamole/guacamole:latest /opt/guacamole/bin/initdb.sh --mysql > initdb.sql
    ```
4.  Créer un `docker-compose.yml` temporaire pour la BDD :
    ```yaml
    services:
      guacdb:
        container_name: guacamoledb
        image: mysql:9.4.0
        restart: always
        environment:
          MYSQL_ROOT_PASSWORD: "mdproot"
          MYSQL_DATABASE: "guacamole_db"
          MYSQL_USER: "mysql"
          MYSQL_PASSWORD: "mdpmysql"
        volumes:
          - './db-data:/var/lib/mysql'
    volumes:
      db-data:
    ```
5.  Lancer la BDD et l'initialiser :
    ```bash
    docker compose up -d
    docker cp initdb.sql guacamoledb:/initdb.sql
    docker exec -it guacamoledb bash -c "cat /initdb.sql | mysql -u root -p'mdproot' guacamole_db"
    ```
6.  Arrêter le conteneur :
    ```bash
    docker compose down
    ```

### 2.4 Configuration (Docker Compose)

Créer le fichier `docker-compose.yml` complet.

> **Note :** `TOTP_ENABLED: "true"` active le MFA. Lors de la première connexion, un QR Code s'affichera pour configurer une app Authenticator. Cela permet d'alléger le filtrage IP sur le FortiWeb.

```yaml
services:
  guacdb:
    container_name: guacamoledb
    image: mysql:9.4.0
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: "mdproot"
      MYSQL_DATABASE: "guacamole_db"
      MYSQL_USERNAME: "mysql"
      MYSQL_PASSWORD: "mdpmysql"
    volumes:
      - './db-data:/var/lib/mysql'

  guacd:
    container_name: guacd
    image: guacamole/guacd:1.6.0
    restart: always

  guacamole:
    container_name: guacamole
    image: guacamole/guacamole:1.6.0
    restart: always
    expose:
      - "8080"
    environment:
      GUACD_HOSTNAME: "guacd"
      MYSQL_HOSTNAME: "guacdb"
      MYSQL_DATABASE: "guacamole_db"
      MYSQL_USERNAME: "mysql"
      MYSQL_PASSWORD: "mdpmysql"
      # TOTP_ENABLED: "true" # Décommenter pour activer le MFA
    depends_on:
      - guacdb
      - guacd

volumes:
  db-data:
```


Puis relancer le conteneur
```bash
docker compose up -d
```

Et tester la page `http://ip_locale:8080/guacamole`.

## 3. Mise en place HTTPS + redirection HTTP -> HTTPS
(certificat déjà généré)

## 1. Installation et modules Apache
* **Installation apache 2 et démarrage au lancement**
    * `apt install apache2`
    * `systemctl enable apache2`

* **Activation des modules pour utiliser le reverse proxy**
    * `a2enmod proxy proxy_wstunnel proxy_http ssl rewrite`
    * `systemctl restart apache2`

## 2. Création et activation du site
* **Création du site en fichier `.conf`**
    * `nano /etc/apache2/sites-available/guacamole.conf`

* **Activation du site**
    * `a2ensite guacamole.conf`
    * `systemctl reload apache2`

* **Désactiver la page par défaut (la 80)**
    * *(Default) Pour éviter conflit avec docker et guacamole*
    * `a2dissite 000-default.conf`

* **Vérification**
    * Configuration finie, tester le site en 80 pour la redirection
    * puis en 443 pour voir s'il fonctionne

## 3. Exemple de Configuration (Reverse Proxy)

* **Schéma :** `nom du site` -> `Contenu` -> `backend`

### Fichier guacamole.conf

# Redirection de HTTP (80) vers HTTPS (443)
```apache
<VirtualHost *:80>
    Servername {FQDN-Serveur}
    Redirect permanent / https://{page-du-site-active}/
</VirtualHost>

# Configuration du reverse proxy en HTTPS

<VirtualHost *:443>
    Servername {FQDN-Serveur}

    # Redirige le /guacamole
    SSLEngine On
    SSLCertificateFile {lien vers certificat.cer}
    SSLCertificateKeyFile {lien vers clé_privée.key}

    # Proxy principal
    ProxyPass / {IP_Conteneur}:8080/guacamole/ flushpackets=on
    ProxyPassReverse / {IP_Conteneur}:8080/guacamole/

    # Configuration spécifique pour Guacamole (websocket)
    <Location /websocket-tunnel>
        Order allow,deny
        Allow from all
        ProxyPass ws://{IP_Conteneur}:8080/guacamole/websocket-tunnel
        ProxyPassReverse ws://{IP_Conteneur}:8080/guacamole/websocket-tunnel
    </Location>
</VirtualHost>
```

## 4. Mise en place dossier de record pour les enregistrements vidéos RDP

### 1. Modification du fichier `docker-compose.yml`

Ajout sous les sections `services:` -> `guacamole:` et `guacd:` :

```yaml
services:
  guacdb:
    container_name: guacamoledb
    image: mysql:9.4.0
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: "mdproot"
      MYSQL_DATABASE: "guacamole_db"
      MYSQL_USERNAME: "mysql"
      MYSQL_PASSWORD: "mdpmysql"
    volumes:
      - './db-data:/var/lib/mysql'

  guacd:
    container_name: guacd
    image: guacamole/guacd:1.6.0
    restart: always
    volumes:
      - /opt/guacamole/recordings:/var/lib/guacamole/recordings:rw

  guacamole:
    container_name: guacamole
    image: guacamole/guacamole:1.6.0
    restart: always
    expose:
      - "8080"
    environment:
      GUACD_HOSTNAME: "guacd"
      MYSQL_HOSTNAME: "guacdb"
      MYSQL_DATABASE: "guacamole_db"
      MYSQL_USERNAME: "mysql"
      MYSQL_PASSWORD: "mdpmysql"
      TOTP_ENABLED: "true"
      RECORDING_ENABLED: "true"
    volumes:
      - /opt/guacamole/recordings:/var/lib/guacamole/recordings:ro
    depends_on:
      - guacdb
      - guacd

volumes:
  db-data:
```
### 2. Donner les bons droits pour lire/écrire dans le `/recordings`
* Les droits se mettent sur l'hôte alors qu'ils seront associés aux utilisateurs dans les conteneurs, en l'occurrence donner les droits écritures et lectures à l'utilisateur guacd, c'est lui qui fera les records des vidéos.
* Pour le savoir, se diriger directement sur le conteneur en question, et regarder l'UID et GID besoin.

Commande pour aller en session interactive sur le conteneur choisi : 
```bash
docker exec -it <container> sh
```

Lister les UID et GID du conteneur : 

```bash
cat /etc/passwd
```

Pour le dossier `/recordings` on doit changer les owner (Group et Utilisateur), pour cela on va mettre en Owner l'utilisateur guacd et groupe guacamole, si on fait les commandes précédentes, on remarque l'UID de guacd(1000) et le GID de guacamole(1001).

* Changer alors les owners via la commande associée

```bash
chown -R 1000:1001 /opt/guacamole/recordings
```

Ensuite on associe les droits lectures / écritures : 
```bash
chmod -R 2750 /opt/guacamole/recordings
```

Après cela, les enregistrements vidéos devraient être créés et lisibles.

## 5. Changement de la page de login pour une meilleure vue

### 1. Objectifs
* Mettre le titre : "`Bienvenue sur l'accès prestataire`"
* Changer le numéro de version par le nom : "`Groupe CGO`"
* Implémenter le logo CGO
* Mettre le fond de page fourni

### 2. Trouver le dossier avec les éléments de base

Pour ce serveur, étant donné qu'il est mis en place avec Docker, les éléments pour modifier les pages de Guacamole se retrouvent dans un conteneur, ce qui fait que si on modifie dans le conteneur directement, les changements ne seront pas persistants.

Pour palier à ça, nous devons récupérer l'archive `guacamole.war` sur l'hôte, qui est située dans le dossier `guacamole:/opt/guacamole/webapp/`

```bash
docker cp guacamole:/opt/guacamole/webapp/guacamole.war /opt/guacamole
```

Après avoir récupéré l'archive, nous devons la décompresser, pour cela j'utiliserai unzip.

```bash
apt install -y unzip zip #installation de zip pour la suite
```

Pour ne pas se perdre dans mes fichiers, je ferai l'extraction dans un dossier `guac_extract`

```bash
mkdir guac_extract
unzip guacamole.war ./guac_extract
cd guac_extract
```

### 3. Modifier le texte de la page de login

Suite à l'extraction, on se retrouve avec plusieurs fichiers/dossiers, celui qui nous permettra de modifier notre page login sera `templates.js`, ce script en JS créé les pages grâce aux templates fournis dans le dossier, par exemple pour la page de login, le template se trouve en `./app/login/templates/login.html`

Pour changer le texte de cette page nous devrons donc ouvrir `templates.js` avec un éditeur de texte tel que nano ou encore vim.

```bash
nano ./templates.js
```

Ensuite, on cherchera une ligne bien spécifique dans ce fichier : 

```JS
$templateCache.put('app/login/templates/login.html'...
```

Dans cette ligne se trouve toute la page html, où on peut y modifier directement les informations nécessaires.

Pour modifier le titre dans notre exemple, on modifiera cette partie 
```html
<div class="app-name"> {{\'APP.NAME\' | translate}} </div>
``` 

en

```html
<div class="app-name"> Bienvenue sur l\'accès prestataire </div>
``` 

Et pour le numéro de version, on modifiera 

```html
<div class="version-number">{{\'APP.VERSION\' | translate}}</div>
```
en 

```html
<div class="version-number"> Groupe CGO </div>
```
### 4. Modifier le logo et le fond de la page de login

Tout d'abord, importer le logo et le fond de page dans le dossier `images/` du dossier compressé.

#### 1. Modifier le logo

Pour pouvoir modifier le logo ainsi que le fond de page, on doit modifier le fichier `.css` qui se trouve aussi dans le dossier décompressé, il est nommé sous la forme "`1.guacamole.{hash}.css`".

```bash
nano ./1.guacamole.{hash}.css
```

Une fois sur l'éditeur de texte, chercher `guac_tricolor.svg` qui est le nom du logo de base sur Guacamole, donc soit renommer son propre logo à ce nom la, soit remplacer l'ancienne valeur par le nouveau nom de son logo, et pour adapter le logo, il faut supprimer toute la variable `.login-ui .login-dialog .logo` et ensuite ajouter à la place celle ci :

```css
.login-ui .login-dialog .logo {display: block;margin: .5em auto;width: 200px;height: 100px;background-size: 200px;-moz-background-size: px 100px;-webkit-background-size: px 100px;-khtml-background-size: px 100px;background-image: url(images/guac-tricolor.svg)}
```

#### 2. Modifier le fond de page

Pour modifier le fond de page, toujours dans le fichier .css, il faut modifier la variable div.login-ui y supprimer une ligne, et en rajouter deux.

Ligne à supprimer : 

```bash
background: #fff;
```

Lignes à ajouter : 

```bash
background-image: url('images/{fond de page}.jpg'); background-size: cover;
```

Les paramètres peuvent être adaptés comme on le souhaite.

### 5. Compression du dossier modifié + mappage du dossier

#### 1. Compression du dossier modifié

Après les modifications effectuées, il faudra refaire le dossier compressé  `guacamole.war` pour ensuite le remettre dans le conteneur, on le remettra dans le dossier `/opt/guacamole` en remplacement de l'ancien.

```bash
zip -r ../guacamole.war * #compressé tous les éléments du dossier modifié dans le nouveau dossier guacamole.war
```

#### 2. Mappage du dossier compressé

Pour rendre les nouveaux paramètres persistant, on va mettre en place un mappage du dossier compressé de l'hôte sur celui du conteneur, le mappage fera en sorte que le dossier de l'hôte remplace celui du conteneur.

La mise en place du mappage se fait via le fichier `docker-compose.yml` : 
(fichier hôte:fichier conteneur)
```YML
  guacamole:
    container_name: guacamole
    image: guacamole/guacamole:latest
    restart: always
    expose:
      - "8080"
    environment:
      GUACD_HOSTNAME: "guacd"
      MYSQL_HOSTNAME: "guacdb"
      MYSQL_DATABASE: "guacamole_db"
      MYSQL_USERNAME: "mysql"
      MYSQL_PASSWORD: "mdpmysql"
      TOTP_ENABLED: "true"
      RECORDING_ENABLED: "true"
    volumes:
      - /opt/guacamole/guacamole.war:/opt/guacamole/webapp/guacamole.war #ajouter cette ligne
      - /opt/guacamole/recordings:/var/lib/guacamole/recordings:ro
```

Redémarrer les conteneurs et tester si le mappage fonctionne bien.

```bash
docker compose && docker compose up -d
```

## 6. Export / Import des connexions 

Lors d'une montée de version ou alors une refonte totale du système Bastion, l'export et l'import des connexions ainsi que leurs paramètres peuvent être nécessaires, pour cela, deux scripts `bash` pour les deux actions, qui vont donc chercher les informations dans la base de données SQL, et les écrire dans un fichier en `.sql`, à l'inverse, le script prend les informations du `.sql` et va les écrire dans la nouvelle base de données.

### 1. Script d'export base de données

script `export_bdd.sh` : 

```bash
#!/bin/bash
#Configuration
CONTAINER_DB="guacamoledb"
DB_NAME="guacamole_db"
DB_USER="mysql"
DB_PASS="mdpmysql"
DATE=$(date +"%Y-%m-%d_%H-%M")
EXPORT_FILE="/opt/guacamole/backups/guac_export_${DATE}.sql"

echo "📦 Export des connexions Guacamole..."
echo "🕒 Date : $DATE"
echo "📁 Destination : $EXPORT_FILE"

#Commande d’export
docker exec -i "$CONTAINER_DB" \
mysqldump --no-tablespaces -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" \
guacamole_connection \
guacamole_connection_parameter \
guacamole_connection_permission \
guacamole_sharing_profile \
guacamole_sharing_profile_parameter \
> "$EXPORT_FILE"

#Vérifie le succès de l’export
if [ $? -eq 0 ]; then
  echo "✅ Export SQL terminé avec succès."
else
  echo "❌ Erreur lors de l’export SQL."
  exit 1
fi
```

Ce script va créer un fichier `.sql` avec les informations dans le dossier `export_bdd/` sous un nom constitué de la date + heures/minutes.

### 2. Script d'import base de données

script `import_bdd.sh` :

```bash
#!/bin/bash
#Configuration
CONTAINER_DB="guacamoledb"
DB_NAME="guacamole_db"
DB_USER="mysql"
DB_PASS="mdpmysql"
IMPORT_DIR="/opt/guacamole/export_bdd"
LATEST_EXPORT=$(ls -t ${IMPORT_DIR}/guac_export_*.sql* 2>/dev/null | head -n 1)

#Vérifications
if [ -z "$LATEST_EXPORT" ]; then
  echo "❌ Aucun fichier de sauvegarde trouvé dans $IMPORT_DIR"
  exit 1
fi

echo "📥 Import des connexions Guacamole..."
echo "📁 Fichier détecté : $LATEST_EXPORT"

#Import dans la base
echo "⚙️  Import du fichier SQL dans la base..."
docker exec -i "$CONTAINER_DB" mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$LATEST_EXPORT"

if [ $? -eq 0 ]; then
  echo "✅ Import terminé avec succès."
else
  echo "❌ Erreur lors de l’import."
  exit 1
fi

echo "✅ Base Guacamole mise à jour avec succès."
```

## 7. Mise en place de la purge mensuelle du dossier recordings pour éviter la saturation

Cette étape permet de supprimer automatiquement les enregistrements vidéos vieux de plus de 30 jours afin de ne pas saturer l'espace disque du serveur.

### 7.1 Création du script de purge

1.  Créer le fichier script dans `/usr/local/sbin/` :
    ```bash
    nano /usr/local/sbin/purge_guac_record.sh
    ```

2.  Copier le contenu suivant :
    ```bash
    #!/bin/bash
    # Script de purge des anciens enregistrements Guacamole

    # Dossier à nettoyer
    DIR="/opt/guacamole/recordings"

    # Supprime les fichiers de plus de 30 jours
    find "$DIR" -type f -mtime +30 -exec rm -f {} \;

    # Supprime les dossiers vides restants
    find "$DIR" -type d -empty -delete

    exit 0
    ```

3.  Rendre le script exécutable :
    ```bash
    chmod +x /usr/local/sbin/purge_guac_record.sh
    ```

### 7.2 Automatisation avec Crontab

1.  Ouvrir l'éditeur crontab :
    ```bash
    crontab -e
    ```

2.  Ajouter la ligne suivante à la fin du fichier pour lancer le script une fois par mois :
    ```cron
    @monthly /usr/local/sbin/purge_guac_record.sh >/var/log/purge-guac.log 2>&1
    ```
    > **Note :** Cette configuration redirige les logs d'exécution (succès et erreurs) vers `/var/log/purge-guac.log`.


## 8. Configuration Guacamole derrière un Reverse Proxy (Docker)

Ce document explique les variables d'environnement essentielles pour garantir la sécurité et le bon fonctionnement d'Apache Guacamole lorsque celui-ci est placé derrière un reverse proxy (comme Apache, ou la passerelle Docker).


### 8.1 Correction de l'identification de l'IP Source

Lorsque Guacamole est dans un conteneur derrière un proxy, il identifie tous les utilisateurs par l'adresse IP du proxy (`172.18.0.1`) et non par leur véritable adresse IP.

L'ajout des variables suivantes active la fonctionnalité **`RemoteIpValve`** de Tomcat, forçant le serveur à lire l'en-tête **`X-Forwarded-For`** pour déterminer la véritable IP du client. Les lignes à ajouter, se mettent dans la partie `guacamole:` du `docker-compose.yml`.

### Configuration dans `docker-compose.yml`

| Variable | Valeur d'exemple | Description |
| :--- | :--- | :--- |
| **`REMOTE_IP_VALVE_ENABLED`** | `"true"` ou `"false"` | Active la `RemoteIpValve` de Tomcat. **Indispensable** pour lire l'IP réelle fournie par le proxy. |
| **`REMOTE_IP_VALVE_INTERNAL_PROXIES`** | `"172\\.18\\.0\\.1"` | Indique à Guacamole que l'IP spécifiée est un proxy de confiance. Cette IP sera ignorée lors du bannissement, permettant de cibler l'IP du client final (e.g., `10.10.10.X`). |

### Objectif

L'objectif est que les logs et les mécanismes de sécurité de Guacamole voient : **`{IP_Client}`** (l'utilisateur) et non **`172.18.0.1`** (le conteneur/passerelle).

---

### 8.2 Gestion des tentatives d'authentification échouées (Anti Brute-Force)

Ces règles sont configurables via de simples variables d'environnement Docker.


#### Ajout au `docker-compose.yml` : 

Pour que cette configuration soit prise en compte, il faut ajouter dans la partie `guacamole:` :

```bash
BAN_MAX_INVALID_ATTEMPTS: "10"       # Augmente la limite de 5 à 10
BAN_ADDRESS_DURATION: "900"          # Définit le ban à 15 minutes (900s)
```

## 9. Mise en place d'un lecteur réseau sur la machine RDP

Cette partie explique comment mettre en place un lecteur réseau entre le serveur où nous sommes connectés et le guacamole, ce qui pourra nous permettre d'envoyer et/ou télécharger des fichiers entre notre hôte et le serveur en RDP.

### 9.1 Création du dossier de partage et ses sous-dossiers.

Sous **`/opt/guacamole`** on va créer un dossier **`share`**, qui sera donc notre dossier principal pour les lecteurs, ensuite on se rend dans ce dossier, et on y créera les sous-dossiers nommés pour chaque service, par exemple un sous-dossier `Compta`.

```bash
mkdir -p /opt/guacamole/share/Compta 
```

Ensuite il faut penser à attribuer les bons droits, que soit l'owner du dossier share, mais aussi les droits en R+W+X

```bash
chown -R 1000:1000 /opt/guacamole/share #1000 est l'UID de l'utilisateur guacd
chmod -R 2700 /opt/guacamole/share #2 attribue les droits sur tous les sous-dossiers
```

### 9.2 Mappage du dossier sur l'hôte serveur et le dossier dans le conteneur.
Pour cette partie, il faudra modifier le `docker-compose.yml` et y ajouter une ligne au service `guacd:` et sous `volumes:` bien sûr en lecture/écriture.

### Nouveau fichier `docker-compose.yml` : 

```YML
guacd:
  container_name: guacd
  image: guacamole/guacd:1.6.0
  restart: always
  volumes:
    - /opt/guacamole/recordings:/var/lib/guacamole/recordings:rw
    - /opt/guacamole/share:/opt/guacamole/share:rw # Ligne à ajouter
```

## 10. Ordonnancement au redémarrage

Lors de l'installation, j'ai pu remarquer que lors du lancement des conteneurs au démarrage du poste, la page web ne chargeait pas par moment, et en fait je me suis rendu compte que c'était parce que lors du lancement des conteneurs, le conteneur de la base de données n'était pas complétement initialisé, sauf que vu que le conteneur contenant la page web en a besoin, il plantait et n'essayait pas de recontacter la BDD.

### 1. Solution

Pour palier à ce problème, ma solution va être de mettre en place un service qui se démarre une seule fois au démarrage du poste, qui va lancer un script faisant bien le redémarrage des conteneurs, ce qui permettra à la base de données de bien s'initialiser.

### 2. Mise en place du script de redémarrage des conteneurs

Script `/usr/local/bin/start_guacamole.sh` : 

```bash
#!/bin/bash
cd /opt/guacamole || exit 1 #dossier où se trouve le conteneur et teste une fois de s'y rendre et sinon coupe le script
/usr/bin/docker compose down #stop les conteneurs
/usr/bin/docker compose up -d #redémarre les conteneurs
```
On met les droits d'exécution au script : 

```bash
chmod +x /usr/local/bin/start_guacamole.sh
```

### 3. Création du service qui va lancer le script 

Créer le service `/etc/systemd/system/guacamole.service` : 

```ini
[Unit]
Description = Redémarrage Guacamole Docker
# S'exécute après le lancement du réseau et de docker
After = network-online.target docker.service
Wants = network-online.target

[Service]
Type = oneshot #éxecute une fois le service
ExecStart = /usr/local/bin/start_guacamole.sh # Chemin vers notre script
RemainAfterExit = yes # Le service est considéré comme actif même après l'exécution du script
User = root
WorkingDirectory = /opt/guacamole # Spécifie le répertoire de travail où se trouve le docker-compose.yml

[Install]
WantedBy = multi-user.target
```

Recharger le systemd

```bash
systemctl daemon-reload
```

Lancer le service + lancement au démarrage du serveur

```bash
systemctl start guacamole.service
```
```bash
systemctl enable guacamole.service
```

