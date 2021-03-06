#!/bin/sh -e

INTERFACE="vtnet0"
PACKAGES="ca_root_nss virtualbox-ose-additions sudo bash"
VAGRANT_PUBLIC_KEY="https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub"

# Network configuration
echo 'hostname="vagrant"' >> /etc/rc.conf
echo 'ifconfig_'${INTERFACE}'="DHCP"' >> /etc/rc.conf
echo 'sshd_enable="YES"' >> /etc/rc.conf

# Start network services
service sshd keygen
service sshd start

# Add FreeBSD package repository
mkdir -p /usr/local/etc/pkg/repos
cat << EOT > /usr/local/etc/pkg/repos/FreeBSD.conf
FreeBSD: {
  url: "pkg+http://pkg.FreeBSD.org/\${ABI}/latest",
    enabled: yes
  }
EOT
env ASSUME_ALWAYS_YES=true /usr/sbin/pkg bootstrap -f
pkg update

# Install required packages
for package in ${PACKAGES}; do
  pkg install -y ${package}
done

# Activate vbox additions
echo 'vboxguest_enable="YES"' >> /etc/rc.conf
echo 'vboxservice_enable="YES"' >> /etc/rc.conf

# Activate installed root certifcates
ln -s /usr/local/share/certs/ca-root-nss.crt /etc/ssl/cert.pem

# Create the vagrant user
echo vagrant | pw useradd -n vagrant -s /usr/local/bin/bash -m -G wheel -H 0

# Enable sudo for vagrant user
mkdir /usr/local/etc/sudoers.d
echo "%vagrant ALL=(ALL) NOPASSWD: ALL" >> /usr/local/etc/sudoers.d/vagrant

# Authorize vagrant to login without a key
mkdir /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
touch /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant

# Get the public key and save it in the `authorized_keys`
fetch -o /home/vagrant/.ssh/authorized_keys ${VAGRANT_PUBLIC_KEY}

# Speed up boot process
echo 'autoboot_delay="1"' >> /boot/loader.conf

# Clean up installed packages
pkg clean -a -y

# Shrink final box file
echo 'Preparing disk for vagrant package command'
dd if=/dev/zero of=/tmp/out bs=1m > /dev/null 2>&1 || true

# Empty out tmp directory
rm -rf /tmp/*

# Remove the history
cat /dev/null > /root/.history

# Done
echo "Done. Power off the box and package it up with Vagrant using 'vagrant package'."

