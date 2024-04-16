# Automatically Backup Drupal Config when Deploying on Platform.sh + Download to the Local Development Environment
Never lose Drupal config again!

Solve the problem of pushing/deploying a git repository (with Drupal config) to platform.sh, then
loosing existing Drupal config changes. 

Automatically creates backups of Drupal config changes on Platform, then sends a google chat message with the commands to download to your local project environment. 

So, after receiving a message, just paste the commands to your local CLI. Then a moment later, compare config changes with your config/sync folder (using a tool ike VS Code)

## Prerequisites
- The Platform.sh project is using Drupal 8+
- The project is not using multi-site Drupal (that's a feature I'll add later)

## What it does
- Automatically looks for updated/deleted Drupal config during a platform deploy, then creates a backup of changes
  in /tmp/drupal_config_backups or /app/drupal_config_backups (if platform mount 'drupal_config_backups' exists)
- Each backup folder is date+time labelled
- Deletes old backups from over 30 days ago
- Displays instructions how to download to your local development environment (e.g. DDEV)
- Optionally sends a download instructions to a google chat space, when changes found
- Follow instructions to download to development folder '.drupal_config_from_platform' and your development's config/sync folder

## Running a backup manually
SSH to the platform environment and run the backup
```
platform ssh 
./vendor/thisisbliss/auto_backup_drupal_config/backup_drupal_config.sh
```

## Configuration
- If the Drupal "config sync" folder isn't config/sync, change variable "drupal_config_sync_path" in backup_drupal_config.sh

### Before Deploying the below changes - Backup Existing Drupal Config!

- SSH to your platform production branch (feel free to try on a staging branch first)
- Copy the contents of ```backup_drupal_config.sh``` and paste straight into the CLI
- Follow the instructions to download your config

### Add to composer packages
**Prefix with DDEV if using DDEV!**

Add the packagist repository if missing:
```
composer config repositories.asset-packagist composer https://asset-packagist.org
```
Add the package:
```
composer require thisisbliss/auto_backup_drupal_config:^0.1.0@beta
```

### Update platform.app.yaml to run the backup script
Add a mount for a cleaner way to backup and download backups.
```
mounts:
    '/drupal_config_backups':
        source: local
        source_path: 'drupal_config_backups'
```

Run the backup during deploy.

**Insert new deploy code before 'drush config-import'.**

Sending a message to google chat is optional, just remove 'send_google_chat' to skip that step.
```
hooks:
    build:
        ... existing build commands ...
        chmod +x /app/vendor/thisisbliss/auto_backup_drupal_config/backup_drupal_config.sh

    deploy:
        ... existing deploy commands like: drush -y cache-rebuild, drush -y updatedb ...

        # --- Backup [Production] config changes before importing config ---
        echo " "
        if [ "$PLATFORM_ENVIRONMENT_TYPE" = "production" ]; then    # test on staging with "development", otherwise "production"
            /app/vendor/thisisbliss/auto_backup_drupal_config/backup_drupal_config.sh send_google_chat
        else
            echo "Platform environment type: $PLATFORM_ENVIRONMENT_TYPE (Drupal config not backed-up for this environment type)"
        fi          

        .... drush -y config-import ...
```

### Update the projects .gitignore
```
# ignore config downloaded from platform
/drupal_config_from_platform
```

### Setup Google Chat Messages
Set platform environment variables to receive google chat messages, when changes are found.

- Get a Google chat Webhook: Within Chat, Select space>Apps and integrations>Add Webhook
- On Platform, set environment variable ```env:GOOGLE_CHAT_WEBHOOK``` with the new webhook
- And environment variable ```env:GOOGLE_CHAT_PROJECT``` for a friendly project name. e.g. "Bliss-customer-x", instead of the referring to less helpful project IDs
- Redeploy the Platform project


## Revision History

### 0.1.0-Beta
Initial Release, working with Platform.sh and Drupal (not Multisite)

## Copyright 2024 Bliss Digital Ltd
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
