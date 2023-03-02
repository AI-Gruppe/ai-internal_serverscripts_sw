#!/bin/bash
RED=$(tput setaf 1) GREEN=$(tput setaf 2) YELLOW=$(tput setaf 3)
NC=$(tput sgr0)
skipped="${GREEN}[Skipped]$NC"
installed="${GREEN}[Installed]$NC"
installing="${YELLOW}[Installing]$NC"
missing="${RED}[Missing]$NC"
cdone="${GREEN}[Done]$NC"
failed="${RED}Installation failed$NC"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) help="$2"; shift ;;
        --local-logs) locallogs="$2"; shift ;;
        --rsyslog-server) logserver="$2"; shift ;;
        --client-key) clientkey="$2"; shift ;;
        --client-cert) clientcert="$2"; shift ;;
        --ca-cert) cacert="$2"; shift ;;
        --log-user) loguser="$2"; shift ;;
        --web) webconf="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if ! [ -z ${help+x} ]; then
    echo "Usage: [--rsyslog-client 0.0.0.0 OR --rsyslog-server + --log-user USERNAME]"
    echo ""
    echo "  --local-logs               Logs stored only localy (do not provide --rsyslog-server when --local-logs is already set)"
    echo "  --rsyslog-server [IPv4]    Configures the device as a log sending client + Enter the rsyslog-server ipv4 (mandatory)"
    echo "  --client-key               Filename of the client keyfile. Same folder as script (mandatory if --rsyslog-server is set)"
    echo "  --client-cert              Filename of the client certfile. Same folder as script (mandatory if --rsyslog-server is set)"
    echo "  --ca-cert                  Filename of the CA certfile. Same folder as script (mandatory if --rsyslog-server is set)"
    echo "  --log-user [Username]      Username of the user who is allowed to view the logs (always mandatory)"
    echo "  --web                      Configures the firewall to allow *80 *443 (optional)"
    echo "  -h or --help               help (this output)"
    echo ""
    echo "Client certificates must be requested from the administrator"
    echo ""
    exit 0 
fi

if [ -z ${locallogs+x} ]; then
    if [ -z ${logserver+x} ]; then
        echo "No rsyslog configuration parameter provided"
        echo "Specify either --local-logs or --rsyslog-server"
        exit 1
    fi
fi

if [ -z ${loguser+x} ]; then
        echo "No Username for the logs provided"
        exit 1
fi

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

run_sudo_silent "timedatectl set-timezone Europe/Berlin"
run_sudo_silent "apt-get -y update" "Update repository"
########## DNSSEC ##########
set_in_file "DNSSEC=yes\nDNSOverTLS=yes" "/etc/systemd/resolved.conf"
done_action "Configure DNSSEC"
run_sudo_silent "systemctl restart systemd-resolved" "Restart DNS"

########## Process Accounting ##########
install_if_missing "acct"
run_sudo_silent "/usr/sbin/accton on" "Configure Process accounting"

########## Disable Coredump ##########
set_in_file "* hard core 0\n* soft core 0" "/etc/security/limits.conf"
set_in_file "fs.suid_dumpable=0\nkernel.core_pattern=|/bin/false" "/etc/sysctl.d/9999-disable-core-dump.conf"
done_action "Coredumpprevention configuration"
run_sudo_silent "sysctl -p /etc/sysctl.d/9999-disable-core-dump.conf" "Coredumpprevention applied"

########## SSH Hardening ##########
run_sudo_silent "rm /etc/issue && sude rm /etc/issue.net && sudo touch /etc/issue /etc/issue.net" "Set login banner"
set_in_file "###############################################################
#                          Nerd Force1                        #
#       All connections are monitored and recorded.           #
#  Disconnect IMMEDIATELY if you are not an authorized user!  #
###############################################################" "/etc/issue"
run_sudo_silent "cp /etc/issue /etc/issue.net" "Legal banner set"
run_sudo_silent "sed -i '/PasswordAuthentication/c\PasswordAuthentication no' /etc/ssh/sshd_config
set_in_file "Banner /etc/issue.net\nAllowTcpForwarding no\nClientAliveCountMax 2\nCompression no\nLogLevel VERBOSE\n
MaxAuthTries 3\nMaxSessions 2\nTCPKeepAlive no\nX11Forwarding no\nAllowAgentForwarding no\n" "/etc/ssh/sshd_config"
run_sudo_silent "sed -i '/X11Forwarding/c\X11Forwarding no' /etc/login.defs" "Disable X11Forwarding"
done_action "SSH service configuration"
run_sudo_silent "service ssh restart" "SSH service restart"

