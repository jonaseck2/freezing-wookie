#!/usr/bin/env bash

#installs docker and docker-compose

sudo apt-get update && sudo apt-get install -qqy curl

#installing docker
if [ ! -x /usr/bin/docker ]; then
	curl -s https://get.docker.com/ | sh
	sudo usermod -a -G docker `id -g -n` # requires relogin
fi

#Installing Compose
if [ ! -x /usr/local/bin/docker-compose ]; then
	sudo bash -c "curl -sL https://raw.githubusercontent.com/docker/compose/1.1.0/contrib/completion/bash/docker-compose > /etc/bash_completion.d/docker-compose"
	sudo bash -c "curl -sL https://github.com/docker/compose/releases/download/1.1.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose"
	sudo chmod +x /usr/local/bin/docker-compose
fi