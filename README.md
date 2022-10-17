# server-hardening.sh
**HINWEIS**<br/>
Vor der Ausführung sollte die Sektion Allgemeines aus https://wiki.gruppe.ai/index.php/Server-Sicherheitskonzept bereits durchgeführt worden sein, da sonst der Port auf 22 default steht, dieser aber von dem Skript und UFW nicht geöffnet wird. Stattdessen wird Port 1461 für SSH geöffnet. Es besteht also die Gefahr, dass der Benutzer nach Ende des Session vom Server ausgesperrt wird.
**EMPFEHLUNG**<br/>
Vor des Ausführung es Skriptes ein Backup des Servers machen.<br/>
Das Skript sollte direkt nach der Aufsetzung des Servers und vor der Softwareinstallation ausgeführt werden.<br/>
Für Server auf denen bereits eine Vielzahl von Software läuft gibt es **keine Gewähr!!**
Wenn das Skript mit dem Argument --rsyslog-server aufgerufen wird, der Server in die Remote-Logging Infrastruktur eingebunden. Dafür ist es notwendig, VORHER ein Zertifikat bei mir zu beantragen.<br/>
Ein solches Zertifikat besteht aus einem Client-Cert und einem Client-Key. Beide Dateinamen müssen dem Skript ordnungsgemäß und mit Dateiendung angegeben werden.<br/>
Ebenso muss der Name des CA Zertifikates mit angegeben werden über das Argument --ca-cert. Dieses CA Zertifikat befindet sich hier in diesem Repo.<br/>
Der --rsyslog-server Befehl nimmt die IPv4 des Targteservers entgegen. Sofern hier nicht anders beschrieben, ist dies die 116.203.29.27.<br/>

Ein Befehl, wie ich ihn beispielsweise einsetze:<br/>
sudo ./server-hardening.sh --rsyslog-server 116.203.29.27 --client-key client-key.pem --client-cert client-cert.pem --ca-cert nerd_force1_UG_CA.pem --log-user dennisang --web`

# docker-hardening.sh
Dieses Skript nimmt sicherheitsrelevante Änderungen an dem Docker Daemon vor. Unter anderem auch das enforcen von User-Namespaces. Wer keine Ahnung hat, was genau das macht aber auch mit dem Bind-Mount auf dem Host <-> Container arbeiten möchte, sollte sich hierzu erstmal belesen. https://docs.docker.com/engine/security/userns-remap/

> Probleme mit VS-Code Remote nach ausführen des Skriptes.

Nach der Ausführung ist die Firewall auf Port 1461 für SSH offen. Ebenso ist in der SSH-Conf die Option **AllowTCPForwarding** auf **no** gesetzt. Diese muss für VS Code auf **yes** geändert werden.
