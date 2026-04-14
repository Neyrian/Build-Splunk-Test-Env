#!/bin/bash 

# Script name: splunk.sh

##################
# You can edit these variable
container_name="splunk"   # Docker container ID or name
debug=true
splunk_pwd="Admin#123"
working_dir="$HOME/Build-Splunk-Test-Env"
##################

# Configuration file path
LOG_CONF_FILE="splunk_imports.conf"

# Define the log function
log_message() {
    if [ "$debug" = true ]; then
        local log_level=$1
        shift
        local log_message="$@"
        local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

        echo "$timestamp [$log_level] $log_message"
    fi
}

# Check if no arguments were passed
if [ $# -eq 0 ]; then
    log_message "WARN" "Usage ./splunk.sh <option>"
    log_message "INFO" "./splunk.sh checks -> checks if everything is good"
    log_message "INFO" "./splunk.sh start -> start the container splunk"
    log_message "INFO" "./splunk.sh delete -> delete the container"
    log_message "INFO" "./splunk.sh stop -> stop the container"
    log_message "INFO" "./splunk.sh pause -> pause the container"
    log_message "INFO" "./splunk.sh unpause -> unpause the container"
    log_message "INFO" "./splunk.sh create -> create the container"
    log_message "INFO" "./splunk.sh status -> check the container status"
    log_message "INFO" "./splunk.sh restart -> restart splunk"
    log_message "INFO" "./splunk.sh shell -> start a shell as splunk user in the splunk docker"
    log_message "INFO" "./splunk.sh config -> display splunk config"
    log_message "INFO" "./splunk.sh importLogs -> import the logs"
    log_message "INFO" "./splunk.sh apps -> install TA windows, linux, apache"
elif [ "$1" == "checks" ]; then
    log_message "INFO" "Checking Docker status"
    d_status=$(service docker status)
    if [ "$d_status" == "Docker is running." ]; then
        log_message "OK" "Docker is running"
    else
        log_message "INFO" "Starting docker"
        sudo service docker start
        sleep 5
    fi
    log_message "INFO" "Download the last docker image"
    sudo docker pull splunk/splunk:latest
elif [ "$1" == "start" ]; then
    if [ "$(sudo docker ps -aq -f status=exited -f name=$container_name)" ]; then
        log_message "INFO" "Starting container..."
        sudo docker container start $container_name
    else
        log_message "WARN" "The container named $container_name doesn't exist or is already running"
    fi
elif [ "$1" == "delete" ]; then
    if [ "$(sudo docker ps -q -f  name=$container_name)" ]; then
        log_message "ERROR" "The container $container_name is running, can't delete..."
    elif [ "$(sudo docker ps -aq -f status=exited -f name=$container_name)" ]; then
        log_message "INFO" "Deleting the container named $container_name"
        sudo docker container rm $container_name
    else
        log_message "ERROR" "No container named $container_name"
        log_message "WARN" "run splunk.sh create"
    fi
elif [ "$1" == "stop" ]; then
    if [ "$(sudo docker ps -q -f  name=$container_name)" ]; then
        log_message "INFO" "Stopping the container."
        sudo docker container stop $container_name
    else
        log_message "ERROR" "The container named $container_name not running..."
    fi
elif [ "$1" == "pause" ]; then
    if [ "$(sudo docker ps -q -f  name=$container_name)" ]; then
        log_message "INFO" "Pausing the container."
        sudo docker container pause $container_name
    else
        log_message "ERROR" "The container named $container_name not running..."
    fi
elif [ "$1" == "unpause" ]; then
    if [ "$(sudo docker ps -q -f  name=$container_name)" ]; then
        log_message "INFO" "Pausing the container."
        sudo docker container unpause $container_name
    else
        log_message "ERROR" "The container named $container_name not running..."
    fi
elif [ "$1" == "create" ]; then
    log_message "INFO" "checking if no spunk container exists..."
    if [ "$(sudo docker ps -aq -f status=exited -f name=$container_name)" ]; then
        log_message "WARN" "A container named $container_name already exists."
    else
        log_message "INFO" "Creating container $container_name"
        sudo docker run -d -p 8000:8000 -e SPLUNK_GENERAL_TERMS=--accept-sgt-current-at-splunk-com -e "SPLUNK_START_ARGS=--accept-license" -e "SPLUNK_PASSWORD=$splunk_pwd" --name $container_name splunk/splunk:latest
    fi
elif [ "$1" == "SSLWarnings" ]; then
    log_message "INFO" "Supress Splunk CLI SSL Warnings..."
    sudo docker exec --user splunk "$container_name" /bin/bash -c "echo -e '\n[sslConfig]\ncliVerifyServerName = false' >> /opt/splunk/etc/system/local/server.conf"
    log_message "INFO" "Restarting the container $container_name."
    sudo docker exec --user splunk "$container_name" /bin/bash -c "/opt/splunk/bin/splunk restart -auth admin:$splunk_pwd"
elif [ "$1" == "status" ]; then
    sudo docker container logs $container_name
    sudo docker container ls -a
elif [ "$1" == "restart" ]; then
    if [ "$(sudo docker ps -q -f  name=$container_name)" ]; then
        log_message "INFO" "Restarting the container $container_name."
        sudo docker exec --user splunk "$container_name" /bin/bash -c "/opt/splunk/bin/splunk restart -auth admin:$splunk_pwd"
    else
        log_message "ERROR" "Container not running..."
    fi
elif [ "$1" == "shell" ]; then
    if [ "$(sudo docker ps -q -f  name=$container_name)" ]; then
        read -p "Enter the user to open the shell as [splunk]: " shell_user
        shell_user=${shell_user:-splunk}
        log_message "INFO" "Opening interactive shell in '$container_name' as user: $shell_user"
        sudo docker exec --user "$shell_user" -it "$container_name" /bin/bash
    else
        log_message "ERROR" "Container not running..."
    fi

elif [ "$1" == "importLogs" ]; then
    if [ "$(sudo docker ps -q -f  name=$container_name)" ]; then
        read -p "Enter the full path to the log file: " logfile_path
        if [ ! -f "$logfile_path" ]; then
            echo "Error: File $logfile_path not found!"
            exit 1
        fi

        read -p "Enter Index name [main]: " index_name
        index_name=${index_name:-main}

        read -p "Enter Sourcetype [windows]: " sourcetype
        sourcetype=${sourcetype:-windows}

        read -p "Enter Hostname [mysuperhost]: " host_name
        host_name=${host_name:-mysuperhost}

        filename=$(basename "$logfile_path")
        dest_in_container="/tmp/$filename"

        log_message "INFO" "Checking if index '$index_name' exists..."

        # Check if index exists, if not, create it
        INDEX_CHECK=$(sudo docker exec "$container_name" /bin/bash -c "sudo /opt/splunk/bin/splunk list index -auth admin:$splunk_pwd | grep -w \"$index_name\"")

        if [ -z "$INDEX_CHECK" ]; then
            log_message "INFO" "Index '$index_name' not found. Creating it..."
            sudo docker exec -it "$container_name" /bin/bash -c "sudo /opt/splunk/bin/splunk add index $index_name -auth admin:$splunk_pwd"
        fi

        log_message "INFO" "Copying $filename to container..."

        sudo docker cp "$logfile_path" "$container_name":"$dest_in_container" 

        log_message "INFO" "Importing to Splunk (Oneshot)..."
        # We use 'oneshot' which indexes the file immediately. 
        # We run as the splunk user to avoid permission issues.
        sudo docker exec --user splunk "$container_name" /bin/bash -c "
            /opt/splunk/bin/splunk add oneshot $dest_in_container \
            -index $index_name \
            -sourcetype $sourcetype \
            -host $host_name \
            -auth admin:$splunk_pwd"
    else
        log_message "ERROR" "Container not running..."
    fi
elif [ "$1" == "apps" ]; then
    if [ "$(sudo docker ps -q -f  name=$container_name)" ]; then
        read -p "Enter the full path to the Splunk App file (.spl/.tar.gz): " app_path
        if [ ! -f "$app_path" ]; then
            echo "Error: App file $app_path not found!"
            exit 1
        fi

        # Extract the filename for the container path
        app_filename=$(basename "$app_path")
        app_dest="/tmp/$app_filename"

        log_message "INFO" "Copying app to container..."
        sudo docker cp "$app_path" "$container_name":"$app_dest"

        sudo docker exec --user splunk "$container_name" /bin/bash -c "/opt/splunk/bin/splunk install app $app_dest -auth admin:$splunk_pwd -update 1"

        if [ $? -eq 0 ]; then
            log_message "INFO" "App $app_filename installed successfully."
        else
            log_message "ERROR" "Failed to install app $app_filename."
        fi
    else
        log_message "ERROR" "Container not running..."
    fi
fi