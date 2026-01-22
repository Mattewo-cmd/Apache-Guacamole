####################################################################################
# Description du script : Job bash qui réactive un compte qui a été mis en inactif donc désactivé.
#
#_Ver_|_Modifie_le_|_Par_|_Objet___________________________________________
#     |            |     |
#     |            |     | 
# 1.0 | 12/12/2025 | MLE | Création du script
#     |            |     | 
####################################################################################

#!/bin/bash

CONTAINER_DB="guacamoledb"
U=root
#M=@PASSWD
B="guacamole_db"
read -s -p "Mot de passe BDD : " M
UMB="-u $U -p$M $B"

read -p "Utilisateur à réactiver : " REACTIVE_USER

# 2. RÉACTIVATION de l'utilisateur choisi
echo "--- Réactivation du compte choisi... ---"

docker exec guacamoledb mysql $UMB -t -N -e "UPDATE guacamole_user JOIN guacamole_entity ON guacamole_user.entity_id = guacamole_entity.entity_id SET guacamole_user.disabled = 0 WHERE guacamole_entity.name = '$REACTIVE_USER';"

# 3. Affiche les utilisateurs activés

echo "--- Rapport Final des Utilisateurs activés ---"

UTILISATEURS_ACTIVES=$(docker exec "guacamoledb" mysql $UMB -t -N -e "SELECT guacamole_entity.name AS username FROM guacamole_entity JOIN guacamole_user ON guacamole_entity.entity_id = guacamole_user.entity_id WHERE guacamole_user.disabled = 0;")
echo "$UTILISATEURS_ACTIVES"