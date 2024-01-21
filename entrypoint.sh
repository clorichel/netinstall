#!/bin/bash                                                                                                                                        
set -e                                                                                                                                             
NETINSTALL_ADDR="${NETINSTALL_ADDR:="192.168.88.1"}"                                                                                               
ROSARCH="${NETINSTALL_ARCH:="arm"}"                                                                                                                
PKGS="${NETINSTALL_NPK:="routeros"}"                                                                                                      
NPKLIST=$(for i in $(ls `for p in $PKGS; do echo "/app/images/$p*-$ROSARCH.npk"; done`); do echo $i; done)                                         
NPKARG="${NPKLIST//$'\n'/ }"                                                                                                                       
echo $PKGS                                                                                                                                         
echo $NPKLIST                                                                                                                                      
echo $NPKARG                                                                                                                                       
exec /app/qemu-i386-static /app/netinstall-cli -b -r -a $NETINSTALL_ADDR $NPKARG