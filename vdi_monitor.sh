#!/bin/bash

get_cluster_name() {
   IFS=$'\n'
   local name
   local raw_arr
   raw_arr=($(eval "ls -al /etc/vstorage/clusters/"))
   name=($(echo ${raw_arr[3]} | awk -F " " '{print $9}'))
   eval "$1=$name"
   IFS=$' '
}

get_cluster_name cl_name

#get count of chunk disks
count=($(vstorage -q -c $cl_name stat | grep 'CS nodes: ' | grep -o -P '(?<=of ).*?(?= \()'))

IFS=$'\n'
#get array of cluster nodes (from uniq chunk-server names)
raw_arr=($(vstorage -q -c $cl_name stat | grep CSID -A$count | awk '{print $10}' | uniq))

#delete "HOST" string from array
delete=(HOST)
for target in "${delete[@]}"; do
  for i in "${!raw_arr[@]}"; do
    if [[ ${raw_arr[i]} = "${delete[0]}" ]]; then
      unset 'raw_arr[i]'
    fi
  done
done

#sorting array of nodes by name
sorted_arr=($(sort <<<"${raw_arr[*]}"))

#commands to execute in remote node
commands=("hostname ; systemctl | grep openstack-nova-compute | awk '{print \$1,\$2,\$3,\$4}' ; systemctl | grep neutron-linuxbridge-agent | awk '{print \$1,\$2,\$3,\$4}'")

#password for sshpass
PASSWD="********"

#execute commands on all nodes in loop
for j in "${!sorted_arr[@]}"; do
    sshpass -p$PASSWD ssh -q -o StrictHostKeyChecking=no root@${sorted_arr[j]} 'bash -s' <<< "${commands[@]}"
    rr=$?
    if [[ rr -ne 0 ]]; then  printf "\e[1;31m${sorted_arr[j]} not responding\e[0m\n"
    fi
done

unset IFS
