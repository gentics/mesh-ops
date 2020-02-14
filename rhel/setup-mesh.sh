#!/bin/bash

set -o nounset
set -o errexit

# Basics
MESH_VERSION=${MESH_VERSION:-1.4.0}
MESH_DIR=${MESH_DIR:-/opt/mesh-server}
MESH_COMMON_DIR=${MESH_COMMON_DIR:-/opt/mesh-server}
MESH_NODE_NAME=${MESH_NODE_NAME:-mesh-node}
MESH_HTTP_PORT=${MESH_HTTP_PORT:-8080}
MESH_VERTX_PORT=${MESH_VERTX_PORT:-4848}
MESH_CLUSTER_INIT=${MESH_CLUSTER_INIT:-false}
MESH_SERVICE_DESC=${MESH_SERVICE_DESC:-Gentics Mesh Server}
MESH_INITIAL_ADMIN_PASSWORD=${MESH_INITIAL_ADMIN_PASSWORD:-admin}
MESH_BINARY_DOCUMENT_PARSER=${MESH_BINARY_DOCUMENT_PARSER:-false}
MESH_INITIAL_ADMIN_PASSWORD=${MESH_INITIAL_ADMIN_PASSWORD:-admin}

# Clustering
MESH_WRITE_QUORUM=${MESH_WRITE_QUORUM:-2}
MESH_READ_QUORUM=${MESH_READ_QUORUM:-1}

# Memory
MESH_HEAP_MEM=${MESH_HEAP_MEM:-2048}
MESH_DIRECT_MEM=${MESH_DIRECT_MEM:-512}
MESH_BUFFER_MEM=${MESH_BUFFER_MEM:-512}
MESH_CLUSTER_NAME=${MESH_CLUSTER_NAME:-mesh-cluster}

# Paths
MESH_AUTH_KEYSTORE_PATH=${MESH_AUTH_KEYSTORE_PATH:-/opt/mesh-server/keystore}
MESH_BINARY_UPLOAD_TEMP_DIR=${MESH_BINARY_UPLOAD_TEMP_DIR:-/opt/mesh-server/temp}
MESH_PLUGIN_DIR=${MESH_PLUGIN_DIR:-/opt/mesh-server/plugins}
MESH_TEMP_DIR=${MESH_TEMP_DIR:-/opt/mesh-server/temp}
MESH_BINARY_DIR=${MESH_BINARY_DIR:-/opt/mesh-server/uploads}
MESH_GRAPH_EXPORT_DIRECTORY=${MESH_GRAPH_EXPORT_DIRECTORY:-/opt/mesh-server/exports}
MESH_GRAPH_BACKUP_DIRECTORY=${MESH_GRAPH_BACKUP_DIRECTORY:-/opt/mesh-server/backups}

# Monitoring
MESH_MONITORING_ENABLED=${MESH_MONITORING_ENABLED:-true}
MESH_MONITORING_HTTP_PORT=${MESH_MONITORING_HTTP_PORT:-8081}
MESH_MONITORING_HTTP_HOST=${MESH_MONITORING_HTTP_HOST:-127.0.0.1}

# Elasticsearch
MESH_ELASTICSEARCH_URL=${MESH_ELASTICSEARCH_URL:-null}
MESH_ELASTICSEARCH_START_EMBEDDED=${MESH_ELASTICSEARCH_START_EMBEDDED:-false}

echo -e "\nCreating Mesh Instance"
echo -e "\nUsing settings:"
set | grep "MESH_"
echo -e "\nPress any key to continue"
read

mkdir -p $MESH_COMMON_DIR
if [ ! -e $MESH_COMMON_DIR/mesh-server-$MESH_VERSION.jar ] ; then
  echo -e "\nDownloading mesh server"
  wget https://maven.gentics.com/maven2/com/gentics/mesh/mesh-server/$MESH_VERSION/mesh-server-$MESH_VERSION.jar
fi

mkdir -p $MESH_DIR/config
MESH_GRAPH_DB_DIRECTORY=${MESH_DIR}/graphdb
MESH_LOCK_PATH=${MESH_DIR}/.meshlock
ln -s mesh-server-$MESH_VERSION.jar mesh-server.jar

