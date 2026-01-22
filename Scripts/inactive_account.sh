#!/bin/bash

CONTAINER_DB="guacamoledb"
#U=@USER
#M=@PASSWD
#B=@DB
read -p "Utilisateur BDD : " U
read -s -p "Mot de passe BDD : " M
read -s -p "BDD Utilisée : " B

UMB="-u $U -p$M $B"
MAX_INACTIF_JOURS=15
EXCLUSION_LIST=(1,3,4,5,6,11)

echo "--- 🛡️ Vérification de l'Inactivité Guacamole  ---"
echo "Seuil d'inactivité : $MAX_INACTIF_JOURS jours."

# 1. Requête SQL pour identifier les ID des comptes inactifs
SQL_LIST_INACTIVE="
SELECT
    guacamole_user.user_id
FROM
    guacamole_user
LEFT JOIN
    guacamole_user_history ON guacamole_user_history.user_id = guacamole_user.user_id
    AND guacamole_user_history.end_date IS NOT NULL
WHERE
    guacamole_user.disabled = 0 AND
    guacamole_user.user_id NOT IN ($EXCLUSION_LIST)
GROUP BY
    guacamole_user.user_id
HAVING
    MAX(guacamole_user_history.end_date) IS NOT NULL
    AND MAX(guacamole_user_history.end_date) < DATE_SUB(NOW(), INTERVAL $MAX_INACTIF_JOURS DAY);
"

echo "🔎 Recherche des utilisateurs inactifs"
INACTIVE_ID_DATA=$(docker exec "$CONTAINER_DB" mysql $UMB -s -N -e "$SQL_LIST_INACTIVE")

if [ $? -ne 0 ]; then
    echo "❌ Erreur: Échec de la requête de listage des ID inactifs."
    exit 1
fi

# 2. DÉSACTIVATION des IDs inactifs
echo "--- Désactivation des comptes identifiés... ---"
while read -r USER_ID; do

    if [[ -z "$USER_ID" ]]; then
        continue
    fi

    # L'argument -s (silent) et -N (skip column names) sont importants pour n'avoir que le nom.
    ENTITY_NAME=$(docker exec "$CONTAINER_DB" mysql $UMB -s -N -e "SELECT name FROM guacamole_entity WHERE entity_id = (SELECT entity_id FROM guacamole_user WHERE user_id=$USER_ID)")

    if [ $? -ne 0 ] || [ -z "$ENTITY_NAME" ]; then
        ENTITY_NAME="[Nom non trouvé]"
    fi
    # -----------------------------------------------------------------

    echo "   [INACTIF] Désactivation de l'utilisateur $ENTITY_NAME (ID $USER_ID) en cours..."
    SQL_UPDATE="UPDATE guacamole_user SET disabled = 1 WHERE user_id = '$USER_ID';"

    docker exec "$CONTAINER_DB" mysql $UMB -e "$SQL_UPDATE"


done <<< "$INACTIVE_ID_DATA"

# 3. Affiche les IDs désactivés

echo "--- Rapport Final des Utilisateurs désactivés ---"

UTILISATEURS_DESACTIVES=$(docker exec "guacamoledb" mysql $UMB -t -N -e "SELECT guacamole_entity.name AS username FROM guacamole_entity JOIN guacamole_user ON guacamole_entity.entity_id = guacamole_user.entity_id WHERE guacamole_user.disabled = 1;")
echo "$UTILISATEURS_DESACTIVES"