#!/bin/bash

while IFS=, read -r col1 col2 col3
do
  "net.create $col1 vlan=$col2 virtual_switch=vs0"
   
done < "C:\Users\UTHAMSH\CodeRepo\vSpereRepo\Adding Nutanix vlans\vlanlist.txt"
