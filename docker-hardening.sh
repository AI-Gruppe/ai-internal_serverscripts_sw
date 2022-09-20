#!/bin/bash
RED=$(tput setaf 1) GREEN=$(tput setaf 2) YELLOW=$(tput setaf 3)
NC=$(tput sgr0)
skipped="${GREEN}[Skipped]$NC"
installed="${GREEN}[Installed]$NC"
installing="${YELLOW}[Installing]$NC"
missing="${RED}[Missing]$NC"
cdone="${GREEN}[Done]$NC"
failed="${RED}Installation failed$NC"

install_if_missing(){
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' "$1"|grep "install ok installed")
if [ "" = "$PKG_OK" ]; then
printf '%-20s %s\n' "$missing" "$1" 
    printf '%-20s %s\n' "$installing" "$1" 
    if sudo apt install -qq "$1" -y > /dev/null 2>&1; then
        printf '%-20s %s\n' "$installed" "$1" 
    else
        printf "%s\n" "$failed"
        exit 1
    fi
else
    printf '%-20s %s\n' "$skipped" "$1" 
fi
}

run_sudo_silent() { #(Command, Message)
    bash -c "sudo $1" > /dev/null;
    printf '%-20s %s\n' "$cdone" "$2" 
}

set_in_file(){
    bash -c "echo -e '$1' >> $2"
}

done_action(){
        printf '%-20s %s\n' "$cdone" "$1" 
}

run_sudo_silent "systemctl stop docker.socket" "Stop docker.socket"
run_sudo_silent "systemctl stop docker" "Stop docker.service"
set_in_file "## Docker Additional Security\n-w /run/containerd/containerd.sock -k docker\n
-w /usr/lib/systemd/system/docker.service -k docker\n-w /etc/docker -k docker\n
-w /usr/bin/containerd -k docker\n-w /var/run/docker.sock -k docker\n-w /etc/default/docker -k docker" "/etc/audit/rules.d/audit.rules"
set_in_file "-w /etc/docker/daemon.json -k docker\n-w /etc/containerd/config.toml -k docker\n-w /etc/sysconfig/docker -k docker\n
-w /usr/bin/containerd-shim-runc-v2 -k docker\n-w /usr/bin/containerd-shim-runc-v1 -k docker\n-w /usr/bin/containerd-shim -k docker\n-w /usr/bin/docker-runc -k docker" "/etc/audit/rules.d/audit.rules"
run_sudo_silent "dockerd --icc=false" "Disable docker ICC on default bridge"
run_sudo_silent "dockerd --userns-remap=default" "Enable docker usernamespace"


run_sudo_silent "systemctl start docker.socket" "Start docker.socket"
run_sudo_silent "systemctl start docker" "Start docker.service"