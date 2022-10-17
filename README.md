# server_scripts_sw
`
# server-hardening.sh
Wenn das Skript mit dem Argument --rsyslog-server aufgerufen wird, der Server in die Remote-Logging Infrastruktur eingebunden. Dafür ist es notwendig, VORHER ein Zertifikat bei mir zu beantragen.
Ein solches Zertifikat besteht aus einem Client-Cert und einem Client-Key. Beide Dateinamen müssen dem Skript ordnungsgemäß und mit Dateiendung angegeben werden.
Ebenso muss der Name des CA Zertifikates mit angegeben werden über das Argument --ca-cert. Dieses CA Zertifikat befindet sich hier in diesem Repo.
Der --rsyslog-server Befehl nimmt die IPv4 des Targteservers entgegen. Sofern hier nicht anders beschrieben, ist dies die 116.203.29.27.

Ein Befehl, wie ich ihn beispielsweise einsetze:
sudo ./server-hardening.sh --rsyslog-server 116.203.29.27 --client-key client-key.pem --client-cert client-cert.pem --ca-cert nerd_force1_UG_CA.pem --log-user dennisang --web`

# docker-hardening.sh
Dieses Skript nimmt sicherheitsrelevante Änderungen an dem Docker Daemon vor. Unter anderem auch das enforcen von User-Namespaces. Wer keine Ahnung hat, was genau das macht aber auch mit dem Bind-Mount auf dem Host <-> Container arbeiten möchte, sollte sich hierzu erstmal belesen. https://docs.docker.com/engine/security/userns-remap/
