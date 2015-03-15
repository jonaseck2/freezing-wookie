# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/trusty64"
  config.vm.network "forwarded_port", guest: 80, host: 8080
  config.vm.provision :shell, path: 'bootstrap.sh', privileged: false
  config.vm.provision "shell",
    inline: "docker-compose -f /vagrant/docker-compose.yml up -d --allow-insecure-ssl"
end