########## Compiler Hardening ##########
run_sudo_silent "chmod o-rx /usr/bin/as"

########## Software Components ##########
install_if_missing "libpam-tmpdir"
install_if_missing "apt-listchanges"
install_if_missing "needrestart"
install_if_missing "debsecan"

########## Fail2Ban ##########
install_if_missing "fail2ban"
set_in_file "[sshd]\nenabled = true\nport = 1461\nfilter = sshd\nlagpath = /var/log/auth.log\nmaxretry = 3\nbantime = 6h\nignoreip = 127.0.0.1" "/etc/fail2ban/jail.local"
run_sudo_silent "systemctl enable fail2ban.service" "Enable fail2ban on startup"
run_sudo_silent "systemctl restart fail2ban.service" "Reload fail2ban"

########## System Drive ##########
set_in_file "blacklist usb-storage\nblacklist firewire_core\nblacklist firewire_ohci" "/etc/modprobe.d/blacklist.conf"
run_sudo_silent "update-initramfs -u" "Block firewire + USB"

########## Secure and Rebase Users ##########
run_sudo_silent "deluser lp;sudo deluser news;sudo deluser uucp;sudo deluser www-data;sudo deluser list;sudo deluser irc;sudo deluser gnats;sudo deluser nobody;" "CleanUp users"
set_in_file "SHA_CRYPT_MIN_ROUNDS 10000\nSHA_CRYPT_MAX_ROUNDS 10000" "/etc/login.defs"
done_action "SHA_CRYPT_MIN_ROUNDS"
install_if_missing "libpam-cracklib"
run_sudo_silent "cp /etc/pam.d/common-password /etc/pam.d/common-password.bak" "Common password backup"
set_in_file "password required pam_cracklib.so try_first_pass retry=3 minlen=10 lcredit=1 ucredit=1 dcredit=2 ocredit=1 difok=1 reject_username" "/etc/pam.d/common-password"
done_action "Set Passwordpolicy"
run_sudo_silent "sed -i '/UMASK\t\t022/c\UMASK\t\t027' /etc/login.defs" "Change UMASK"

########## RK-Hunter ##########
install_if_missing "rkhunter"
run_sudo_silent "rkhunter rkhunter -c --skip-keypress --display-logfile --rwo --propupd" "Scanning for Rootkits"
done_action "Rootkithunter configured"

########## Auditd + Laurel ##########
install_if_missing "auditd"
install_if_missing "wget"
run_sudo_silent "rm /etc/audit/rules.d/audit.rules" "Remove default ruleset"
run_sudo_silent "sed -i '/max_log_file/c\max_log_file = 7000' /etc/audit/auditd.conf && sudo sed -i '/num_logs/c\num_logs = 2' /etc/audit/auditd.conf" "Configure Auditd"
set_in_file "max_log_file_action = rotate" "/etc/audit/auditd.conf"
run_sudo_silent "wget 'https://raw.githubusercontent.com/Neo23x0/auditd/master/audit.rules' -O /etc/audit/rules.d/audit.rules" "Set new ruleset"
run_sudo_silent "curl -OL https://github.com/threathunters-io/laurel/releases/download/v0.4.1/laurel-v0.4.1-x86_64-glibc.tar.gz" "Download laurel 0.4.1"
run_sudo_silent "tar xzf laurel-v0.4.1-x86_64-glibc.tar.gz laurel" "Unpack laurel"
run_sudo_silent "install -m755 laurel /usr/local/sbin/laurel" "Install laurel"
run_sudo_silent "useradd --system --home-dir /var/log/laurel --create-home _laurel && mkdir /etc/laurel" "Create user _laurel"
run_sudo_silent "wget 'https://raw.githubusercontent.com/threathunters-io/laurel/master/etc/laurel/config.toml' -O /etc/laurel/config.toml" "Configure laurel"
run_sudo_silent "sed -i '/read-users/c\read-users = [ \"${loguser}\" ]' /etc/laurel/config.toml" "Added ${loguser} to config"
set_in_file "active = yes\ndirection = out\ntype = always\nformat = string\npath = /usr/local/sbin/laurel\nargs = --config /etc/laurel/config.toml" "/etc/audit/plugins.d/laurel.conf"
run_sudo_silent "service auditd start" "Audidt Service start"
run_sudo_silent "systemctl enable auditd" "Enable Auditd"
run_sudo_silent "pkill -HUP auditd" "Auditd config reload"

