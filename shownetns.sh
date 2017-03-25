#!/bin/bash 

function ergodic(){  
        for file in ` ls $1 `  
        do  
              if [ $(echo $1"/"$file | grep -E "/proc/[0-9]+$") ]; then
                    sudo   ls -l $1"/"$file"/ns/net" | grep net
              fi
        done  
}  

ergodic "/proc"
