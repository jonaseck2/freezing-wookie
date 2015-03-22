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
	echo "GOOGLE_AUTH_PROXY_CLIENT_ID=default_client_id
GOOGLE_AUTH_PROXY_CLIENT_SECRET=default_client_secret
GOOGLE_AUTH_PROXY_COOKIE_SECRET=default_cookie_secret" > google_auth_proxy.env
fi
source ./google_auth_proxy.env
if [ -z $GOOGLE_AUTH_PROXY_CLIENT_ID ] || [ -z $GOOGLE_AUTH_PROXY_CLIENT_SECRET ] || [ -z $GOOGLE_AUTH_PROXY_COOKIE_SECRET ]; then
	echo "Invalid google_auth_proxy.env file, should set the environment variables"
	echo "GOOGLE_AUTH_PROXY_CLIENT_ID=<your client id here>"
	echo "GOOGLE_AUTH_PROXY_CLIENT_SECRET=<your client secret here>"
	echo "GOOGLE_AUTH_PROXY_COOKIE_SECRET=<your cookie secret here>"
	exit 1
fi

#name=${PWD##*/}
name="freezing-wookie"
sudo mkdir -p /var/${name}
cp -r proxy docker-compose.yml *.env /var/${name}/

# TODO the mustache file gets overwritten if the volume is mounted. Comment in the lines below and the yml to enable the volume
# if [ ! -d /var/katalog/tpl ] || [ -z /var/katalog/tpl/mustache.nginx ]; then
# 	#workaround to copy the nginx.mustache file from the container that gets overwritten when mounting the tpl volume
# 	sudo mkdir -p /var/katalog/
# 	rm -f tmp.cid 2> /dev/null
# 	sudo docker run -d --privileged --cidfile tmp.cid -v /var/run/docker.sock:/var/run/docker.sock joakimbeng/katalog
# 	sudo docker cp `cat tmp.cid`:/app/tpl/ /var/katalog/
# 	sudo docker kill `cat tmp.cid`
# 	sudo docker rm `cat tmp.cid`
# 	rm -f tmp.cid
# fi

sudo service ${name} stop 2> /dev/null
#logging sugar
cd /var/${name} && docker-compose pull && docker-compose build
sudo sh -c "echo '
description \"A job for running a ${name} docker-compose service\"
author \"Jonas Eckerström\"

start on filesystem and started docker on runlevel [2345]
stop on shutdown

exec sh -c \"cd /var/${name} && docker-compose up\"
respawn' > /etc/init/${name}.conf"

sudo init-checkconf /etc/init/${name}.conf || exit 1
sudo service ${name} start
