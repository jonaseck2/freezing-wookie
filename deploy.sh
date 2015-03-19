#!/usr/bin/env bash

#check prerequisites
if [ ! -f ./github_secret.env ]; then
	echo "creating default github_secret.env file"
	echo "This secret should match the configuration set in your github hooks"
	echo "GITHUB_SECRET=default_secret" > github_secret.env
fi
source ./github_secret.env
if [ -z $GITHUB_SECRET ]; then
	echo "Invalid github_secret.env file, should set environment variable"
	echo "GITHUB_SECRET=<your secret here>"
	exit 1
fi

if [ ! -f ./google_auth_proxy.env ]; then
	echo "creating default google_auth_proxy.env file"
	echo "For instructions how to obtain client id and client secret, see"
	echo "https://github.com/bitly/google_auth_proxy#oauth-configuration"
	echo "GOOGLE_AUTH_PROXY_CLIENT_ID=default_client_id\nGOOGLE_AUTH_PROXY_CLIENT_SECRET=default_client_secret" > google_auth_proxy.env
fi
source ./google_auth_proxy.env
if [ -z $GOOGLE_AUTH_PROXY_CLIENT_ID || -z $GOOGLE_AUTH_PROXY_CLIENT_SECRET ]; then
	echo "Invalid google_auth_proxy.env file, should set the environment variables"
	echo "GOOGLE_AUTH_PROXY_CLIENT_ID=<your client id here>"
	echo "GOOGLE_AUTH_PROXY_CLIENT_SECRET=<your client secret here>"
	exit 1
fi

#install docker if missing
if [ ! -x /usr/bin/docker ]; then
	sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
	sudo sh -c "echo deb https://get.docker.com/ubuntu docker main > /etc/apt/sources.list.d/docker.list"
	sudo apt-get update
	sudo apt-get -qqy install lxc-docker
	sudo usermod -a -G docker `id -g -n`  # emable running docker without sudo
fi
	
if [ ! -f /etc/init/mongo.conf ]; then
	sudo docker pull dockerfile/mongodb
	sudo mkdir -p /var/log/mongo
	sudo sh -c "echo '
description \"A job for running a MongoDB docker container\"
author \"Joakim Carlstein\"

start on filesystem on runlevel [2345]
stop on shutdown

exec docker run --rm -p 27017:27017 -v /var/mongo/db:/data/db dockerfile/mongodb >> /var/log/mongo/mongo.log
respawn' > /etc/init/mongo.conf"

	sudo init-checkconf /etc/init/mongo.conf
fi
sudo service mongo start

if [ ! -f /etc/init/katalog.conf ]; then
	sudo docker pull joakimbeng/katalog

	#workaround to copy the nginx.mustache file from the container that gets overwritten when sharing the tpl volume
	mkdir -p /var/katalog/
	rm -f tmp.cid
	docker run --privileged -d --cidfile tmp.cid -v /var/run/docker.sock:/var/run/docker.sock joakimbeng/katalog
	sudo docker cp `cat tmp.cid`:/app/tpl/ /var/katalog/
	docker kill `cat tmp.cid`
	rm -f tmp.cid

	sudo mkdir -p /var/log/katalog/

	sudo sh -c "echo '
description \"A job for running a Katalog docker container\"
author \"Joakim Carlstein\"

start on filesystem on runlevel [2345]
stop on shutdown

exec docker run --rm --privileged -p 5005:5005 -v /var/run/docker.sock:/var/run/docker.sock -v /var/katalog/tpl:/app/tpl -v /var/katalog/data:/app/data -v /var/katalog/nginx:/app/nginx joakimbeng/katalog >> /var/log/katalog/katalog.log
respawn' > /etc/init/katalog.conf"

	sudo init-checkconf /etc/init/katalog.conf
fi
sudo service katalog start

if [ ! -f /etc/init/nginx-proxy.conf ]; then
	sudo docker pull joakimbeng/nginx-site-watcher
	sudo mkdir -p /var/log/nginx
	sudo touch /var/log/nginx/nginx.log
	sudo sh -c "echo '
description \"A job for running a Nginx-site-watcher docker container\"
author \"Joakim Carlstein\"

start on filesystem on runlevel [2345]
stop on shutdown

exec docker run --rm -p 80:80 -v /etc/localtime:/etc/localtime:ro -v /var/katalog/nginx:/etc/nginx/sites-enabled -v /var/log/nginx:/var/log/nginx joakimbeng/nginx-site-watcher >> /var/log/nginx/nginx.log
respawn' > /etc/init/nginx-proxy.conf"
#remove 80:80 when adding oauth

	sudo init-checkconf /etc/init/nginx-proxy.conf
fi
sudo service nginx-proxy start

#api
if [ `docker images | grep laughing-batman | wc -l` -le 0 ]; then
	docker build -t softhouse/laughing-batman https://github.com/Softhouse/laughing-batman.git
fi
if [ `docker ps | grep laughing-batman | wc -l` -le 0  ]; then
	docker run -d --name softhouse_laughing-batman_1 -e GITHUB_SECRET=$GITHUB_SECRET -e KATALOG_VHOSTS=default/api -e MONGO_HOST=172.17.42.1 softhouse/laughing-batman
fi

#builder 
if [ `docker images | grep flaming-computing-machine | wc -l` -le 0 ];then  
	docker build -t softhouse/flaming-computing-machine https://github.com/Softhouse/flaming-computing-machine.git
fi
if [ `docker ps | grep flaming-computing-machine | wc -l` -le 0  ]; then
	docker run -d --name softhouse_flaming-computing-machine -v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/docker:/usr/bin/docker -e GITHUB_SECRET=$GITHUB_SECRET -e MONGO_HOST=172.17.42.1 softhouse/flaming-computing-machine
fi
