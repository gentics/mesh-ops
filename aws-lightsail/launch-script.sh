#!/bin/bash

MESH_VERSION=1.4.0
HEAP_SIZE=256m
DIRECT_SIZE=64m
INITIAL_PW=admin
MESH_DIR=/opt/mesh-server

echo -e "\nConfiguring debian"
echo "deb http://deb.debian.org/debian stretch-backports main" > /etc/apt/sources.list.d/stretch-backports.list
apt-get update

echo -e "\nInstalling Open JRE 11"
apt-get install -y openjdk-11-jre-headless

echo -e "\nInstalling Gentics Mesh $MESH_VERISON"
mkdir -p $MESH_DIR
cd $MESH_DIR
wget https://maven.gentics.com/maven2/com/gentics/mesh/mesh-server/$MESH_VERSION/mesh-server-$MESH_VERSION.jar
ln -s mesh-server-$MESH_VERSION.jar mesh-server.jar


echo -e "\nPreparing service"
cat <<EOT > mesh-server.service
[Unit]
Description=Gentics Mesh Server
Wants=basic.target
After=basic.target network.target syslog.target

[Service]
User=mesh
Restart=on-failure
HEAP_SIZEcStart=/usr/bin/java -Xms$MEM -Xmx$MEM -XX:MaxDirectMemorySize=$DIRECT_SIZE -Dstorage.diskCache.bufferSize=64 -jar mesh-server.jar

WorkingDirectory=$MESH_DIR
LimitMEMLOCK=infinity
LimitNOFILE=65536
LimitAS=infinity
LimitRSS=infinity
LimitCORE=infinity
Environment=MESH_ELASTICSEARCH_URL=null
Environment=MESH_MONITORING_ENABLED=false
Environment=MESH_HTTP_PORT=8080
Environment=MESH_INITIAL_ADMIN_PASSWORD=$INITIAL_PW

[Install]
WantedBy=multi-user.target
EOT

echo -e "\nAdding user"
adduser --system --no-create-home --group mesh

echo -e "\nUpdating permissions"
chown mesh: $MESH_DIR -R

echo -e "\nEnabling service"
systemctl enable $MESH_DIR/mesh-server.service

echo -e "\nStarting service"
service mesh-server start


