#!/bin/bash
DATE=$(date +"%d-%m-%Y_%H-%M")
EXPORT_FILE="/opt/guacamole/export_bdd/export_users_${DATE}.csv"

# On crée l'en-tête
echo "name,password_hash_b64,password_salt_b64" > "$EXPORT_FILE"

mysql -uroot -pmdproot guacmole_db -N -e \
"SELECT
   CONCAT_WS(',',
     e.name,
     TO_BASE64(u.password_hash),
     TO_BASE64(u.password_salt)
   )
 FROM guacamole_entity e
 JOIN guacamole_user u ON e.entity_id = u.entity_id
 WHERE e.type = 'USER';" \
 >> "$EXPORT_FILE"

echo "Export terminé dans : $EXPORT_FILE"