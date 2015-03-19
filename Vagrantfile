# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/trusty64"
  config.vm.network "forwarded_port", guest: 80, host: 8080

  # using docker-compose (requires vagrant plugin vagrant-proxyconf)
  if Vagrant.has_plugin?("vagrant-proxyconf")
    config.proxy.no_proxy = "localhost,127.0.0.1,/var/run/docker.sock"
    config.vm.provision :shell, inline: 'cd /vagrant && ./docker-compose.sh'
    config.vm.provision :shell, inline: 'cd /vagrant && docker-compose up -d'
  else
 	config.vm.provision :shell, path: 'deploy.sh', privileged: false
  end
end
