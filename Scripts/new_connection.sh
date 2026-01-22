####################################################################################
# Description du script : Job bash qui créer une nouvelle connexion à un serveur.
#
#_Ver_|_Modifie_le_|_Par_|_Objet___________________________________________
#     |            |     |
#     |            |     | 
# 1.0 | 10/12/2025 | MLE | Création du script
#     |            |     | 
####################################################################################

#!/bin/bash
# Bien penser à mettre l'utilisateur qui exécute le script dans le groupe "docker" : << usermod -aG docker {USER} >>

CONTAINER_DB="guacamoledb"
U="root"
M="@option.bdd_pass_root@" 
B="guacamole_db"
UMB="-u $U -p$M $B"
TEMP_SQL_FILE="/tmp/guac_conn_$(date +%s).sql"

# ID Groupes
PARENT_ID_RDP=1 # Groupe Windows
PARENT_ID_SSH=3 # Groupe Linux

# Variables de record
RECORDING_PATH_VAR='${HISTORY_PATH}/${HISTORY_UUID}'
TYPESCRIPT_NAME_VAR='${GUAC_DATE}-${GUAC_TIME}'

# Variable globale pour l'ID de la nouvelle connexion (important pour le nettoyage)
CONN_ID=""

# --- Fonction de Suppression de connexion mise en erreur ---
cleanup_and_exit() {
    local error_code=$1
    local file_to_keep=$2

    echo "❌ Erreur critique lors de l'import. Code de sortie: $error_code"

    if [[ -n "$CONN_ID" && "$CONN_ID" =~ ^[0-9]+$ ]]; then
        echo "Tentative de ROLLBACK : Suppression de la connexion ID $CONN_ID..."
        DELETE_CMD="mysql $UMB -e \"DELETE FROM guacamole_connection WHERE connection_id = $CONN_ID;\""
        docker exec "$CONTAINER_DB" /bin/bash -c "$DELETE_CMD"

        if [ $? -eq 0 ]; then
            echo "✅ Suppression réussie : Connexion ID $CONN_ID supprimée de la base."
        else
            echo "🚨 AVERTISSEMENT : Échec de la suppression. La connexion ID $CONN_ID pourrait exister partiellement."
        fi
    fi

    if [ -f "$file_to_keep" ]; then
        echo "Fichier SQL temporaire conservé pour le débogage : $file_to_keep"
    else
        echo "Fichier SQL temporaire non trouvé, impossible de le conserver."
    fi

    exit $error_code
}
# -------------------------------------


# Récupère des infos

echo "--- Création d'une nouvelle connexion Guacamole ---"

#CONN_NAME=@CONN_NAME
#PROTOCOL=@PROTOCOL
read -p "Nom affiché de la connexion : " CONN_NAME
read -p "Protocole (SSH ou RDP) : " PROTOCOL

PROTOCOL=$(echo "$PROTOCOL" | tr '[:upper:]' '[:lower:]')
# Définition du Parent ID
if [[ "$PROTOCOL" == "SSH" || "$PROTOCOL" == "ssh" ]] ; then
    PARENT_ID=$PARENT_ID_SSH
    echo "➡️ Associé au groupe Linux/SSH (ID: $PARENT_ID)."
elif [[ "$PROTOCOL" == "RDP" || "$PROTOCOL" == "rdp" ]] ; then
    PARENT_ID=$PARENT_ID_RDP
    echo "➡️  Associé au groupe Windows/RDP (ID: $PARENT_ID)."
else
    echo "❌ Protocole invalide. Le script s'arrête."
    exit 1
fi


#HOSTNAME=@HOSTNAME
#PORT=@PORT
#USERNAME=@USERNAME
#PASSWORD=@PASSWORD
read -p "Adresse IP/Hostname du serveur (IPv4) : " HOSTNAME
read -p "Port du serveur : " PORT
read -p "Identifiant de l'utilisateur : " USERNAME
read -s -p "Mot de passe de l'utilisateur : " PASSWORD


echo ""

# --- Génération du Fichier SQL ---

echo "--- 📝 Préparation du fichier SQL temporaire : $TEMP_SQL_FILE ---"

