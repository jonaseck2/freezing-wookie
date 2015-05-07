#!/usr/bin/env bash

#installs docker and docker-compose

sudo apt-get update && sudo apt-get install -qqy curl cgroup-lite apparmor

#docker
curl -s https://get.docker.com/ | sh
sudo usermod -a -G docker `id -g -n` # requires relogin

#Compose
sudo bash -c "curl -sL https://raw.githubusercontent.com/docker/compose/1.2.0/contrib/completion/bash/docker-compose > /etc/bash_completion.d/docker-compose"
#use a forked compose until urls are supported again in 1.3.0
sudo bash -c "curl -sL https://github.com/jonaseck2/compose/releases/download/1.2.0-urlfix/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose"
sudo chmod +x /usr/local/bin/docker-compose
	