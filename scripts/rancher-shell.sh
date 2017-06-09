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
# Configruation
#

# RANCHER_IP=

# proxy settings

# export http_proxy="http://your-proxy:8880"
# export https_proxy="${http_proxy}"
# export ftp_proxy="${http_proxy}"
# export no_proxy="localhost,127.0.0.1"


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
alias top="htop"


#
# functions
#


function installRancher() {
  # persist the mysql database to a docker volume
  docker volume create --name rancher-mysql

  docker run -d \
    --restart=unless-stopped \
    -v rancher-mysql:/var/lib/mysql \
    -p 8080:8080 \
  rancher/server:latest
}

function installRancherHA() {
  if [[ -z "${RANCHER_IP}" ]]; then
    echo "proxy variables not set!"
    exit 1
  else
    # persist the mysql database to a docker volume
    docker volume create --name rancher-mysql

    docker run -d \
      --restart=unless-stopped \
      -v rancher-mysql:/var/lib/mysql \
      -p 3306:3306 \
      -p 8080:8080 \
      -p 9345:9345 \
    rancher/server:stable \
      --advertise-address ${RANCHER_IP}
  fi

  #    -p 500:500/udp \
  #    -p 4500:4500/udp \

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
  apt-get update -y && \
  apt-get upgrade -y && \
  apt-get install -y \
    bzip2 \
    git \
    vim \
    linux-generic \
    htop
    # dnsutils \
    # dosfstools \
    # iputils-ping \
    # bsdmainutils

  # install docker-clean
  curl -s https://raw.githubusercontent.com/ZZROTDesign/docker-clean/master/docker-clean \
    | sudo tee /usr/local/bin/docker-clean > /dev/null && \
    sudo chmod +x /usr/local/bin/docker-clean
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

function docker-clean-unnamed-container() {
  docker rmi --force $(docker images -a | grep "^<none>" | awk '{print $3}')
}


function container_update() {
  echo updating containers ...
  docker images | grep -v "REPOSITORY" | awk '{print $1":"$2}' | xargs -L1 docker pull
}


function installRoot() {
  installApps
  shellSetup
  # uncomment next line if you use a proxy
  # proxySetup
}

function installUser(){
  shellSetup
  installRancher
  # uncomment next line if you use a proxy and comment line above
  # installRancherProxy
}

