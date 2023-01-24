#!/bin/bash
output=`nix build --impure --no-link --expr 'with import (builtins.getFlake "nixpkgs") {};; fetchurl {url = "https://raw.githubusercontent.com/PapenfussLab/bionix/master/examples/ref.fa"; sha256 = "sha256-V3zqOJFuGtukDRQttK/pGfKofgOlKrridHaWYhGGyWs=";}'`
if [[ -z $output ]] ; then
    echo "Your BioNix is working perfectly!"
else
    echo "Something is wrong, please follow this guide and try to configure BioNix again"
fi
