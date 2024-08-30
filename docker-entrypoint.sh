#!/bin/sh

if [ "$1" = 'valkey-cluster' ]; then
    # Allow passing in cluster IP by argument or environmental variable
    IP="${2:-$IP}"

    if [ -z "$IP" ]; then # If IP is unset then discover it
        IP=$(hostname -I)
    fi

    echo " -- IP Before trim: '$IP'"
    IP=$(echo ${IP}) # trim whitespaces
    echo " -- IP Before split: '$IP'"
    IP=${IP%% *} # use the first ip
    echo " -- IP After trim: '$IP'"

    if [ -z "$INITIAL_PORT" ]; then # Default to port 7000
      INITIAL_PORT=7000
    fi

    if [ -z "$MASTERS" ]; then # Default to 3 masters
      MASTERS=3
    fi

    if [ -z "$SLAVES_PER_MASTER" ]; then # Default to 1 slave for each master
      SLAVES_PER_MASTER=1
    fi

    if [ -z "$BIND_ADDRESS" ]; then # Default to any IPv4 address
      BIND_ADDRESS=0.0.0.0
    fi

    max_port=$(($INITIAL_PORT + $MASTERS * ( $SLAVES_PER_MASTER  + 1 ) - 1))
    first_standalone=$(($max_port + 1))
    if [ "$STANDALONE" = "true" ]; then
      STANDALONE=2
    fi
    if [ ! -z "$STANDALONE" ]; then
      max_port=$(($max_port + $STANDALONE))
    fi

    for port in $(seq $INITIAL_PORT $max_port); do
      mkdir -p /valkey-conf/${port}
      mkdir -p /data/${port}

      if [ -e /data/${port}/nodes.conf ]; then
        rm /data/${port}/nodes.conf
      fi

      if [ -e /data/${port}/dump.rdb ]; then
        rm /data/${port}/dump.rdb
      fi

      if [ -e /data/${port}/appendonly.aof ]; then
        rm /data/${port}/appendonly.aof
      fi

      if [ "$port" -lt "$first_standalone" ]; then
        PORT=${port} BIND_ADDRESS=${BIND_ADDRESS} envsubst < /valkey-conf/valkey-cluster.tmpl > /valkey-conf/${port}/valkey.conf
        nodes="$nodes $IP:$port"
      else
        PORT=${port} BIND_ADDRESS=${BIND_ADDRESS} envsubst < /valkey-conf/valkey.tmpl > /valkey-conf/${port}/valkey.conf
      fi

    done

    bash /generate-supervisor-conf.sh $INITIAL_PORT $max_port > /etc/supervisor/supervisord.conf

    supervisord -c /etc/supervisor/supervisord.conf
    sleep 3


    echo "Using valkey-cli to create the cluster"
    echo "yes" | eval valkey-cli --cluster create --cluster-replicas "$SLAVES_PER_MASTER" "$nodes"

    tail -f /var/log/supervisor/valkey*.log
else
  exec "$@"
fi
