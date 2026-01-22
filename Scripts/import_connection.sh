#!/bin/bash
#Configuration
CONTAINER_DB="guacamoledb"
UMB="-umysql -p guacamole_db" # On groupe les infos de connexion
IMPORT_DIR="/opt/guacamole/export_bdd"
LATEST_EXPORT=$(ls -t ${IMPORT_DIR}/guac_export_*.sql* 2>/dev/null | head -n 1)

#Vérifications
if [ -z "$LATEST_EXPORT" ]; then
  echo "❌ Aucun fichier de sauvegarde trouvé dans $IMPORT_DIR"
  exit 1
fi

echo "📥 Import des connexions Guacamole..."
echo "📁 Fichier détecté : $LATEST_BACKUP"

#Import dans la base
echo "⚙️  Import du fichier SQL dans la base..."
docker exec -i "$CONTAINER_DB" mysql $UMB < "$LATEST_EXPORT"

if [ $? -eq 0 ]; then
  echo "✅ Import terminé avec succès."
else
  echo "❌ Erreur lors de l’import."
  exit 1
fi

echo "✅ Base Guacamole mise à jour avec succès."