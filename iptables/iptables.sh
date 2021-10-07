#!/bin/bash 

LOG=0
iFace=eth1
iFaceAddr=$(ip -4 addr show eth1 | grep 'inet ' | awk '{ print $2}' | cut -d'/' -f1)
podmanAddr="172.16.0.0/16"

function create_ipset() { 
  ipset create whitelist nethash
  ipset add whitelist 127.0.0.0/8
  ipset add whitelist $podmanAddr
  ipset add whitelist $iFaceAddr
}

rulesOn="
iptables -t mangle -I INPUT -i $iFace -m set ! --match-set whitelist src -j DROP
(( $LOG )) &&  iptables -t mangle -I INPUT -i $iFace -m set ! --match-set whitelist src -j LOG --log-prefix \"mangle INPUT: DROP \"
iptables -t mangle -I INPUT -i $iFace -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -t mangle -I INPUT -i $iFace -p tcp --dport 22 -j ACCEPT

iptables -t mangle -I FORWARD -i $iFace -m set ! --match-set whitelist src -j DROP
(( $LOG )) && iptables -t mangle -I FORWARD -i $iFace -m set ! --match-set whitelist src -j LOG --log-prefix \"mangle FORWARD: DROP \"
iptables -t mangle -I FORWARD -i $iFace -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -t mangle -I FORWARD -i $iFace -m set ! --match-set whitelist src -p tcp -m multiport --dports 80,443 -m state --state NEW -j ACCEPT
"
rulesOff=$(echo "$rulesOn" | grep -v LOG | sed -e 's/-I /-D /g'; echo sleep 1; echo "$rulesOn" | grep LOG | sed -e 's/-I /-D /g';)


function start() { 
  if ! ipset list whitelist > /dev/null 2>&1; then
    echo "  Creating ipset."
    create_ipset
  fi

  # echo "  Iptables rules:" 
  # echo "$rulesOn" 
  sleep 1
  echo "$rulesOn" | bash 
} 

function stop() { 
 echo "Removing iptables rules and destroying ipset.:" 
 # echo "$rulesOff" 
 echo "$rulesOff" | bash 
 ipset destroy whitelist
} 

function showRules() { 
 echo "Iptables rules:" 
 echo "$rulesOn" 
} 

function status() { 
 if iptables -t mangle -L -v | grep '! match-set whitelist src' | grep -q DROP; then
   echo "Iptables is active" 
 else 
   echo "Iptables is not active" 
 fi 
} 

case $1 in 

 start) 
   start 
   ;; 

 stop) 
   stop 
   ;; 

 status) 
   status 
   ;; 

 show_rules) 
   showRules 
   ;; 

 *) 
   echo "Usage: $0 start|stop|show_rules|status" 
   ;; 

esac

