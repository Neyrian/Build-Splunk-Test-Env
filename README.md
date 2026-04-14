# Splunk Docker Env Management Toolkit 🛠️

A robust Bash utility designed to automate the deployment, configuration, and data ingestion workflows for Splunk Enterprise running in Docker. This toolkit is perfect for security researchers, lab builders, and Splunk architects who need to spin up and tear down test environments rapidly.

## ✨ Features

* Interactive Menu System

* Intelligent Log Ingestion: Handles oneshot imports with custom Sourcetypes and Hostnames.

* App Management: Install or update Splunk Apps (.spl, .tar.gz) with a single command.

* History Tracking: Logs every import and app installation to splunk_imports.conf for auditing.

* Manage docker env

## 🚀 Quick Start

1. Get the script from this repo 
```bash
git clone https://github.com/Neyrian/build_splunk_test.git
cd build_splunk_test
chmod +x splunk.sh
```

2. Ensure that you have docker installed, otherwise run
```bash
sudo apt install docker.io
```

3. Usage

```bash
./splunk.sh
```


## ⚙️ Configuration

Edit splunk.sh variable for custom config

## 🛠️ Menu Options

* Check Env & Pull Image: Prepares the Docker host and pulls the latest Splunk image.

* Create Container: Standardized docker run with necessary environment variables.

* Import Logs: Interactive flow to copy files into the container and index them immediately.

* Install App: Seamlessly deploys Technology Add-ons (TAs) or Dashboards.

* sUppress SSL Warnings: Fixes CLI certificate errors by modifying server.conf automatically.

* Open Shell: Provides instant access to the container as splunk or other user.

This script is intended for Lab/Test environments. 
Developed with ❤️ for the Splunk Community.

## Using WSL2

If you are using WSL, you may encounter some issue accessing the splunk instance. It is likely a port forwarding issue.
Powershell command:
```Powershell
netsh interface portproxy add v4tov4 listenport=<Win_port> listenaddress=0.0.0.0 connectport=<WSL2_port> connectaddress=<WSL2_IP>
```
Obtain <WSL2_IP> from

```powershell
wsl hostname -I
```
To see existing port-forwardings:
```Powershell
netsh interface portproxy show all
```

To delete a particular port-forwarding:
```Powershell
netsh interface portproxy delete v4tov4 listenport=<port> listenaddress=<IP>
```
