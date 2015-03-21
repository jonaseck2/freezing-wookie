#!/usr/bin/env bash
sudo apt-get -qqy purge virtualbox

curl -Os https://dl.bintray.com/mitchellh/vagrant/vagrant_1.7.2_x86_64.deb
sudo dpkg -i vagrant_1.7.2_x86_64.deb
rm -f vagrant_1.7.2_x86_64.deb

mkdir -p ~/.gnupg
chmod 700 ~/.gnupg
touch ~/.gnupg/gpg.conf
chmod 600 ~/.gnupg/gpg.conf
sudo sh -c "echo deb http://download.virtualbox.org/virtualbox/debian trusty contrib > /etc/apt/sources.list.d/virtualbox.list"
curl -s http://download.virtualbox.org/virtualbox/debian/oracle_vbox.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -qqy install -qqy virtualbox-4.3