#!/bin/bash

set -o nounset
set -o errexit

MESH_VERSION=${MESH_VERSION:-1.4.0}
HEAP_SIZE=${HEAP_SIZE:-256m}
DIRECT_SIZE=${DIRECT_SIZE:-64m}
INITIAL_PW=${INITIAL_PW:-admin}
MESH_DIR=${MESH_DIR:-/opt/mesh-server}

# 250 MB
MESH_BINARY_UPLOAD_LIMIT=${MESH_BINARY_UPLOAD_LIMIT:-262144000}
MESH_HTTP_CORS_ENABLE=${MESH_HTTP_CORS_ENABLE:-false}
MESH_HTTP_CORS_ALLOW_CREDENTIALS=${MESH_HTTP_CORS_ALLOW_CREDENTIALS:-false}
MESH_HTTP_CORS_ORIGIN_PATTERN=${MESH_HTTP_CORS_ORIGIN_PATTERN:-""}
MESH_BINARY_DOCUMENT_PARSER=${MESH_BINARY_DOCUMENT_PARSER:-false}
MESH_DEBUGINFO_LOG_ENABLED=${MESH_DEBUGINFO_LOG_ENABLED:-false}

# Settings
MESH_ELASTICSEARCH_URL=${MESH_ELASTICSEARCH_URL:-null}
MESH_HTTP_PORT=${MESH_HTTP_PORT:-80}

echo -e "\nInstalling Open JRE 11"
apt-get update
apt-get install -y openjdk-11-jre-headless

echo -e "\nInstalling Gentics Mesh $MESH_VERSION"
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
ExecStart=/usr/bin/java -Xms$HEAP_SIZE -Xmx$HEAP_SIZE -XX:MaxDirectMemorySize=$DIRECT_SIZE -Dstorage.diskCache.bufferSize=64 -jar mesh-server.jar

WorkingDirectory=$MESH_DIR
LimitMEMLOCK=infinity
LimitNOFILE=65536
LimitAS=infinity
LimitRSS=infinity
LimitCORE=infinity
AmbientCapabilities=CAP_NET_BIND_SERVICE

Environment=MESH_ELASTICSEARCH_URL=$MESH_ELASTICSEARCH_URL
Environment=MESH_MONITORING_ENABLED=false
Environment=MESH_HTTP_PORT=$MESH_HTTP_PORT
Environment=MESH_INITIAL_ADMIN_PASSWORD=$INITIAL_PW
Environment=MESH_HTTP_CORS_ENABLE=$MESH_HTTP_CORS_ENABLE
Environment=MESH_HTTP_CORS_ALLOW_CREDENTIALS=$MESH_HTTP_CORS_ALLOW_CREDENTIALS
Environment=MESH_HTTP_CORS_ORIGIN_PATTERN=$MESH_HTTP_CORS_ORIGIN_PATTERN
Environment=MESH_DEBUGINFO_LOG_ENABLED=$MESH_DEBUGINFO_LOG_ENABLED
Environment=MESH_BINARY_DOCUMENT_PARSER=$MESH_BINARY_DOCUMENT_PARSER
Environment=MESH_BINARY_UPLOAD_LIMIT=$MESH_BINARY_UPLOAD_LIMIT

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
