#!/bin/bash

WD=/usr/src/Kamikaze2/

network_fixes() {
        cp $WD/interfaces /etc/network/
        sed -i 's/After=network.target auditd.service/After=auditd.service/' /etc/systemd/system/multi-user.target.wants/ssh.service
}

prep_ubuntu() {
	apt-get update
	echo "** Preparing Ubuntu for kamikaze2 **"
	cd /opt/scripts/tools/
	git pull
	sh update_kernel.sh --bone-kernel --lts-4_1
	apt-get -y upgrade
	apt-get -y install unzip iptables
	touch /etc/pm/sleep.d/wireless
	sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
}

remove_unneeded_packages() {
	echo "** Remove unneded packages **" 

	rm -rf /etc/apache2/sites-enabled
	rm -rf /root/.c9
	rm -rf /usr/local/lib/node_modules
	rm -rf /var/lib/cloud9
	rm -rf /usr/lib/node_modules/
	apt-get purge -y apache2 apache2-bin apache2-data apache2-utils
}

install_repo() {
	cat >/etc/apt/sources.list.d/testing.list <<EOL
#### Kamikaze ####
deb [arch=armhf] http://kamikaze.thing-printer.com/debian/ stretch main
EOL
	wget -q http://kamikaze.thing-printer.com/debian/public.gpg -O- | apt-key add -
	apt-get update
}

prep() {
	network_fixes
	prep_ubuntu
	remove_unneeded_packages
	install_repo
}

prep

echo "Now reboot into the new kernel and run make-kamikaze-2.1.sh"