########## Package Overwatch ##########
install_if_missing "debsums"

########## Disable Protocols ##########
set_in_file "install dccp /bin/true" "/etc/modprobe.d/nodccp"

########## UFW Firewall ##########
install_if_missing "ufw"
run_sudo_silent "ufw default deny incoming" "UFW deny incoming"
run_sudo_silent "ufw default allow outgoing" "UFW allow outgoing"
if ! [ -z ${logserver+x} ]; then
    run_sudo_silent "ufw allow 6514/tcp" "Enable 6514/tcp"
fi
run_sudo_silent "ufw allow 1461/tcp" "Enable 1461/tcp"
if ! [ -z ${webconf+x} ]; then
    run_sudo_silent "ufw allow 80/tcp" "Enable 80/tcp"
    run_sudo_silent "ufw allow 443/tcp" "Enable 443/tcp"
fi
set_in_file "IPV6=yes" "/etc/default/ufw"
done_action "Enable ipv6"
run_sudo_silent "echo 'y' | ufw enable" "Enable firewall"
run_sudo_silent "service ufw restart" "Restart firewall"

########## Remote Logs ##########
if ! [ -z ${logserver+x} ]; then
    install_if_missing "rsyslog"
    if ! [ -z ${logserver+x} ]; then
        install_if_missing "gnutls-bin"
        install_if_missing "rsyslog-gnutls" 
        run_sudo_silent "mkdir /etc/rsyslog-keys" "Create /etc/rsyslog-keys"
        run_sudo_silent "mv \$(pwd)/*.pem /etc/rsyslog-keys" "Copy keys"
        run_sudo_silent "chown -R 0:0 /etc/rsyslog-keys && sudo chmod 700 -R /etc/rsyslog-keys" "Setting root as keys owner"
    fi
    run_sudo_silent "cp /etc/rsyslog.conf /etc/rsyslog_original.config" "Config backup"
    run_sudo_silent "touch /etc/rsyslog.d/laurel.conf" "Create custom config"
    if ! [ -z ${logserver+x} ]; then
    set_in_file "module(load=\"imfile\")\ninput(type=\"imfile\" File=\"/var/log/laurel/audit*.log\" Tag=\"\" ruleset=\"remote\")\nruleset(name=\"remote\"){\n
    action(type=\"omfwd\" target=\"${logserver}\" port=\"6514\" protocol=\"tcp\"\nStreamDriver=\"gtls\" StreamDriverMode=\"1\" StreamDriverAuthMode=\"anon\")}" "/etc/rsyslog.d/laurel.conf"
    done_action "Configure ${logserver} as logging target"
    set_in_file "\$DefaultNetstreamDriver gtls\n\$DefaultNetstreamDriverCAFile /etc/rsyslog-keys/${cacert}\n\$DefaultNetstreamDriverCertFile /etc/rsyslog-keys/${clientcert}\n
    \$DefaultNetstreamDriverKeyFile /etc/rsyslog-keys/${clientkey}\n\$ActionSendStreamDriverMode 1\n\$ActionSendStreamDriverAuthMode anon" "/etc/rsyslog.conf"
    done_action "Configure rsyslog TLS"
    fi
    run_sudo_silent "systemctl enable --now rsyslog" "Enable rsyslog"
    run_sudo_silent "systemctl restart rsyslog" "Restart rsyslog"
fi
########## Final Changes ##########
install_if_missing "apt-listbugs"
run_sudo_silent "rm laurel*" "Cleaning up"
done_action "Rebooting system now"
run_sudo_silent "reboot" "Reboot System"
########## Lynis ##########
#install_if_missing "apt-transport-https"
#run_sudo_silent "wget -O - https://packages.cisofy.com/keys/cisofy-software-public.key | sudo apt-key add -" "Get Cisofy PubKey"
#run_sudo_silent "echo \"deb https://packages.cisofy.com/community/lynis/deb/ stable main\" | sudo tee /etc/apt/sources.list.d/cisofy-lynis.list" "Configure sources.list"
#run_sudo_silent "apt-get -y update" "Update repository"
#install_if_missing "lynis"
