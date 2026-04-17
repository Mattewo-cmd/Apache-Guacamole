#!/bin/bash

DB_CONTAINER="guacamoledb"
DB_USER="root"
read -s -p "Mot de passe BDD : " DB_PASS
DB_NAME="guacamole_db"

if [ -z "$1" ]; then
    echo "Usage: $0 [nom_du_groupe]"
    exit 1
fi

GROUP_NAME=$1 # prend la première zone de texte après le nom du script

echo "--- Suppression du groupe Guacamole : $GROUP_NAME ---"

IDS=$(docker exec -i $DB_CONTAINER mysql -u$DB_USER -p$DB_PASS $DB_NAME -N -s -e \
"SELECT g.entity_id, g.user_group_id FROM guacamole_user_group g
 JOIN guacamole_entity e ON g.entity_id = e.entity_id
 WHERE e.name = '$GROUP_NAME' AND e.type = 'USER_GROUP';")

ENTITY_ID=$(echo $IDS | awk '{print $1}')
GROUP_ID=$(echo $IDS | awk '{print $2}')

if [ -z "$ENTITY_ID" ]; then
    echo "Erreur : Le groupe '$GROUP_NAME' n'existe pas."
    exit 1
fi

docker exec -i $DB_CONTAINER mysql -u$DB_USER -p$DB_PASS $DB_NAME <<EOF
SET FOREIGN_KEY_CHECKS=0;
DELETE FROM guacamole_user_group_member WHERE user_group_id = $GROUP_ID;
DELETE FROM guacamole_user_group_permission WHERE affected_user_group_id = $GROUP_ID OR entity_id = $ENTITY_ID;
DELETE FROM guacamole_connection_permission WHERE entity_id = $ENTITY_ID;
DELETE FROM guacamole_connection_group_permission WHERE entity_id = $ENTITY_ID;
DELETE FROM guacamole_system_permission WHERE entity_id = $ENTITY_ID;
DELETE FROM guacamole_user_group_attribute WHERE user_group_id = $GROUP_ID;
DELETE FROM guacamole_user_group WHERE user_group_id = $GROUP_ID;
DELETE FROM guacamole_entity WHERE entity_id = $ENTITY_ID;
SET FOREIGN_KEY_CHECKS=1;
EOF

if [ $? -eq 0 ]; then
    echo "Succès : Le groupe '$GROUP_NAME' a été supprimé."
else
    echo "Erreur lors de la suppression."
fi
