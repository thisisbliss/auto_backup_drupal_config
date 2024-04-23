# Backup Drupal Config changes (not multi-site)
#
# v1.0 30/Dec/23 - Jeremy Mitchell @ Bliss Digital Ltd
# v1.1 11/Apr/24 - Add platform mount and backup option to use rsync, convert to package + share
#
# notes:
# += for concatinating strings within platform.app.yaml isn't valid, although valid when using bash from the platform CLI

# params 
notify_google_chat=$1     # platform.app.yaml should execute this script with parameter 'send_google_chat'
drupal_config_backup_mount='drupal_config_backups'
drupal_config_sync_path='config/sync'

# Colours
red='\033[0;41m'  # Red background
green='\033[0;32m'  # Green text
end='\e[0m'  # Reset formatting

# --- Check drupal_config_backup mount exists ---
# Check if the mount point exists
if ! mount | grep "${drupal_config_backup_mount} type" > /dev/null; then
  drupal_config_backup_folder="/tmp/drupal_config_backups"
  echo -e " "
  echo -e "${red} Please define mount '${drupal_config_backup_mount}' in platform.app.yaml for Drupal backup files. ${end}"
  echo -e "${red} Using temporary location ${drupal_config_backup_folder} for now ${end}"
  echo -e " "
  echo -e "Example:"
  echo -e "mounts:"
  echo -e "\t'${drupal_config_backup_mount}':"
  echo -e "\t\t source: local"
  echo -e "\t\t source_path: 'drupal_config_backups'"
  echo -e " "
  backup_mount_exists=false
else
  drupal_config_backup_folder="/app/${drupal_config_backup_mount}"
  backup_mount_exists=true
fi

# --- Send a Test Google Chat Message ---
if [ "$notify_google_chat" = "test_google_chat" ]; then
    if [ -z "$GOOGLE_CHAT_WEBHOOK" ]; then
        echo -e "${red} Unable to send message to google chat. Set platform.sh environment variable 'env:GOOGLE_CHAT_WEBHOOK' to the chat webhook first. ${end}"
    fi

    chat=""
    if [ -n "$GOOGLE_CHAT_PROJECT" ]; then 
      chat="${chat}*${GOOGLE_CHAT_PROJECT}*\n\n" # Frendly project name
    fi

    chat="${chat}*Test Google Chat Message from ${PLATFORM_ENVIRONMENT_TYPE}*\n\n"
    chat="${chat}_Project: *${PLATFORM_PROJECT}*  Branch: *${PLATFORM_BRANCH}*_\n\n"
    chat="${chat}\n"
    chat_json="{\"text\":\"${chat}\"}"
    echo -e "Sending Google Chat Message..."
    curl -X POST -H "Content-Type: application/json" -d "${chat_json}" "${GOOGLE_CHAT_WEBHOOK}"
fi


# --- Check Config, backup + send/display results ---
drush_output=$(drush config:status 2>&1)

if echo -e "$drush_output" | grep -q "No differences"; then
    echo -e "${green}No Drupal Config Changes on ${PLATFORM_ENVIRONMENT_TYPE} ${end}"

elif echo -e "$drush_output" | grep -q "unable to query the database"; then
  echo -e "${red}Aborting: Drush unable to query the database.${end}"
  exit 1 # Report an error

