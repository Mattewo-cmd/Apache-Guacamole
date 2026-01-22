#!/bin/bash
#Configuration
CONTAINER_DB="guacamoledb"
UMB="-umysql -p guacamole_db" # On groupe les infos de connexion
DATE=$(date +"%Y-%m-%d_%H-%M")
EXPORT_FILE="/opt/guacamole/export_bdd/guac_export_${DATE}.sql"

echo "📦 Export des connexions Guacamole..."
echo "🕒 Date : $DATE"
echo "📁 Destination : $EXPORT_FILE"

#Commande d’export
docker exec -i "$CONTAINER_DB" \
mysqldump --no-tablespaces $UMB \
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