# Install virt-manager
sudo apt install -y virt-manager

# Add youself to kvm and libvirt group
sudo usermod --append --groups kvm,libvirt "${USER}"

# Fix-up permission to avoid "Could not access KVM kernel module: Permission denied" error
sudo chown root:kvm /dev/kvm
sudo chmod 660 /dev/kvm

if ! grep "nestedVirtualization\=true" /etc/wsl.conf 2>1 >/dev/null
then
	echo 
echo "Need to add the following to /etc/wsl.conf

[wsl2]
nestedVirtualization=true
"

fi

#[boot]
#systemd=true
#command = /bin/bash -c 'chown -v root:kvm /dev/kvm && chmod 660 /dev/kvm'
#
#[network]
#generateResolvConf = true
#
#[wsl2]
#nestedVirtualization=true

