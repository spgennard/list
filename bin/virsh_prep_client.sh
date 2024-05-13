#!/bin/bash

if [ "x$(which yum 2>/dev/null)" == "x"  ];
then
	sudo apt install libnss-libvirt ## Debian/Ubuntu ##
else
	sudo yum install libvirt-nss ## RHEL/CentOS/Fedora ##
fi


if [ "x$(grep -w 'hosts:' /etc/nsswitch.conf | grep libvirt)" == "x" ];
then
	echo "/etc/nsswitch.conf need the following added:"
	echo " libvirt libvirt_guest"
	echo " in the files area"
fi
