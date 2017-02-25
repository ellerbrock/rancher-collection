#!/usr/bin/env bash 

#
# Quick way to setup Rancher Server on RancherOS
#
# Whats inside?
#
#   - install rancher server
#   - install rancher with proxy settings
#   - persist rancher mysql db to docker volume (rancher-mysql)
#   - rancher mysql backup function
#   - setup bash shell with bash_it framework
#   - stop and delete all docker stuff function
#   - delete all unnamed container function


#
# variables
#

RANCHER_ID=$(docker ps | grep "rancher/server" | cut -f1 -d " ")
RANCHER_MYSQL_VOL="rancher-mysql"
RANCHER_BACKUP_DIR="/home/rancher/backup/rancher"

#
# aliases
#

alias ls="ls --color=auto"
alias l="ls -alF"
alias ..="cd .."


#
# proxy settings
#

# export http_proxy="http://your-proxy:8880"
# export https_proxy="${http_proxy}"
# export ftp_proxy="${http_proxy}"
# export no_proxy="localhost,127.0.0.1"


#
# functions
#

function docker-clean-all() {
  docker stop $(docker ps -a -q)
  docker rm -f $(docker ps -a -q)
  docker rmi -f $(docker images -q)
  docker volume rm $(docker volume ls -q)
  docker network rm $(docker network ls -q)
}


function docker-clean-unnamed-container() {
  docker rmi --force $(docker images -a | grep "^<none>" | awk '{print $3}')
}


function installRancher() {
  # persist the mysql database to a docker volume
  docker volume create --name rancher-mysql

  docker run -d \
    --restart=unless-stopped \
    -v rancher-mysql:/var/lib/mysql \
    -p 8080:8080 \
  rancher/server:latest
}


function installRancherProxy() {
  if [[ -z "${http_proxy}" ]]  || \
    [[ -z "${https_proxy}" ]] || \
    [[ -z "${no_proxy}" ]]; then 
   echo "proxy variables not set!"
   exit 1
  else
    # persist the mysql database to a docker volume
    docker volume create --name rancher-mysql
   
    docker run -d \
      --restart=unless-stopped \
      -v rancher-mysql:/var/lib/mysql \
      -p 8080:8080 \
      -e http_proxy="${http_proxy}" \
      -e https_proxy="${https_proxy}" \
      -e no_proxy="${no_proxy}" \
      -e NO_PROXY="${no_proxy}" \
     rancher/server
  fi
}


function backupRancherMySQL() {
  if [ -z "${RANCHER_ID}" ]; then
    echo "ERROR: Can't get Rancher ContainerID"
    exit 1
  fi

  MYSQL_BACKUP_DIR="${RANCHER_BACKUP_DIR}/mysql/$(date +%s)"
  mkdir -p ${MYSQL_BACKUP_DIR}
  cd ${MYSQL_BACKUP_DIR}
  docker cp ${RANCHER_ID}:/var/lib/mysql .
}


function installApps() {
  apt-get update -y
  apt-get upgrade -y
  apt-get install -y bzip2 git vim
}


function shellSetup() {
  git config --global url."https://".insteadOf git://
  rm ~/.bashrc ~/.bash_profile
  rm -rf ~/.bash_it
  git clone --depth=1 https://github.com/Bash-it/bash-it.git ~/.bash_it
  ~/.bash_it/install.sh --silent
  echo -e "\n\nsource /home/rancher/scripts/rancher-shell.sh" >> ~/.bashrc
  echo "export BASH_IT_THEME='sexy'" >> ~/.bashrc
  echo "source ~/.bashrc" > ~/.bash_profile
}


function proxySetup() {
 if [[ -z "${http_proxy}" ]]  || \
    [[ -z "${https_proxy}" ]] || \
    [[ -z "${no_proxy}" ]]; then
   echo "proxy variables not set!"
   exit 1
 else
   if [[ $(id -u) != 0 ]]; then
     echo "please run as root user"
     exit 1
   fi
  
   # docker proxy settings
   echo 'export http_proxy="'${http_proxy}'"' > /etc/default/docker
 fi
}


function installRoot() {
  # uncomment next line if you use a proxy
  # proxySetup
  installApps
  shellSetup
}

function installUser(){
  shellSetup
  installRancher
  # uncomment next line if you use a proxy and comment line above
  # installRancherProxy
}

