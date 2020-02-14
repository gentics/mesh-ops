#!/bin/bash

set -o nounset
set -o errexit

function setupLB() {
  sudo yum install haproxy

  local number=$1
  local lbPort=$2
  local path=$LB_HOME/lb$number
  echo "Creating LB - $number"
  sudo mkdir -p $path
  updateFilepermissions

  local tmpfile=/tmp/ha_$number.conf
  if [ -e $tmpfile ] ; then
    rm $tmpfile
  fi
  cat >$tmpfile <<EOL
global
  chroot      $path
  pidfile     /var/run/haproxy$number.pid
  maxconn 8000
  user  haproxy
  group haproxy
  daemon

  # turn on stats unix socket
  stats socket $path/stats$number

defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 0
    timeout http-request    25s
    timeout queue           1m
    timeout connect         25s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 15s
    timeout check           15s
    maxconn                 3000

frontend http-in
    bind *:$lbPort
    acl is_gql path_end /graphql
    acl is_gql path_end /graphql/
    acl is_post method POST
    acl is_get method GET
    #use_backend mesh_replicas if is_gql or is_get
    #use_backend mesh_masters if is_post !is_gql
    use_backend mesh_masters
    default_backend mesh_masters
EOL

local replicas=/tmp/mesh_replicas.cfg
local masters=/tmp/mesh_masters.cfg

  echo -e "\nbackend mesh_masters" > $masters
  echo "    option httpchk GET /api/v1 HTTP/1.0" >> $masters

  echo -e "\nbackend mesh_replicas" > $replicas
  echo "    option httpchk GET /api/v1 HTTP/1.0" >> $replicas


  echo "    stats enable" >> $replicas
  echo "    stats uri /admin?stats" >> $replicas
  echo "    stats refresh 5s" >> $replicas

  for server in $(cat $SETUP_DIR/mesh_servers.lst | grep -v "#"); do
    IFS=" " read -r -a info <<< "$server"
    local mesh_name=${info[0]}
    local mesh_type=${info[2]}
    local mesh_ip=${info[3]}
    local mesh_httpPort=${info[4]}
    local mesh_monPort=${info[5]}

    echo "* Adding $mesh_name to ha config"
    if [ "$mesh_type" == "master" ] ; then
      echo "    server $mesh_name $mesh_ip:$mesh_httpPort maxconn 64 check fall 3 rise 2" >> $masters
    fi

    if [ "$mesh_type" == "replica" ] ; then
      echo "    server $mesh_name $mesh_ip:$mesh_httpPort maxconn 64 check fall 3 rise 2" >> $replicas
    fi 
  done

  cat $masters >> $tmpfile
  cat $replicas >> $tmpfile

  local confFile=$path/haproxy.cfg
  sudo chown portal: $LB_HOME -R
  sudo cp $tmpfile $confFile

  setupHAProxyService $number
  updateFilepermissions

  sudo chown haproxy: $path -R
  sudo service lb-$number start
}

setupLB 1 9081

