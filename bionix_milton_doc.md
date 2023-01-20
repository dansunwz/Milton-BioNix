# Running BioNix on Milton

Milton can be accessed via [WEHI RAP](https://rap.wehi.edu.au/), under the tab **RDP – SSH**. After entering your WEHI login details, select **SSH – slurm-login**. You will now see a welcome message, indicating that you have successfully connected to Milton.

## Setting up BioNix

To run [BioNix](https://github.com/PapenfussLab/bionix) on Milton, we first need to switch the node to `vc7-shared` as Nix can only be run in this node. Run the following command:
```{sh}
ssh vc7-shared
```
and type in your WEHI password. You will see another message that tells you have switched node successfully.
If you wish to read more about the node `vc7-shared`, you can refer to this [page](https://wehieduau.sharepoint.com/sites/rc2/SitePages/using-milton.aspx) in WEHI's [Research Computing Website](https://wehieduau.sharepoint.com/sites/rc2).

<br>

Using BioNix on Milton requires dependencies [Nix](https://nixos.org/) and [Git](https://git-scm.com/). Note that the default Git on Milton is outdated, and the Nix module loads a newer version (view by `git --version`). 
To load them, type in:
```{sh}
module load nix
```
Application software on Milton is provided through [Environment Modules](https://modules.sourceforge.net/) and can be accessed via `module` command. For more information, please refer to the page [Accessing software](https://wehieduau.sharepoint.com/sites/rc2/SitePages/modules.aspx).

<br>

Since Nix is not installed globally on Milton, it is important to bind mount your personal user store using:
```{sh}
nix-chroot bash
```
Bind mount allows you to mount Nix to another location in the file system (i.e. your personal store) so that you can get access to it. Otherwise you will get a broken symlink when you build an expression.
Now you can run BioNix as you would on your local machine. E.g. `nix build`. 

<br>

If you want to use [nixpkgs](https://github.com/NixOS/nixpkgs/tree/master/pkgs), you use:
```{nix}
with import (builtins.getFlake "nixpkgs") {};
```
rather than `with import <nixpkgs> {};` as channels are not configured with `nix-channel`.


## Testing BioNix

To ensure BioNix is working correctly on Milton we will test it with [Kai Bing's BioNix-qc-pipe](https://github.com/victorwkb/BioNix-qc-pipe).

First, make sure you have correctly set up Nix on Milton according to the instructions above, then in your home directory or your preferred location on Milton, run:
```{sh}
git clone --depth 1 https://github.com/victorwkb/BioNix-qc-pipe.git
```

<br>

Now change the directory to `subread-wf`:
```{sh}
cd BioNix-qc-pipe/subread-wf/
```

<br>

Build the expression using:
```{sh}
nix build
```
Use `nix build` to test workflows, it will create a symlink to the build result under the `result` directory. In this case, when no path is specificed, `nix build` will build the `default.nix` file from the flake in the current directory. Nix Flakes allow you to specify code dependencies in the `flake.nix` file. A `flake.lock` file will be generated when you build for the first time, it contains a record of the version of all packages used in this build. Nix Flakes are the key to Nix's high reproducibility. You can read more about Nix Flakes [here](https://nixos.wiki/wiki/Flakes).

<br>

You can view the results with:
```{sh}
cat result
```

<br>

To ensure the result is correct we will compare it with the expected result.
A couple of files are required to do this test, you can get them by doing:
```{sh}
git clone --depth 1 https://github.com/dansunwz/Milton-BioNix.git
```

<br>

Now change directory to the test folder we've just cloned:
```{sh}
cd Milton-BioNix/milton_bionix_test/
```

<br>

Give permission to run the shell script by typing in:
```{sh}
chmod +x test.sh
```

<br>

Now run the script:
```{sh}
./test.sh
```
After running the script `test.sh`, a prompt will show up in the terminal to tell you whether BioNix is working as intended. If it isn't, please follow the guide from the beginning and try to configure BioNix again.

## Resource allocation

Cpus per task and memory allocations can be specified for the jobs that your nix expressions may schedule to SLURM. Contrary to usual practice, for example, of using the `--cpus-per-task=` or `--mem=` flags with `srun`, default resource requirements can be specified as an overlay in a `flake.nix` file, as shown in [jbedo's static-nix documentation](https://github.com/jbedo/static-nix).
```{nix}
{
  description = "Flake for yourSoftware";

  inputs = {
    bionix.url = "github:papenfusslab/bionix";
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, bionix, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system: with bionix.lib
        {
          overlays = [
            (self: super: { example = self.callBionix ./example.nix { }; })
            (self: super: {
              exec = f: x@{ ppn ? 1, mem ? 1, walltime ? "2:00:00", ... }: y:
                (f (removeAttrs x [ "ppn" "mem" "walltime" ]) y).overrideAttrs (attrs: {
                  PPN = if attrs.passthru.multicore or false then ppn else 1;
                  MEMORY = toString mem + "G";
                  WALLTIME = walltime;
                });
            })
            ./resources.nix
          ];
          nixpkgs = import nixpkgs { inherit system; };
        };
      {
        defaultPackage = callBionix ./. { };
      }
      );
}
```
Above is [victorwkb's example `flake.nix` template](https://github.com/victorwkb/BioNix-Doc) with [jbedo's example of resource allocation](https://github.com/jbedo/static-nix).

As mentioned in the [BioNix README](https://github.com/PapenfussLab/bionix):
- ppn is the number of cores to request
- mem is the amount of memory to request (GB)
- walltime is a string defining the maximum walltime
And the default parameters of these can be specificed in the overlay above. For example `ppn ? 1, mem ? 1, walltime ? "2:00:00"` will give 1 core, 1GB of memory and a walltime of 2 hours.

Such as the example above, you may also pass in a nix file, in this case `resources.nix` that can override the default resource specifications for a specfied job. Here is an example from [jbedo's malaria-variant-calling](https://github.com/jbedo/malaria-variant-calling/blob/master/resources.nix):
```{nix}
self: super: with super;
{
  bwa.align = def bwa.align { mem = 20; ppn = 20; walltime = "12:00:00"; };
  samtools.sort = def samtools.sort { ppn = 10; mem = 15; flags = "-m 1G"; walltime = "1:00:00"; };
  octopus.call = def octopus.call { mem = 20; ppn = 24; walltime = "24:00:00"; };
}
```
So the job of `bionix.bwa.align` will recieve 20GB of memory, 20 cores and a walltime of 12 hours to complete.
