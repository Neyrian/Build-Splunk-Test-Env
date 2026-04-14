#!/bin/bash 

# Script name: splunk.sh
# Description: Management toolkit for Splunk Enterprise in Docker.

###########################################
# CONFIGURATION
###########################################
container_name="splunk"   
debug=true
splunk_pwd="Admin#123"
LOG_CONF_FILE="splunk_imports.conf"

###########################################
# HELPER FUNCTIONS
###########################################

# Unified logging function
log_message() {
    if [ "$debug" = true ]; then
        local log_level=$1
        shift
        local msg="$@"
        local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        echo -e "$timestamp [$log_level] $msg"
    fi
}

# Function to check if the container is currently running
is_running() {
    sudo docker ps -q -f name="$container_name"
}

# Function to check if the container exists (even if stopped)
exists() {
    sudo docker ps -aq -f name="$container_name"
}

###########################################
# CORE ROUTINES
###########################################

import_logs() {
    if [ -z "$(is_running)" ]; then log_message "ERROR" "Container not running"; return; fi

    read -p "Enter full path to log file: " logfile_path
    [ ! -f "$logfile_path" ] && { echo "File not found!"; return; }

    read -p "Enter Index name [main]: " index_name; index_name=${index_name:-main}
    read -p "Enter Sourcetype [windows]: " sourcetype; sourcetype=${sourcetype:-windows}
    read -p "Enter Hostname [mysuperhost]: " host_name; host_name=${host_name:-mysuperhost}

    filename=$(basename "$logfile_path")
    dest="/tmp/$filename"

    log_message "INFO" "Checking if index '$index_name' exists..."
    # Check index existence via CLI
    INDEX_CHECK=$(sudo docker exec --user splunk "$container_name" /opt/splunk/bin/splunk list index -auth admin:"$splunk_pwd" 2>/dev/null | grep -w "$index_name")

    if [ -z "$INDEX_CHECK" ]; then
        log_message "INFO" "Creating index '$index_name'..."
        sudo docker exec --user splunk "$container_name" /opt/splunk/bin/splunk add index "$index_name" -auth admin:"$splunk_pwd"
    fi

    log_message "INFO" "Copying and importing $filename..."
    sudo docker cp "$logfile_path" "$container_name":"$dest"
    
    # Run oneshot and then delete the temp file
    sudo docker exec --user splunk "$container_name" /bin/bash -c "/opt/splunk/bin/splunk add oneshot $dest -index $index_name -sourcetype $sourcetype -host $host_name -auth admin:$splunk_pwd"
    
    # Log to our history file
    echo "$(date) | LOG | File: $filename | Index: $index_name | Host: $host_name" >> "$LOG_CONF_FILE"
}

install_app() {
    if [ -z "$(is_running)" ]; then log_message "ERROR" "Container not running"; return; fi

    read -p "Enter full path to App file (.spl/.tar.gz): " app_path
    [ ! -f "$app_path" ] && { echo "File not found!"; return; }

    app_filename=$(basename "$app_path")
    sudo docker cp "$app_path" "$container_name":"/tmp/$app_filename"

    log_message "INFO" "Installing app $app_filename..."
    sudo docker exec --user splunk "$container_name" /opt/splunk/bin/splunk install app "/tmp/$app_filename" -auth admin:"$splunk_pwd" -update 1
    
    sudo docker exec "$container_name" rm "/tmp/$app_filename"
    echo "$(date) | APP | App: $app_filename" >> "$LOG_CONF_FILE"
}

###########################################
# MAIN MENU LOOP
###########################################

while true; do
    echo -e "\n--- SPLUNK DOCKER MANAGER ---"
    echo "1) Check Env & Pull Image"
    echo "2) Create Container"
    echo "3) Start Container"
    echo "4) Stop/Pause/Unpause"
    echo "5) Import Logs (Oneshot)"
    echo "6) Install App (.spl/.tar.gz)"
    echo "7) Suppress SSL Warnings (server.conf)"
    echo "8) Open Interactive Shell"
    echo "9) Restart Splunk"
    echo "10) Delete Container"
    echo "0) Exit"
    read -p "Select an option [0-10]: " choice

    case $choice in
        1)
            log_message "INFO" "Checking Docker & Pulling latest Splunk..."
            sudo service docker start && sudo docker pull splunk/splunk:latest
            ;;
        2)
            if [ -n "$(exists)" ]; then log_message "WARN" "Container already exists";
            else
                sudo docker run -d -p 8000:8000 -e SPLUNK_GENERAL_TERMS=--accept-sgt-current-at-splunk-com \
                -e "SPLUNK_START_ARGS=--accept-license" -e "SPLUNK_PASSWORD=$splunk_pwd" \
                --name "$container_name" splunk/splunk:latest
                log_message "INFO" "Splunk available at http://localhost:8000/"
            fi
            ;;
        3)  
            if [ -n "$(is_running)" ]; then log_message "INFO" "Splunk is already running at http://localhost:8000/";
            else
                sudo docker container start "$container_name" 
                log_message "INFO" "Splunk available at http://localhost:8000/"
            fi
            ;;
        4)
            read -p "(s)top, (p)ause, or (u)npause? " action
            case $action in
                s) sudo docker container stop "$container_name" ;;
                p) sudo docker container pause "$container_name" ;;
                u) sudo docker container unpause "$container_name" ;;
            esac
            ;;
        5) import_logs ;;
        6) install_app ;;
        7)
            log_message "INFO" "Modifying server.conf and restarting..."
            sudo docker exec --user splunk "$container_name" /bin/bash -c "echo -e '\n[sslConfig]\ncliVerifyServerName = false' >> /opt/splunk/etc/system/local/server.conf"
            sudo docker exec --user splunk "$container_name" /opt/splunk/bin/splunk restart -auth admin:"$splunk_pwd"
            ;;
        8)
            read -p "User [splunk]: " s_user; s_user=${s_user:-splunk}
            sudo docker exec --user "$s_user" -it "$container_name" /bin/bash
            ;;
        9) sudo docker exec --user splunk "$container_name" /opt/splunk/bin/splunk restart -auth admin:"$splunk_pwd" ;;
        10)
            sudo docker container stop "$container_name"
            sudo docker container rm "$container_name"
            ;;
        0) exit 0 ;;
        *) echo "Invalid choice, try again." ;;
    esac
done