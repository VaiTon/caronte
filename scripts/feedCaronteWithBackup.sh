#!/bin/bash

#Note: remember to install inotifywait
#apt-get update
#apt-get install inotify-tools

trap ctrl_c INT

function ctrl_c(){
	echo "Killing tcpdump"
	kill -9 $TCPDUMP_PID
}

if [[ "$#" -ne 4 ]]; then
    echo "Usage ./feedCaronte.sh <caronte_ip> <nic> <time_window> <pcap_dir>"
    exit 2
fi

CARONTE_IP="$1"
NIC="$2"		#NetworkINterface
TIME_WINDOW="$3"
PCAP_DIR="$4"

tcpdump -vve -ni $NIC -G $TIME_WINDOW -Z $USER -w $PCAP_DIR/cap%H%M%S.pcap &
export TCPDUMP_PID=$!
echo $TCPDUMP_PID

inotifywait -q -m "$PCAP_DIR" -e close_write |
    while read dir action file; do
      echo "[$(date +%H:%M:%S)] The file $file appeared in directory $dir via $action"
      curl_output=$(curl -sS -X POST "http://$CARONTE_IP:3333/api/pcap/upload" -H "Content-Type: multipart/form-data" -F "file=@$dir/$file" -F "flush_all=false" --user "admin:{{ caronte_pwd }}")
      echo "[CARONTE] $curl_output"
      
      #Opz per mantenere dei pcap fino ad un massimo di dimensione indicato
      SIZE=$(du -B 1 $dir | cut -f 1)    
      # 2GB = 2147483648 bytes
      # 10GB = 10737418240 bytes
      if [[ $SIZE -gt 147483648 ]]; then
      	  echo "deleting file $dir/$file"
          rm "$dir/$file"
      fi
      
      # rm "$dir/$file"
      echo
    done
