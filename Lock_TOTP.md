# Procédure : Désactiver ou Réinitialiser le MFA (TOTP) d'un utilisateur

Cette documentation décrit la marche à suivre pour gérer la double authentification (MFA/TOTP) d'un utilisateur (en cas de perte de téléphone, désynchronisation ou besoin de désactivation temporaire).

**Prérequis :**
* Disposer d'un compte administrateur.
* Avoir accès à l'interface de gestion des utilisateurs.

---

## 1. Accéder au profil utilisateur

1.  Connectez-vous à la console d'administration avec le compte administrateur (**`infra`**).
2.  Naviguez vers la section de gestion des **Utilisateurs**.
3.  Cliquez sur le **nom de l'utilisateur** concerné pour éditer son profil.
4.  Repérez la section **STATUT D'INSCRIPTION TOTP** (visible dans l'image ci-dessous).

![Statut TOTP](./TOTP.png)

---

## 2. Choisir l'action à effectuer

Selon le besoin, modifiez l'état des cases à cocher comme suit :

### Cas A : Réinitialiser le MFA (Perte de téléphone / Nouveau téléphone)
*Utilisez cette option si l'utilisateur a perdu son appareil ou doit re-scanner un nouveau QR Code.*

Pour forcer l'utilisateur à reconfigurer son MFA lors de sa prochaine connexion :
1.  **DÉCOCHER** la case : `Clé secrète générée`.
2.  **DÉCOCHER** la case : `Appareil d'authentification confirmé`.
3.  Laissez la case `Désactiver TOTP` décochée.

> **Résultat :** Le système "oublie" l'ancienne configuration. À la prochaine connexion, l'utilisateur verra apparaître un nouveau QR Code à scanner.

### Cas B : Désactiver le MFA (Arrêt temporaire ou définitif)
*Utilisez cette option si vous souhaitez que l'utilisateur se connecte uniquement avec son mot de passe, sans code, tout en conservant sa configuration existante en mémoire (ou pour couper l'accès MFA).*

Pour couper le MFA :
1.  **COCHER** la case : `Désactiver TOTP`.

> **Résultat :** L'utilisateur ne sera plus sollicité pour le code TOTP, mais sa clé secrète reste stockée (sauf si vous décochez aussi les autres cases).

---

## 3. Valider

Une fois les cases modifiées selon le cas choisi :
1.  Cliquez sur le bouton **Enregistrer** en bas de la page du profil utilisateur.
2.  Informez l'utilisateur qu'il peut tenter de se reconnecter.