# 1. Obtenir le prochain ID de connexion via Docker
LAST_ID_CMD="mysql $UMB -s -N -e \"SELECT COALESCE(MAX(connection_id), 0) + 1 FROM guacamole_connection;\""
CONN_ID=$(docker exec "$CONTAINER_DB" /bin/bash -c "$LAST_ID_CMD")

if [ -z "$CONN_ID" ] || ! [[ "$CONN_ID" =~ ^[0-9]+$ ]]; then
    echo "❌ Erreur: Échec de la détermination de l'ID de connexion."
    exit 1
fi

echo "ID déterminé : $CONN_ID"


# 2. Construction de la requête principale (connection)
# La première insertion est faite séparément pour capturer les erreurs avant d'insérer les paramètres.
CONNECTION_SQL="
INSERT INTO guacamole_connection (connection_id, parent_id, connection_name, protocol)
VALUES ($CONN_ID, $PARENT_ID, '$CONN_NAME', '$PROTOCOL');
"

# --- Insertion de la connexion de base ---
echo "--- 🚀 Insertion de la connexion de base (ID $CONN_ID)... ---"
DOCKER_INSERT_CMD="mysql $UMB -e \"$CONNECTION_SQL\""
docker exec "$CONTAINER_DB" /bin/bash -c "$DOCKER_INSERT_CMD"

if [ $? -ne 0 ]; then
    # L'erreur (ex: Duplicate Entry) est survenue à l'étape 2 on supprime la connection.
    cleanup_and_exit $? "$TEMP_SQL_FILE"
fi

echo "✅ Connexion de base insérée. Continuation avec les paramètres."


# 3. Paramètres de connexion (construction des paramètres dans le fichier SQL temporaire)
SQL_PARAMS_VALUES="
($CONN_ID, 'hostname', '$HOSTNAME'),
($CONN_ID, 'port', '$PORT'),
($CONN_ID, 'username', '$USERNAME'),
($CONN_ID, 'password', '$PASSWORD')
"

# Ajout des paramètres spécifiques au protocole + Enregistrement
if [ "$PROTOCOL" == "ssh" ]; then
    echo "Ajout des paramètres SSH/Typescript..."
    SQL_PARAMS_VALUES+=",
($CONN_ID, 'typescript-path', '$RECORDING_PATH_VAR'),
($CONN_ID, 'typescript-name', '$TYPESCRIPT_NAME_VAR'),
($CONN_ID, 'create-typescript-path', 'true')
"
elif [ "$PROTOCOL" == "rdp" ]; then
    echo "Ajout des paramètres RDP/Enregistrement Écran..."
    SQL_PARAMS_VALUES+=",
($CONN_ID, 'ignore-cert', 'true'),
($CONN_ID, 'security', 'nla'),
($CONN_ID, 'recording-path', '$RECORDING_PATH_VAR'),
($CONN_ID, 'recording-name', 'recordings'),
($CONN_ID, 'create-recording-path', 'true')
"
fi

# 4. Écriture de la requête d'insertion des paramètres dans le fichier SQL (pour un débogage futur)
echo "INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES $SQL_PARAMS_VALUES;" > "$TEMP_SQL_FILE"


# --- 🚢 Insertion des Paramètres via Docker ---
echo "--- 🚢 Insertion des paramètres (ID $CONN_ID)... ---"
docker exec -i "$CONTAINER_DB" mysql $UMB < "$TEMP_SQL_FILE"

if [ $? -ne 0 ]; then
    # L'erreur est survenue lors de l'insertion des paramètres (étape 4). Suppression en cours.
    cleanup_and_exit $? "$TEMP_SQL_FILE"
fi

echo "✅ Import terminé avec succès."
echo "✅ Nouvelle connexion '$CONN_NAME' (ID: $CONN_ID) ajoutée au groupe $PARENT_ID."

# Nettoyage final (Supprime le fichier SQL créé pour l'insertion de la nouvelle connexion).
rm -f "$TEMP_SQL_FILE"

echo "Si le serveur mis en place se trouve dans le VLAN DMZ (20) Connexion OK, s'il se trouve dans un autre VLAN, ajuster les règles de pare-feu."