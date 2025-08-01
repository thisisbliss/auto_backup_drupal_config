# Automated Config Backup During 'Drush Deploy' on Platform.sh
Never lose Drupal config again!

Solve the problem of deploying a git repository to platform.sh, then losing existing Drupal config changes.

Automatically creates backups of Drupal config changes on Platform, then sends a google chat message to your local project environment.

Paste the commands included in the chat message to your local CLI, then compare config changes in your config/sync folder (great for Visual Studio Code)

## Prerequisites
- The Platform.sh project is using Drupal 8+
- The project is not using multi-site Drupal (that's a feature I'll add later)

## What it does
- Automatically looks for updated/deleted Drupal config during a platform deploy, then creates a backup of changes
  in /tmp/drupal_config_backups or /app/drupal_config_backups (if platform mount 'drupal_config_backups' exists)
- Each backup folder is date+time labelled
- Deletes old backups from over 30 days ago
- Displays instructions how to download to your local development environment (e.g. DDEV)
- Optionally sends instructions to a google chat space, when changes found
- Chat message includes instructions to download to a development folder named '.drupal_config_from_platform' and your development's config/sync folder

## How to Manually Backup Drupal Config
Run from any platform environment
```
platform ssh
```
```
./vendor/thisisbliss/auto_backup_drupal_config/backup_drupal_config.sh
```

Or setup a local alias:
```
alias backup_config="platform ssh -e main -- './vendor/thisisbliss/auto_backup_drupal_config/backup_drupal_config.sh'"
backup_config
```
* assumes 'main' is your production branch


## How to Automatically Backup Drupal Config
If the Drupal "config sync" folder isn't config/sync, change variable "drupal_config_sync_path" in backup_drupal_config.sh

### Before deploying the below changes: Backup Existing Drupal Config!

- SSH to your platform production branch (will work on any branch)
- Copy the contents of ```backup_drupal_config.sh``` and paste straight into the Platform CLI
- Follow the instructions to download your config

### Add to composer packages

Add the Gitlab repository if missing:
```
ddev composer config repositories.auto_backup_drupal_config vcs https://github.com/thisisbliss/auto_backup_drupal_config
```
* Remove ddev prefix if not being used

Add the package:
```
ddev composer require thisisbliss/auto_backup_drupal_config:^1.0
```

~~Add the packagist repository if missing:~~

~~composer config repositories.asset-packagist composer https://asset-packagist.org~~

### Update platform.app.yaml to run the backup script
Add a mount for a cleaner way to download backups.
```
mounts:
    '/drupal_config_backups':
        source: local
        source_path: 'drupal_config_backups'
```

Run the backup during deploy.

**Insert new deploy code before 'drush config-import'.**

Sending a message to google chat is optional, just remove 'send_google_chat' if not required.

```
hooks:
    build:
        ... existing build commands ...
        chmod +x /app/vendor/thisisbliss/auto_backup_drupal_config/backup_drupal_config.sh


    deploy:
        ... existing commands - before config imported ...

        # --- Backup [Production] config changes before importing config ---
        echo " "
        if [ "$PLATFORM_ENVIRONMENT_TYPE" = "production" ]; then    # test on staging with "development"
            /app/vendor/thisisbliss/auto_backup_drupal_config/backup_drupal_config.sh send_google_chat
        else
            echo "Platform environment type: $PLATFORM_ENVIRONMENT_TYPE (Drupal config not backed-up for this environment type)"
        fi

        .... drush -y deploy or drush -y config-import ...
```

### Update the project's .gitignore
```
# ignore config downloaded from platform
/drupal_config_from_platform
```

### Setup Google Chat Messages
Set platform environment variables to receive google chat messages (when changes are found).

- Get a Google chat Webhook: Within Chat, Select space>Apps and integrations>Add Webhook
- On Platform, set environment variable ```env:GOOGLE_CHAT_WEBHOOK``` with the new webhook
- And environment variable ```env:GOOGLE_CHAT_PROJECT``` for a friendly project name. e.g. "Bliss-customer-x", instead of the referring to less helpful project IDs
- Redeploy the Platform project
```
platform ssh
./vendor/thisisbliss/auto_backup_drupal_config/backup_drupal_config.sh test_google_chat
```
## Revision History

### 0.1.0-Beta
- Initial Release, working with Platform.sh and Drupal (not Multisite)
### 1.0.0-Stable
- Beta has been stable on 10+ sites for a few months.


### dev-main (latest changes)
- send a test google chat message by using parameter test_google_chat
- compare new drupal config about to be imported, before reporting/backing up as "lost config"

## Copyright 2024-2025 Bliss Digital Ltd
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
