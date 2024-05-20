# `Makefile` for Mikrotik Netinstall 

`netinstall` allows "flashing" of Mikrotik devices, using a list of packages and various option.  While Mikrotik provides a Linux version of `netinstall`, running it involves many steps.  One of which is the downloading packages, for the right CPU, and possibilty some "extra-packages" needed too.

Mikrotik has a good overview of `netinstall` and the overall process: https://help.mikrotik.com/docs/display/ROS/Netinstall#Netinstall-InstructionsforLinux

The source code and CI image building are stored in a public GitHub repo, and an OCI is also pushed to DockerHub by GitHub's Actions.  [Comments, complaints, and bugs](https://github.com/tikoci/netinstall/issues) are all welcome via GitHub Issues in the `tikoci/netinstall` [repo](https://github.com/tikoci/netinstall).  


### Dual Use

#### Just Automating `netinstall` on Linux desktop

The "script" is invoked by just calling `make` from the same directory, and by default that will start a netinstall using ARM packages, from "stable" channel, on an interface named "eth0". _This is often not the case, so variables on the network interface/IP will likely need to be changed from defaults._

#### _or..._ Running as a Mikrotik `/container` 

There is an associated `Dockerfile` to enable containerization, including using QEMU to run Mikrotik's X86 `netinstall` binary on other platforms, specifically ARM and ARM64/aarch.  By default, the container version runs as a "service", so after one netinstall completes, it goes on to waiting for the next. The OCI container image for a `/container/add tag= ...` is available on DockerHub and GitHub's ghcr.io repo (for arm, arm64/aarch, and x86_64/amd64) using tag=
`ammo74/netinstall` for [DockerHub](https://hub.docker.com/r/ammo74/netinstall) or [GitHub Container Registry (ghcr.io)](https://github.com/tikoci/netinstall/pkgs/container/netinstall) for `ghcr.io/tikoci/netinstall:latest` as remote-image=/tag= in `/container`

> On RouterOS, the container registry must be set to either one of those in 
> `/container/config`



## Linux Install and Usage

#### Prerequisits
* Linux device (or virtual machine) with ethernet 
* Some familarity with the UNIX shell and commands
* `make` is installed (by default, most distro include it)

> **NOTE**
>
> Each distro is different.  Only limited testing was done on Linux, specifcally virtualized Ubuntu.  While very generic POSIX commands/tools are used, still possible to get errors that stop `make` from running.  Please report any issues found, including errors.

#### Downloading Code to Run on Linux

While you can download the Makefile itself to a new directly, and the just run `make download` to see what, if any options are needed.  But it may be easier to just use:

```
cd ~    # or anywhere
git clone https://github.com/tikoci/netinstall.git
cd netinstall 
make download
```

#### Linux Usage Examples

`make` need to be run from the **same directory** as the `Makefile`.  To use the examples, the shell CWD must have the `Makefile`, so to start:
```
cd ~/netinstall
make dump # to test 
```

> **INFO**
>
> `sudo` must be used on most desktop Linux distros for any operation that starts running `netinstall`, since previledged ports are used.

* The runs netinstall using "testing" (`CHANNEL`) build with "mipsbe" (`ARCH`):
  ```
  sudo make testing mipsbe 
  ```
* Download files for "stable" on the "tile" CPU - but does NOT run netinstall -  removing any cached files to save space and force a refresh:
  ```
  make clean stable tile download 
  ```
* Conversely, without `clean` or `download`, a local copy of packages will be used and since default is `netinstall` runs after all files are present, this should be quick (since files for "stable tile" were previously downloaded in above example):
  ```
  sudo make stable tile
  ```
* Similarly, without `clean` or `download`, a local copy of packages will be used and since, by default, `netinstall` attempt to start:
  ```
  sudo make stable tile
  ```


## RouterOS `/container` Install

To use a `/container` running `netinstall` to enable a full reset/recovery of connected RouterOS device, some steps are needed.  The basic approach is the container's VETH is bridged to a physical ethernet port using a new `/interface/bridge`, and the container runs `netinstall` using emulation (on arm/arm64) using options provided via `/container/env` entries and the remote.

> Although theorically a single VLAN-enabled bridge should work, if VETH and target physical port have some vlan-id=.  But for `netinstall` likely best if just seperate, since VLANs add another level of complexity here.  Likely possible, just untested.

See Mikrotik's docs on `/container` for more details and background, including how to installed the prerequisits:
https://help.mikrotik.com/docs/display/ROS/Container

#### Prerequisits

* RouterOS device that supports containers, generally ARM, ARM64, or X86 devices
* Some non-flash storage (internal drives, ramdisk, NFS/SMB client via ROS, USB, etc.)
* `container.npk` extra-package has been installed and other RouterOS specifics, and `/system/device-mode` has been used to enable container support as well.

#### Steps

1. Create `/interface/veth` interface:
    ```
    /interface veth add address=172.17.9.200/24 gateway=172.17.9.1 name=veth-netinstall
    ```
2. Create a seperate bridge for `netinstall` use and add VETH to it:
    ```
    /interface bridge add name=bridge-netinstall
    /interface bridge port add bridge=bridge-netinstall interface=veth-netinstall
    ```
3. Add veth and physical port to bridge: 
    ```
    /interface bridge port add bridge=bridge-netinstall interface=ether5
    ```
    **or** reassign a _existing_ bridge port to the new `bridge-netinstall`:
    ```
    /interface bridge port set [find interface=ether5 bridge=bridge-netinstall 
    ````
    > **NOTE** _Replace `ether5` with the physical ethernet port where the device needing `netinstall` is going to connect._    

4. Adjust firewall so the container can download packages/netinstall binary from Mikrotik.  The exact changes needed can be specific.  But if using the default firewall, the easiest may be:
    ```
    /interface/list/member add list=LAN interface=bridge-netinstall 
    ```
    > **TIP**
    > Alternatively, you can /ip/firewall/filter or NAT rules on the containers subnet, to specifically allow VETH access to internet.  Traffic between `netinstall` is forwarded, not routed, so only need if for outbound access from the container's IP.  **How?** - depends...   

5. Create enviroments variables to controll what `netinstall` behaviors:
    ```
    /container envs add key=ARCH name=NETINSTALL value=arm64
    /container envs add key=CHANNEL name=NETINSTALL value="testing"
    /container envs add key=PKGS name=NETINSTALL value="container zerotier wifi-qcom iot gps"
    /container envs add key=OPTS name=NETINSTALL value="-b -r"

    ```
    > The following are used to set a specific version, instead of using `CHANNEL` to select the version, or to mix-and-match `netinstall` versions as needed:
    > ```
    >     /container envs add key=VER name=NETINSTALL value=7.12.1
    >     /container envs add key=VER_NETINSTALL name=NETINSTALL value=7.15rc3
    > ```
---
---
>
> **TIP**
>
> It's possible to build the container image yourself into a `.tar`, instead of some of the steps below. See Mikrotik docs for [example Docker build steps](https://help.mikrotik.com/docs/display/ROS/Container#Container-c)buildanimageonPC) for Pi-Hole.  To start, use `git clone https://github.com/tikoci/netinstall.git`, to get the needed `Dockerfile` (and `Makefile` that contains the `netinstall` logic) to start `docker buildx` that well in a few steps get a `.tar` file locally to use on RouterOS – without using DockerHub etc.
>
---
6. The `registry-url` is used to fetch "pull" images.  It must be set to use either DockerHub or GitHub Container Registry.
    To see what's set, use `/container/config/print` to view the `registry-url` and `tmpdir` in use. 

    So for DockerHub, the setting should look like this:
    ```
    /container config set registry-url=https://registry-1.docker.io tmpdir=disk1/pulls-docker
    ```
    > **NOTE** 
    > _Adjust the `disk1/` path as need to use a non-flash disk_

    > Or, alternatively for GitHub's Container Registry (ghcr.io), `/container config set registry-url=https://ghcr.io tmpdir=disk1/pulls-ghcr` - the `remote-image=` depends on the repo set, but either will work but tag= must align with the repo being used.

7. Create the container and start the container.  This assumes DockerHub is being used:
    
    ```
    /container add remote-image=ammo74/netinstall:latest envlist=NETINSTALL interface=veth-netinstall logging=yes workdir=/app root-dir=disk1/root-netinstall
    ```
    > Or, if using ghcr.io, instead of DockerHub, use `remote-image=ghcr.io/tikoci/netinstall` instead.

    > **NOTE**
    > If you built your own `.tar` file using `docker buildx`, do not use `remote-image=` at all.  Instead, use `file=` that contains the path the `.tar` image uploaded to router.  Rest of attributes to `/container add` are the same in all case. 

    It will take about a minute to download and process the image file. 
    After the new container is expanded, it is indicating as a "stopped" status (instead of "expanding" or "error").  Status can be show by using `/container/print`.  
    
    If you see "error" status means something failed, likely disk or firewall issues. Worth it to check the `/logs/print` to where the process is failed. 

8. Now Start Container!To try to start it, use:  
    ```
     /container/start [find tag~"netinstall" status="stopped"]   
    ```

    > **TIP**
    > Configuration and options are described elsewhere, but using `/container/env` is likely the easiest.

9. Using variables used to control the container are described elsewhere.  In generally, using the /container/env methods is simplest.
    > **NOTE**
    > A restart of the netinstall container (e.g hitting stop, waiting 30s, then hitting start ) is required to pickup any changed settings.
    > This can be done using a rather complex one-line that re-tries:
    > ```
    > /container { :local c [find tag~"netinstall" status!="error"]; stop $c; :retry {start $c; :if ([get $c status]!="running") do={:error "waiting"}} delay=5s max=100 }
> ``` 


## Configuration Options and Variables

Let start with some commons ones, directly from the `Makefile` script:
```
ARCH ?= arm
PKGS ?= wifi-qcom-ac zerotier
CHANNEL ?= stable
```

These can used in three ways:

1. **Editting the Makefile**
   All of the variables are at the top of the file.  The ones with `?=` are only used IF the same variable was NOT already provided via CLI or env.  In general, only benifit to this method is persitance.
   > **CAUTION** 
   >
   > Be careful to not changes computed/complex variables & avoid trailing spaces etc.  Also note `Makefiles` use ONLY tab indentations, and Makefile will not run if wrong.
2. **Provided via `make` at CLI**, in same directory as Makefile.  For example, to start netintall for mipsbe using `VER` number directly, with some extra packages and `-a 192.168.88.7` option, and specific version `netinstall` to be used of 7.15rc3: 
    ```
    cd ~/netinstall
    sudo make -d ARCH=mipsbe VER=7.14.3 PKGS="iot gps ups" CLIENTIP=192.168.88.7 VER_NETINSTALL=7.15rc3
    ```
    which results in the follow `netinstall` command line being used:

    ```
    ./netinstall-cli-7.15rc3 -b -r -a 192.168.88.7 routeros-7.14.3-mipsbe.npk iot-7.14.3-mipsbe.npk gps-7.14.3-mipsbe.npk ups-7.14.3-mipsbe.npk
    ```
    An equivalent command line be:
    ```
    sudo make
    ```
    

### Basic Settings

The specific file names needed for `netinstall` are generated automatically based on the `ARCH`, `CHANNEL`, and `PKGS` variables to make things easier to configure.   The routeros*.npk does NOT need to be included in `PKGS` - it always added based on `ARCH`.  Only items "extra-packages" that needed to be installed are added to `PKGS`. 

| _option_   | _default_       |           |
| -     | -             | -             |
| ARCH | `arm` | **architecture name** must match `/system/resource`| 
| PKGS | `wifi-qcom-ac zerotier`          | **additional package name(s)**, without version/cpu, seperated by spaces, invalid/missing packages are skipped
| CHANNEL | `stable` | same choices as `/system/package/update` i.e. **testing**, **long-term**|

 Each time `make` is run, the `CHANNEL`'s current version is checked via the web, and sets `VER` automatically.
 
 ### Version Selection

 By design, `CHANNEL` should be used to control the version used. 

If `VER` or `VER_NETINSTALL` are provided, the string must be in the same form as published, like `7.15rc2` or `7.12.1`.  It **cannot** be a channel name like "stable".  But these variables can be any valid version, including older one or ones no longer on a channel.

`VER_NETINSTALL` is useful since sometimes `netinstall` has bug or gains new features.  Generally a newer netinstall can, and often should, be used to install older versions _i.e. some potential `OPTS` have changed over time..._  By default, only `CHANNEL` control what version of `netinstall` will be used.  Meaning, even if `VER` is lower/older than `VER_NETINSTALL`, the latest "stable" `netinstall` for Linux will be used by default.  That is unless unless `VER_NETINSTALL` is specified explictly

| _option_   | _default_       |           |
| -     | -             | -             |
| VER | _calculated from `CHANNEL`_ | specific version to install on a device, in `x.y.z` form |
| VER_NETINSTALL | _calculated from `CHANNEL`_ | version of `netinstall` to use, can be different than `VER`  |


### `OPTS` - Device Configuration
 In the variable `OPTS`, the string is provided directly to `netinstall` unparsed.  So any valid `netinstall` command line options can be provided – they just get inserted with run.  
 
To get an **empty config**, change `-r` in `OPTS` variable to a **`-e`** (both `-r` and `-e` are NOT allowed at some time).  `netinstall` also supports additional options, like replacing the default configuration via an option `-s <defconf_file>` and `-k <keyfile>`.  These too can be provided in `OPTS` – as long as any file references are present
 
| _option_   | _default_       |           |
| -     | -             | -             |
| OPTS | `-b -r` | default is to "remove any branding" `-b` and "reset to default" `-r`, see [`netinstall` docs](https://help.mikrotik.com/docs/display/ROS/Netinstall#Netinstall-InstructionsforLinux)  |

#### Network and System Configuration

Critical to `netinstall` wokring to flash a device is the networking is configured.  This is the trickiest part.  Basically the `-i` or `-a` options must align with everything else, which coorespond to the `IFACE` **OR** `CLIENTIP`.

Mikrotik has a YouTube video that explains a bit about these interface vs IP options: [Latest netinstall-cli changes](https://youtu.be/EdwcHcWQju0?si=CrmixEZyH7FOjlZk).  These are more applicable if you're using Makefile standaone on a Linux machine - if running in a `/container`, the network default here should work.

In either case, the router and machine (or container's VETH) should be directly connected or on a bridged without ANY other traffic.  And IP address should be install on the system running `make`.  You may need internet or Wi-Fi initially to download the packages (`make download`).

If used within a Mikroitk `/container` via the Dockerfile/registry, the defaults should work: `-i eth0 ...` since the container only has one VETH _and IP config has to work to get to this point._

| _option_   | _default_       |           |
| -     | -             | -             |
| IFACE | `eth0` | physical interface name connected to device to `netinstall`, i.e. the link name in `ip addr` |
| CLIENTIP | _not set_ | by default `-i <iface>` is used, if `CLIENTIP` then `-a <clientip>` is ued |
| NET_OPTS | _calculated_ | raw `netinstall` network options, like "-i en4" – `IFACE` and `CLIENTIP` are ignored if `NET_OPTS` is set, only needed if `-i <iface>` or `-a <clientip>` do not work (or change)|

   

### Uncommon Options
This should not be changed, documenting here for consitistancy.

| _option_   | _default_       |           |
| -     | -             | -             |
| QEMU | `./i386` | `qemu-user-static` is needed to run `netinstall` on  non-Intel platforms (`QEMU` is NOT used if X86).  See Dockerfile, but Alpine Linux does not have a pre-built package, so it's borrowed from a Debian build for use on Alpine.    |
| URLVER | https://upgrade.mikrotik.com/routeros/NEWESTa7 | URL used to determine what version is "stable"/etc |
| PKGS_FILES | _computed_ | _read-only_, in logs shows the resolved "extra-package" to be installed
| PLATFORM | _computed from `uname -m`_ | _internal_, used to determine if emulation is needed to run `netinstall`, if set to x86_64 will the skip `QEMU` emulation step – does not effect packages to be _installed_ as those are controlled by `ARCH`.

## `make` arguments for CLI (or Docker `CMD`)

The script is based on a `Makefile` and the `make` command in Linux.  One important detail is `make` looks for the `Makefile` within the current working directory.  


### Basic usage

* `make` -  same as `make run`, see below
* `make run` - **CLI default** is run netinstall unit found and finished, then stop container
* `make service` - **Dockerfile default** runs netinstall as a service until stopped manually
* `make download` - used on desktop to download packages before potentially disconnecting the network, then `make` can be used without internet access

### Using CLI "shortcuts"

Any targets provided via aguments to `make` will OVERRIDE any environment variable with same name. _i.e._ CLI arguments win
* `make <stable|testing|long-term>` - specify the `CHANNEL` to use
* `make <arm|arm64|mipsbe|mmips|smips|ppc|tile>` - specify the `ARCH` to use

For example `make testing tile` which will start `netinstall` using the current "testing" channel version, for the "tile" architecture.  

### Combine `make` "shortcuts"

For offline use, while only one channel and one architecture can be used at a time...Downloaded files are cached until deleted manually or `make clean`. So to download without running, add an `download` to the end of `make stable mipsbe download`, and repeate for any versions you want to "cache".

> **TIP**
>
> The "shortcut" with `make` variables provided like `make download VER=7.12 ARCH=mmips CLIENTIP=192.168.88.4 VER_NETINSTALL=7.15rc3`.  Just don't mix TOO many together, but output (or logs) should indicate the potential problem

### Troubleshooting and File Management

* `make clean` - remove all stored packages and netinstall; will be re-created at startup again
* `make nothing` - does nothing, except keep running; used to access `/container/shell` without starting anything
* `make dump` - for internal debugging use, not much data

    

>### Wait, a C/C++ `Makefile`, why not python or node?
>The aim here is to simplify the process to automatically download all the various packages and `netinstall` tool itself.  But also an experiment in approaches too.  Essentially the "code" is just an old-school UNIX `Makefile`, but beyond it's history, it has some modern advatages:
> *  `make` is very good at maintaining a directory with all the needed files, so it downloading only when needed efficiently.  
> * By using [`.PHONY` targets](https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html), and non-traditional target names, _`make`_ this approach act more "script-like" than a C/C++ build tool.
> * `make` natively supports taking variables from **either** via `make` arguments or environment variables.  This is pretty handy to allow some code to support containerization and plain CLI usage
> * As a "script interpeter", `make` (plus busybox tools) is significantly smaller "runtime" than Python/Node/etc.  Before loading the packages, the container image is 6MB.  
>
>The disadvantages is that is complex to understand unless one is already familar with `Makefile`. It's a dense ~200 page manual (see "GNU make manual" in [HTML](https://www.gnu.org/software/make/manual/make.html) or [PDF](https://www.gnu.org/software/make/manual/make.pdf)).
  But since `make` deal well with state and files, it saves a lot of `if [ -f routeros* ] ... fi` stuff it take to do same as here in `bash`... 
>
>And, just wanted to if `make` worked as a UNIX init process for container:
> ```
> ## so make is the init
> CMD ["make", "service"]
>```
>After trying this, it does seem like a nifty trick in the bag to get a little more organization out of what is mainly some busybox and `/bin/sh` commands.  In particular, how it deals with variables from EITHER env or program args.  Anyway, worked well enough for me to write it up and share – both the tool and approach.
>
>     



## Unlicensing

This work is marked with CC0 1.0. To view a copy of this license, visit https://creativecommons.org/publicdomain/zero/1.0/