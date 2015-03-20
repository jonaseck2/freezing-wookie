# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/trusty64"
  config.vm.network "forwarded_port", guest: 80, host: 8080

  config.vm.provision :shell, path: 'docker-compose.sh', privileged: false
  # using docker-compose (requires vagrant plugin vagrant-proxyconf)
  if Vagrant.has_plugin?("vagrant-proxyconf")
    config.proxy.no_proxy = "localhost,127.0.0.1,/var/run/docker.sock"
    config.vm.provision :shell, inline: 'cd /vagrant && docker-compose up -d', privileged: false
  else
    config.vm.provision :shell, inline: 'cd /vagrant && ./deploy.sh', privileged: false
  end
end
