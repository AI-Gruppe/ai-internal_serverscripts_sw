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
    bash -c "sudo $1" > /dev/null 2>&1;
    printf '%-20s %s\n' "$cdone" "$2" 
}

set_in_file(){
    bash -c "echo -e '$1' >> $2"
}

done_action(){
        printf '%-20s %s\n' "$cdone" "$1" 
}

run_sudo_silent "apt-get update && sudo apt-get install docker-scan-plugin" "Install docker vuln-scan"
run_sudo_silent "systemctl stop docker.socket" "Stop docker.socket"
run_sudo_silent "systemctl stop docker >/dev/null 2>&1" "Stop docker.service"
run_sudo_silent "touch /etc/audit/rules.d/docker.rules" "Create auditd docker config"
set_in_file "## Docker Additional Security\n-w /run/containerd/containerd.sock -k docker\n
-w /usr/lib/systemd/system/docker.service -k docker\n-w /etc/docker -k docker\n
-w /usr/bin/containerd -k docker\n-w /var/run/docker.sock -k docker\n-w /etc/default/docker -k docker
-w /etc/docker/daemon.json -k docker\n-w /etc/containerd/config.toml -k docker\n-w /etc/sysconfig/docker -k docker\n-w /usr/bin/runc -k docker\n
-w /usr/bin/containerd-shim-runc-v2 -k docker\n-w /usr/bin/containerd-shim-runc-v1 -k docker\n-w /usr/bin/containerd-shim -k docker\n-w /usr/bin/docker-runc -k docker" "/etc/audit/rules.d/docker.rules"
done_action "Configure Auditd"
run_sudo_silent "touch /etc/docker/daemon.json" "Create docker daemon config"
set_in_file "{\"userns-remap\": \"default\",\"icc\": false,\"no-new-privileges\": true,\"live-restore\": true,\"userland-proxy\": false}" "/etc/docker/daemon.json"
run_sudo_silent "systemctl start docker.socket" "Start docker.socket"
run_sudo_silent "systemctl start docker" "Start docker.service"
run_sudo_silent "pkill -HUP auditd" "Auditd config reload"
run_sudo_silent "service auditd restart" "Restart Auditd"