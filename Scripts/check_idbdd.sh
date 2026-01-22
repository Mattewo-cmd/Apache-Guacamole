#!/bin/bash

#Affiche les utilisateurs et leur id :

docker exec -it guacamoledb mysql -u root -p guacamole_db -e "SELECT entity_id, name FROM guacamole_entity WHERE type='USER';"

#Affiche la dernière fois que le mdp a été mis à jour avec l'id user :

docker exec -it guacamoledb mysql -u root -p guacamole_db -e "SELECT user_id, password_date FROM guacamole_user;"

#Affiche l'ID de l'entité et l'ID de l'utilisateur pour pouvoir les comparer :

docker exec -it guacamoledb mysql -u root -p guacamole_db -e "SELECT e.entity_id, e.name, u.user_id FROM guacamole_entity e LEFT JOIN guacamole_user u ON e.entity_id = u.user_id WHERE e.type='USER';"