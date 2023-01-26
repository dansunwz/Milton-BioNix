#!/bin/bash
if [[ -f ./milton-bionix-output.txt ]] ; then
    rm -f ./milton-bionix-output.txt
fi

grep -v "platypusOptions" ../../result > milton-bionix-output.txt
output=`diff sample-output.txt milton-bionix-output.txt`

if [[ -z $output ]] ; then
    echo "Your BioNix is working perfectly!"
else
    echo "Something is wrong, please follow this guide and try to configure BioNix again"
fi
