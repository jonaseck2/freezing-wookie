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
GOOGLE_AUTH_PROXY_CLIENT_SECRET=default_client_secret" > google_auth_proxy.env
fi
source ./google_auth_proxy.env
if [ -z $GOOGLE_AUTH_PROXY_CLIENT_ID ] || [ -z $GOOGLE_AUTH_PROXY_CLIENT_SECRET ]; then
	echo "Invalid google_auth_proxy.env file, should set the environment variables"
	echo "GOOGLE_AUTH_PROXY_CLIENT_ID=<your client id here>"
	echo "GOOGLE_AUTH_PROXY_CLIENT_SECRET=<your client secret here>"
	exit 1
fi

name=${PWD##*/}
sudo mkdir -p /var/log/$name

#mongodb
sudo service $name-mongodb stop 2> /dev/null
sudo docker pull dockerfile/mongodb
sudo sh -c "echo '
description \"A job for running a MongoDB docker container\"
author \"Joakim Carlstein\"

start on filesystem on runlevel [2345]
stop on shutdown

exec docker run --rm --name mongodb \
--expose=27017 \
-v /var/mongodb/db:/data/db \
dockerfile/mongodb \
>> /var/log/$name/mongodb.log
respawn' > /etc/init/$name-mongodb.conf"

sudo init-checkconf /etc/init/$name-mongodb.conf || exit 1
sudo service $name-mongodb start

#katalog
sudo service $name-katalog stop 2> /dev/null
sudo docker pull joakimbeng/katalog

if [ ! -d /var/katalog/tpl ] || [ -z /var/katalog/tpl/mustache.nginx ]; then
	#workaround to copy the nginx.mustache file from the container that gets overwritten when mounting the tpl volume
	sudo mkdir -p /var/katalog/
	rm -f tmp.cid 2> /dev/null
	sudo docker run -d --privileged --cidfile tmp.cid -v /var/run/docker.sock:/var/run/docker.sock joakimbeng/katalog
	sudo docker cp `cat tmp.cid`:/app/tpl/ /var/katalog/
	sudo docker kill `cat tmp.cid`
	sudo docker rm `cat tmp.cid`
	rm -f tmp.cid
fi

sudo sh -c "echo '
description \"A job for running a Katalog docker container\"
author \"Joakim Carlstein\"

start on filesystem on runlevel [2345]
stop on shutdown

exec docker run --rm \
--name=katalog \
--privileged \
--expose=5005 \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /var/katalog/tpl:/app/tpl \
-v /var/katalog/data:/app/data \
-v /var/katalog/nginx:/app/nginx \
joakimbeng/katalog \
>> /var/log/$name/katalog.log
respawn' > /etc/init/$name-katalog.conf"

sudo init-checkconf /etc/init/$name-katalog.conf || exit 1
sudo service $name-katalog start

#sitewatcher
sudo service $name-sitewatcher stop 2> /dev/null
sudo docker pull joakimbeng/nginx-site-watcher
sudo sh -c "echo '
description \"A job for running a Nginx-site-watcher docker container\"
author \"Joakim Carlstein\"

start on filesystem on runlevel [2345]
stop on shutdown

exec docker run --rm \
--name sitewatcher \
--expose=80 \
-v /etc/localtime:/etc/localtime:ro \
-v /var/katalog/nginx:/etc/nginx/sites-enabled \
-v /var/log/$name/sitewatcher:/var/log/nginx \
joakimbeng/nginx-site-watcher \
>> /var/log/$name/sitewatcher.log
respawn' > /etc/init/$name-sitewatcher.conf"

sudo init-checkconf /etc/init/$name-sitewatcher.conf || exit 1
sudo service $name-sitewatcher start

#api
sudo service $name-api stop 2> /dev/null
if [ `docker images | grep laughing-batman | wc -l` -le 0 ]; then
	sudo docker build -t softhouse/laughing-batman https://github.com/Softhouse/laughing-batman.git
fi
sudo sh -c "echo '
description \"A job for running a laughing-batman docker container\"
author \"Jonas Eckerström\"

start on filesystem on runlevel [2345]
stop on shutdown

exec docker run --rm \
--name api \
--env-file=$(pwd)/github_secret.env \
-e KATALOG_VHOSTS=default/api \
-e MONGO_HOST=mongodb \
--link=mongodb:mongodb \
softhouse/laughing-batman \
>> /var/log/$name/api.log
respawn' > /etc/init/$name-api.conf"

sudo init-checkconf /etc/init/$name-api.conf || exit 1
sudo service $name-api start

#builder
sudo service $name-builder stop 2> /dev/null
if [ `docker images | grep flaming-computing-machine | wc -l` -le 0 ];then
	sudo docker build -t softhouse/flaming-computing-machine https://github.com/Softhouse/flaming-computing-machine.git
fi
sudo sh -c "echo '
description \"A job for running a flaming-computing-machine docker container\"
author \"Jonas Eckerström\"

start on filesystem on runlevel [2345]
stop on shutdown

exec docker run --rm --name builder \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /usr/bin/docker:/usr/bin/docker \
--env-file=$(pwd)/github_secret.env \
-e MONGO_HOST=mongodb \
--link=mongodb:mongodb \
softhouse/flaming-computing-machine \
>> /var/log/$name/builder.log
respawn' > /etc/init/$name-builder.conf"

sudo init-checkconf /etc/init/$name-builder.conf || exit 1
sudo service $name-builder start

#googleauth
sudo service $name-googleauth stop 2> /dev/null
sudo docker pull a5huynh/google-auth-proxy
sudo sh -c "echo '
description \"A job for running a google-auth-proxy docker container\"
author \"Jonas Eckerström\"

start on filesystem on runlevel [2345]
stop on shutdown

exec docker run --rm --name googleauth \
--expose=4180 \
--env-file=$(pwd)/google_auth_proxy.env \
--link=sitewatcher:sitewatcher \
a5huynh/google-auth-proxy \
--upstream=http://sitewatcher \
--http-address=0.0.0.0:4180 \
--cookie-https-only=false \
--redirect-url=\"http://localhost/oauth2/callback\" \
--google-apps-domain=\"softhouse.se\" \
>> /var/log/$name/googleauth.log
respawn' > /etc/init/$name-googleauth.conf"

sudo init-checkconf /etc/init/$name-googleauth.conf || exit 1
sudo service $name-googleauth start

#proxy
sudo service $name-proxy stop 2> /dev/null
sudo docker pull a5huynh/google-auth-proxy
sudo sh -c "echo '
description \"A job for running a google-auth-proxy docker container\"
author \"Jonas Eckerström\"

start on filesystem on runlevel [2345]
stop on shutdown

exec docker run --rm --name proxy \
--env-file=$(pwd)/github_secret.env \
--link=googleauth:googleauth \
-v $(pwd)/proxy/nginx/sites-enabled:/etc/nginx/sites-enabled \
-v $(pwd)/proxy/nginx/nginx.conf:/etc/nginx.conf \
-v /var/log/$name/proxy:/var/log/nginx \
-p 80:80 \
dockerfile/nginx \
>> /var/log/$name/proxy.log
respawn' > /etc/init/$name-proxy.conf"

sudo init-checkconf /etc/init/$name-proxy.conf || exit 1
sudo service $name-proxy start
