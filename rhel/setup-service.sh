#!/bin/bash

mkdir -p $MESH_DIR
MESH_GRAPH_DB_DIRECTORY=${MESH_DIR}/graphdb
MESH_LOCK_PATH=${MESH_DIR}/.meshlock

cat <<EOT > mesh-server.service
[Unit]
Description=Gentics Mesh Server
Wants=basic.target
After=basic.target network.target syslog.target

[Service]
User=mesh
Restart=on-failure
ExecStart=/usr/bin/java -Xms${HEAP_MEM}m -Xmx${HEAP_MEM}m -XX:MaxDirectMemorySize=${DIRECT_MEM}m -Dstorage.diskCache.bufferSize=${BUFFER_MEM} -jar ${MESH_COMMON}/mesh-server.jar
WorkingDirectory=${MESH_DIR}
LimitMEMLOCK=infinity
LimitNOFILE=65536
LimitAS=infinity
LimitRSS=infinity
LimitCORE=infinity

# Features
Environment=MESH_MONITORING_ENABLED=false
Environment=MESH_UPDATECHECK=false
Environment=MESH_DEBUGINFO_LOG_ENABLED=false
Environment=MESH_BINARY_DOCUMENT_PARSER=${MESH_BINARY_DOCUMENT_PARSER}
Environment=MESH_DEFAULT_LANG=${MESH_DEFAULT_LANG}

# Auth
Environment=MESH_AUTH_KEYSTORE_PASS=${MESH_AUTH_KEYSTORE_PASS}

# ES
Environment=MESH_ELASTICSEARCH_URL=null
Environment=MESH_ELASTICSEARCH_START_EMBEDDED=false

# Ports
Environment=MESH_MONITORING_HTTP_PORT=${MESH_MONITORING_HTTP_PORT}
Environment=MESH_HTTP_PORT=${MESH_HTTP_PORT}

# Clustering
Environment=MESH_NODE_NAME=${MESH_NODE_NAME}
Environment=MESH_CLUSTER_VERTX_PORT=${MESH_VERTX_PORT}
Environment=MESH_CLUSTER_NAME=${MESH_CLUSTER_NAME}
Environment=MESH_CLUSTER_ENABLED=${MESH_CLUSTER_ENABLED}
Environment=MESH_CLUSTER_INIT=${MESH_CLUSTER_INIT}

# Paths
Environment=MESH_AUTH_KEYSTORE_PATH=${MESH_AUTH_KEYSTORE_PATH}
Environment=MESH_GRAPH_EXPORT_DIRECTORY=${MESH_GRAPH_EXPORT_DIRECTORY}
Environment=MESH_GRAPH_BACKUP_DIRECTORY=${MESH_GRAPH_BACKUP_DIRECTORY}
Environment=MESH_BINARY_DIR=${MESH_BINARY_DIR}
Environment=MESH_TEMP_DIR=${MESH_TEMP_DIR}
Environment=MESH_GRAPH_DB_DIRECTORY=${MESH_GRAPH_DB_DIRECTORY}
Environment=MESH_BINARY_UPLOAD_TEMP_DIR=${MESH_BINARY_UPLOAD_TEMP_DIR}
Environment=MESH_INITIAL_ADMIN_PASSWORD=${MESH_INITIAL_ADMIN_PASSWORD}

[Install]
WantedBy=multi-user.target
EOT