echo -e "\nCreating log configuration"
cat << EOT > ${MESH_DIR}/config/logback.xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration scan="true" scanPeriod="30 seconds">

	<conversionRule conversionWord="meshName" converterClass="com.gentics.mesh.log.MeshLogNameConverter"/>
	<statusListener class="ch.qos.logback.core.status.NopStatusListener" />

  <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
    <file>log/mesh.log</file>
    <target>System.err</target>
    <append>true</append>
    <encoder>
      <pattern>%d [%meshName] %-5level [%file:%line] - %msg%n</pattern>
    </encoder>
    <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
      <fileNamePattern>log/mesh-%d{yyyy-MM}.log.gz</fileNamePattern>
      <maxHistory>12</maxHistory>
    </rollingPolicy>
  </appender>

	<appender name="STDERR" class="ch.qos.logback.core.ConsoleAppender">
		<target>System.err</target>
		<encoder>
			<pattern>%d{HH:mm:ss.SSS} [%meshName] %-5level [%thread] [%logger{20}] - %msg%n</pattern>
		</encoder>
		<filter class="ch.qos.logback.classic.filter.LevelFilter">
			<level>ERROR</level>
			<onMatch>ACCEPT</onMatch>
			<onMismatch>DENY</onMismatch>
		</filter>
	</appender>

	<appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
		<encoder>
			<pattern>%d{HH:mm:ss.SSS} [%meshName] %-5level [%thread] [%logger{20}] - %msg%n</pattern>
		</encoder>
	</appender>

	<logger name="io.vertx" level="INFO"/>
	<logger name="com.gentics" level="INFO"/>

	<root level="ERROR">
    <appender-ref ref="FILE"/>
		<appender-ref ref="STDOUT"/>
	</root>
</configuration>
EOT

echo -e "\nCreating default cluster configuration"
cat << EOT > ${MESH_DIR}/config/default-distributed-db-config.json
{
  "autoDeploy": true,
  "readQuorum": ${MESH_READ_QUORUM},
  "writeQuorum": ${MESH_WRITE_QUORUM},
  "hotAlignment": true,
  "executionMode": "synchronous",
  "failureAvailableNodesLessQuorum": false,
  "readYourWrites": true,
  "newNodeStrategy": "static",
  "servers": {
    "*": "master"
  },
  "clusters": {
    "internal": {
    },
    "*": {
      "servers": ["<NEW_NODE>"]
    }
  }
}
EOT

echo -e "\nCreating service configuration"
cat << EOT > ${MESH_DIR}/mesh-server.service
[Unit]
MESH_Description=$MESH_SERVICE_DESC
Wants=basic.target
After=basic.target network.target syslog.target

[Service]
User=mesh
Restart=on-failure
MESH_MESH_ExecStart=/usr/bin/java -Xms${MESH_HEAP_MEM}m -Xmx${MESH_HEAP_MEM}m -XX:MaxDirectMemorySize=${MESH_DIRECT_MEM}m -Dstorage.diskCache.bufferSize=${MESH_BUFFER_MEM} -jar ${MESH_COMMON_DIR}/mesh-server.jar
WorkingDirectory=${MESH_DIR}
LimitMEMLOCK=infinity
LimitNOFILE=65536
LimitAS=infinity
LimitRSS=infinity
LimitCORE=infinity

# Features
Environment=MESH_UPDATECHECK=false
Environment=MESH_DEBUGINFO_LOG_ENABLED=false
Environment=MESH_BINARY_DOCUMENT_PARSER=${MESH_BINARY_DOCUMENT_PARSER}
Environment=MESH_DEFAULT_LANG=${MESH_DEFAULT_LANG}

# Auth
Environment=MESH_AUTH_KEYSTORE_PASS=${MESH_AUTH_KEYSTORE_PASS}

# ES
Environment=MESH_ELASTICSEARCH_URL=${MESH_ELASTICSEARCH_URL}
Environment=MESH_ELASTICSEARCH_START_EMBEDDED=${MESH_ELASTICSEARCH_START_EMBEDDED}

# Monitoring
Environment=MESH_MONITORING_ENABLED=${MESH_MONITORING_ENABLED}
Environment=MESH_MONITORING_HTTP_PORT=${MESH_MONITORING_HTTP_PORT}
Environment=MESH_MONITORING_HTTP_HOST=${MESH_MONITORING_HTTP_HOST}

# Ports
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

echo -e "\nAdding user"
adduser --system --no-create-home --group mesh

echo -e "\nUpdating permissions"
chown mesh: $MESH_DIR -R
chown mesh: $MESH_COMMON_DIR -R

echo -e "\nEnabling service"
systemctl enable $MESH_DIR/mesh-server.service

echo -e "\nYou may start the service with:"
echo "service mesh-server start"

echo "\nDone"