else # drush output ok
    config_folder_name="config_export_$(date +'%Y-%m-%d-%H%M')"
    config_path="${drupal_config_backup_folder}/${config_folder_name}"
    mkdir -p "$config_path"

    # Output each config change as a line to platform_export.sh as "drush cget {config name}", then run it
    echo -e "Checking for Drupal config changes on ${PLATFORM_ENVIRONMENT_TYPE}..."
    drush config:status --state="Only in DB","Different" --format=string | awk -v config_folder="$config_path" '{print "drush cget "$1" > " config_folder "/" $1 ".yml"}' > $config_path/platform_export.sh
    chmod +x $config_path/platform_export.sh
    bash $config_path/platform_export.sh

    # Create command file for local Dev environment to Update the config/sync folder: Delete any removed config + copy new config
    echo -e "Checking for deleted Drupal config..."
    drush config:status --state="Only in sync dir" --format=string | awk '{print "rm $drupal_config_sync_path/"$1}' >"$config_path/update_sync_folder.sh"
    echo "cp ./drupal_config_from_platform/${config_folder_name}/*.yml ./${drupal_config_sync_path}" >> "$config_path/update_sync_folder.sh"


    # Delete config backups from over 30 days ago
    find $drupal_config_backup_folder -maxdepth 1 -type d -name 'config_export_*' -mtime +30 -exec rm -rf {} \;

    # --- User message to download ---

    if $backup_mount_exists; then
      download_instructions="platform mount:download --mount=${drupal_config_backup_mount} --target=drupal_config_from_platform --environment=${PLATFORM_BRANCH} -y\n"
      download_instructions="${download_instructions}chmod +x ./drupal_config_from_platform/${config_folder_name}/update_sync_folder.sh\n"
      download_instructions="${download_instructions}./drupal_config_from_platform/${config_folder_name}/update_sync_folder.sh\n"

    else # no mount defined, config was backed up to /tmp
      download_instructions="mkdir -p ./drupal_config_from_platform\n"
      download_instructions="${download_instructions}rsync -avz \$(platform ssh --environment=${PLATFORM_BRANCH} --pipe):$config_path/ ./drupal_config_from_platform/${config_folder_name}\n"
      download_instructions="${download_instructions}chmod +x ./drupal_config_from_platform/${config_folder_name}/update_sync_folder.sh\n"
      download_instructions="${download_instructions}./drupal_config_from_platform/${config_folder_name}/update_sync_folder.sh\n"
    fi

    # --- Send Google Chat Message ---
  

    if [ "$notify_google_chat" = "send_google_chat" ]; then

        if [ -z "$GOOGLE_CHAT_WEBHOOK" ]; then
            echo -e "${red} Unable to send message to google chat. Set platform.sh environment variable 'env:GOOGLE_CHAT_WEBHOOK' to the chat webhook first. ${end}"
        fi

        chat=""
        if [ -n "$GOOGLE_CHAT_PROJECT" ]; then 
          chat="${chat}*${GOOGLE_CHAT_PROJECT}*\n\n" # Frendly project name
        fi

        chat="${chat}*Backup Created of Drupal Config Changes on ${PLATFORM_ENVIRONMENT_TYPE}*\n\n"
        chat="${chat}_Project: *${PLATFORM_PROJECT}*  Branch: *${PLATFORM_BRANCH}*_\n\n"
        #chat="${chat}Saved in $config_path\n\n"
        chat="${chat}\`\`\`\n${drush_output}\n\`\`\`\n" # escape backticks to interpret as a monoblock markdown for gogole chat, actual backtick causes platform.sh to fail excuting this line correctly
        chat="${chat}\n\n"
        chat="${chat}*From your local project root, use these commands to download + update ${drupal_config_sync_path}*\n"
        chat="${chat}\n"
        chat="${chat}${download_instructions}"
        chat="${chat}\n"
        chat_json="{\"text\":\"${chat}\"}"
        echo -e "Sending Google Chat Message..."
        curl -X POST -H "Content-Type: application/json" -d "${chat_json}" "${GOOGLE_CHAT_WEBHOOK}"
    fi

    # --- Echo - Explain how to download ---
    echo -e " "
    echo -e "${red} Backup Created of Drupal Config Changes on ${PLATFORM_ENVIRONMENT_TYPE}! ${end}"
    echo -e "Saved in $config_path"
    echo -e " "
    echo -e "$drush_output"
    echo -e " "
    echo -e "${green}From your local project root: Use these commands to download + update ${drupal_config_sync_path} ${end}"
    echo -e " "
    echo -e "${download_instructions}"
    echo -e " "
    echo -e "${green} --- ${end}"
    echo -e " "

fi