# Mikrotik `netinstall` using `make`


`netinstall` allows the "flashing" of Mikrotik devices, using a list of packages and various options.  While Mikrotik provides a Linux version of `netinstall`, running it involves **many** steps.  One of which is the downloading packages, for the right CPU, possibility some "extra-packages" too.

Mikrotik has a good overview of `netinstall` and the overall process: https://help.mikrotik.com/docs/display/ROS/Netinstall#Netinstall-InstructionsforLinux

The source code and CI image building are stored in a public GitHub repo, and an OCI is also pushed to DockerHub by GitHub's Actions.  [Comments, complaints, and bugs](https://github.com/tikoci/netinstall/issues) are all welcome via GitHub Issues in the `tikoci/netinstall` [repo](https://github.com/tikoci/netinstall).  


### Dual Use – `/container` or Linux Shell

#### Just Automating `netinstall` from Linux

The "script" is invoked by just calling `make` from the same directory, and by default that will start a netinstall using ARM packages, from "stable" channel, on an interface named "eth0". _This is often not the case, so variables on the network interface/IP will likely need to be changed from defaults._

#### _or..._ Running as a Mikrotik `/container` 

There is an associated `Dockerfile` to enable containerization, including using QEMU to run Mikrotik's X86 `netinstall` binary on other platforms, specifically ARM and ARM64/aarch (see forked code).  By default, this container runs as a "service", so after one netinstall completes, it goes on to waiting for the next. 




## RouterOS `/container` Install

`/container` running `netinstall` is handy to enable reset/recovery of a connected RouterOS device **without needing a PC**.  The basic approach is a container's VETH is bridged to a physical ethernet interface, using a new `/interface/bridge` for "netinstall".  Then the container runs the Linux `netinstall` using emulation (on arm/arm64).   The trick here is no `/container/mounts` are needed – **install packages are downloaded _automatically_** based on the environment variables provided to the image.

> Using "vlan-filtering=yes" bridge should work if VETH and target physical port have some vlan-id=.  But for `netinstall` likely best if just separate, since VLANs add another level of complexity here.  Possible, just untested and undocumented here.

#### Prerequisites

* RouterOS device that supports containers, generally ARM, ARM64, or X86 devices
* Some non-flash storage (internal drives, ramdisk, NFS/SMB client via ROS, USB, etc.)
* `container.npk` extra-package has been installed and other RouterOS specifics, and `/system/device-mode` has been used to enable container support as well.

See Mikrotik's docs on `/container` for more details and background, including how to install the prerequisites:
https://help.mikrotik.com/docs/display/ROS/Container


#### Steps

Instructions below assume a non-flash disk is at `disk1/` and `ether5` is where the device to be "netinstall'ed" is connected.  Adjust examples needed.

1. Create `/interface/veth` interface:
    ```
    /interface veth add address=172.17.9.200/24 gateway=172.17.9.1 name=veth-netinstall
    /ip address add address=172.17.9.1/24 interface=veth-netinstall
    ```
2. Create a separate bridge for `netinstall` use and add VETH to it:
    ```
    /interface bridge add name=bridge-netinstall
    /interface bridge port add bridge=bridge-netinstall interface=veth-netinstall
    ```
3. Add veth and physical port, _e.g._ "ether5", to the newly created bridge: 
    ```
    /interface bridge port add bridge=bridge-netinstall interface=ether5
    ```
    or, if the physical port is already in a bridge port, reassign it instead: `/interface bridge port [find interface=ether5] bridge=bridge-netinstall`
    
    > **NOTE**
    > 
    > Replace `ether5` with the ethernet interface to device needing `netinstall`.    

4. Adjust the firewall so the container can download packages/netinstall binary from Mikrotik.  The exact changes needed can be specific.  But if using the default firewall, the easiest may be:
    ```
    /interface/list/member add list=LAN interface=bridge-netinstall 
    ```
    > **TIP**
    >
    > Alternatively, you can /ip/firewall/filter or NAT rules on the containers subnet, to specifically allow VETH access to the internet.  Traffic between `netinstall` is forwarded, not routed, so only needed for outbound access from the container's IP.  **How?** - depends...   

5. Create some environment variables to control `netinstall` operation – adjusting all `value=` as needed:
    ```
    /container envs add key=ARCH name=NETINSTALL value=arm64
    /container envs add key=CHANNEL name=NETINSTALL value="testing"
    /container envs add key=PKGS name=NETINSTALL value="container zerotier wifi-qcom iot gps"
    /container envs add key=OPTS name=NETINSTALL value="-b -r" comment=" use EITHER -r to reset to defaults or -e for an empty config; use -b to remove any branding"
    ```
   
6. The `registry-url` is used to fetch "pull" images. Either DockerHub or GitHub Container Registry are supported.
 Use `/container/config/print` to view the `registry-url` and `tmpdir` in use on RouterOS (if any). 

    For DockerHub, the `registry-url` setting should be `https://registry-1.docker.io`, if not set use:
    ```
    /container config set registry-url=https://registry-1.docker.io tmpdir=disk1/pulls-docker
    ```
    
    > **NOTE** 
    >
    > Ensure `disk1/` is a valid disk and has at least ~150MB available. Some routers may need the form `usb1-part1/` or similar.  The disk path can be a cheap USB stick to run the container even – just not a router's boot flash.  **Non-specific errors may result if an invalid path is used.**

7. Create the container.  This assumes DockerHub is used:
        
    ```
    /container add remote-image=ammo74/netinstall:latest envlist=NETINSTALL interface=veth-netinstall logging=yes workdir=/app root-dir=disk1/root-netinstall
    ```
    
    > **NOTE**
    >
    > Or, to use GHCR (ghcr.io), instead of DockerHub, the above would use `remote-image=ghcr.io/tikoci/netinstall` instead.
    >
    > Or, if you built your own `.tar` file using `docker buildx`, do not use ~~`remote-image=`~~ at all.  Instead, use `file=` that contains the path of the `.tar` image uploaded to the router.  
    >
    > The rest of the attributes to `/container add` are the same as example. 

    It will take about a minute to download and process the image file. 
    After the new container is expanded, it is indicated as a "stopped" status (instead of "expanding" or "error").  Status can be shown by using `/container/print`.  
        
    If you see "error" status means something failed, likely disk or firewall issues. Worth it to check the `/logs/print` to where the process has failed. 

8. Now start container! Use:  
    ```
    /container/start [find tag~"netinstall" status="stopped"]   
    ```

### Additional `/container/env` options

All options are described in greater detail later.  But `CHANNEL`, `ARCH`, `PKG`, and `OPTS` are the typical ones.  But some additional `/container/env` include:

#### `VER`
Instead of using `CHANNEL` like "stable", to select the version use:
```
/container envs add key=VER name=NETINSTALL value=7.12.1
```
If both `CHANNEL` and `VER` are used, VER wins.  

> **TIP**
>
> It recommend you only set `VER` when needed, since it overrides what is set in `CHANNEL`.  This may be what you want – just as a default "stable" makes more sense.

#### `VER_NETINSTALL`
To set the version of `netinstall` use:
```
/container envs add key=VER_NETINSTALL name=NETINSTALL value=7.15rc3
```
Left unset, the version of `netinstall` itself will follow what is set in `CHANNEL`, which defaults to "stable". 

#### `IFACE` and `CLIENTIP`
While these variables control networking, they shuld **not** be needed with `/container` as it should be automatic via `-i eth0`.  If not, [file a bug](https://github.com/tikoci/netinstall/issues).




## Building Container Locally
 The container can be built locally into the `.tar` file needed by RouterOS as an alternative to "pull".  The specific steps depending on your environment.  Generally, adapt the steps here with Mikrotik's [example Docker build steps](https://help.mikrotik.com/docs/display/ROS/Container#Container-c\)buildanimageonPC) for Pi-Hole.
 
 To begin, use `git clone https://github.com/tikoci/netinstall.git` to download needed `Dockerfile` and `Makefile` (that contains the `netinstall` logic) to your PC & use these with  `docker buildx` as described in Mikrotik's doc.  With a few more steps you get a `.tar` for use on RouterOS – without using DockerHub or GHCR.

 > **TIP**
 >
 > See [example/builder/README.md](example/builder/README.md) for a sample `Dockerfile` to build your `tar` image.
 >



## Configuration Options and Variables

Let's start with some commons ones, directly from the `Makefile` script — these are the **defaults** _if left any **unset**_ elsewhere:
```
ARCH ?= arm
PKGS ?= wifi-qcom-ac
CHANNEL ?= stable
OPTS ?= -b -r
# ...
```

These can used in three ways:

1. **Using environment variables**
 This is generally most useful with containers since environment variables are the typical configuration method.  
**_For Mikrotik RouterOS_** these are stored in `/container/env` and documented here.  
**_For Linux_** use `export VER_NETINSTALL=7.14.2` in a `.profile` or similar. This allows environment variables to persist on a Linux shell, similar to a container.  _i.e._ to avoid always having to provide them every time without having to edit the `Makefile` directly. 

2. **Provided via `make` at CLI**, in same directory as Makefile.  For example, to start netinstall for mipsbe using the `VER` number directly, with some extra packages and `-a 192.168.88.7` option, and specific version `netinstall` to be used of 7.15rc3: 
    ```
    cd ~/netinstall
    sudo make -d ARCH=mipsbe VER=7.14.3 PKGS="iot gps ups" CLIENTIP=192.168.88.7 VER_NETINSTALL=7.15rc3
    ```
    which results in the following `netinstall` command line being used:

    ```
    ./netinstall-cli-7.15rc3 -b -r -a 192.168.88.7 routeros-7.14.3-mipsbe.npk iot-7.14.3-mipsbe.npk gps-7.14.3-mipsbe.npk ups-7.14.3-mipsbe.npk
    ```
    > **TIP**
    >
    > Any `make` at CLI, can be used as the `/container cmd=` as an alternive to environment variables.

3. **Editing the `Makefile`**
 All of the variables are at the top of the file.  The ones with `?=` are used only if the same variable was **not** already provided via CLI or env.  In general, the only benefit of this method is proximity.  The method is not recommended - it makes using some future updated `Makefile` harder.   
   > **TIP**
   >
   > In the `Makefile` take careful note to **use <kbd>tab</kbd> indentations** – `make` will fail if <kbd>space</kbd> indentations are used.
   >
   > Also, be careful not to change or override computed variables, _i.e._ variables that use `=` or `:=` assignment.  The `?=` mean default _if not provided_, so those are the one designed to be "overriden".  



### Basic Settings

The specific file names needed for `netinstall` are generated automatically based on the `ARCH`, `CHANNEL`, and `PKGS` variables to make things easier to configure.   The routeros*.npk does NOT need to be included in `PKGS` - it is always added based on `ARCH`.  Only items "extra-packages" that needed to be installed are added to `PKGS`. 

| _option_ | _default_ |           |
| -     | -             | -             |
| ARCH | `arm` | **architecture name** must match `/system/resource`| 
| PKGS | `wifi-qcom-ac` | **additional package name(s)**, without version/CPU, separated by spaces, invalid/missing packages are skipped
| CHANNEL | `stable` | same choices as `/system/package/update` i.e. **testing**, **long-term**|

 Each time `make` is run, the `CHANNEL`'s current version is checked via the web and sets `VER` automatically.

 
 ### Version Selection

 By design, `CHANNEL` should be used to control the version used. 

If `VER` (RouterOS) and/or `VER_NETINSTALL` (executable) are provided, the string must be in the same form as published, like `7.15rc2` or `7.12.1`.  It **cannot** be a channel name like "stable".  But these variables can be any valid version, including older ones no longer on a channel.

`VER_NETINSTALL` is useful since sometimes `netinstall` has bugs or gains new features.  Generally, a newer netinstall can, and often should, be used to install older versions _i.e. some potential `OPTS` has changed over time..._ By default, only `CHANNEL` controls what version of `netinstall` will be used.  Meaning, even if `VER` is lower/older than `VER_NETINSTALL`, the latest "stable" `netinstall` for Linux will be used by default.  That is unless `VER_NETINSTALL` is specified explicitly

| _option_ | _default_ |           |
| -     | -             | -             |
| VER | _calculated from `CHANNEL`_ | specific version to install on a device, in `x.y.z` form |
| VER_NETINSTALL | _calculated from `CHANNEL`_ | version of `netinstall` to use, can be different than `VER` |


### `OPTS` - Device Configuration
 In the variable `OPTS`, the string is provided directly to `netinstall` unparsed.  So any valid `netinstall` command line options can be provided – they just get inserted with run.  
 
To get an **empty config**, change `-r` in the `OPTS` variable to a **`-e`** (both `-r` and `-e` are NOT allowed at some time).  

The real `netinstall` also supports additional options, like replacing the default configuration via an option `-s <defconf_file>`, among others.  These too can be provided in `OPTS` - along with existing options. 

> **TIP**
>
> If netinstall option needs a file, `/container/mount` can used, and the "container-relative" full path referenced in same `OPTS` after flag. For example, `-r -s /data/mydefconf.rsc`.
 
| _option_ | _default_ |           |
| -     | -             | -             |
| OPTS | `-b -r` | default is to "remove any branding" `-b` and "reset to default" `-r`, see [`netinstall` docs](https://help.mikrotik.com/docs/display/ROS/Netinstall#Netinstall-InstructionsforLinux)  |

### Network and System Configuration

Critical to `netinstall` working to flash a device is the networking is configured.  This is the trickiest part.  The `-i` or `-a` options must align with everything else, which corresponds to the `IFACE` **OR** `CLIENTIP`.

Mikrotik has a YouTube video that explains a bit about these interface vs IP options: [Latest netinstall-cli changes](https://youtu.be/EdwcHcWQju0?si=CrmixEZyH7FOjlZk).  These are more applicable if you're using Makefile standalone on a Linux machine - if running in a `/container`, the network default here should work.

In either case, the router and machine (or container's VETH) should be directly connected or on a bridge without ANY other traffic.  An IP address should be installed on the system running `make`.  You may need internet or Wi-Fi initially to download the packages (`make download`).

If used within a Mikrotik `/container` via the Dockerfile/registry, the defaults should work: `-i eth0 ...` since the container only has one VETH _and the IP config has to work to get to this point._

| _option_ | _default_ |           |
| -     | -             | -             |
| IFACE | `eth0` | physical interface name connected to the device to `netinstall`, i.e. the link name in `ip addr` |
| CLIENTIP | _not set_ | by default `-i <iface>` is used, if `CLIENTIP` then `-a <clientip>` is used |
| NET_OPTS | _calculated_ | raw `netinstall` network options, like "-i en4" – `IFACE` and `CLIENTIP` are ignored if `NET_OPTS` is set, only needed if `-i <iface>` or `-a <clientip>` do not work (or change)|

### Branding and Non Standard Packages
To use a branding package, `PKGS_CUSTOM` variable can be used with `/container/mount`.  The full container-relative path need to be used.  The value of `PKGS_CUSTOM` is simply appended to the end of the `netinstall` command, so any package with a valid full path can used.
   
| _option_ | _default_ |           |
| -     | -             | -             |
| PKGS_CUSTOM | _empty_ | full path _within container_ to addtional packages, space seperated; any paths must match `/container/mount`

### Uncommon Options
This should not be changed, documented here for consistency.

| _option_ | _default_ |           |
| -     | -             | -             |
| QEMU | `./i386` | `qemu-user-static` is needed to run `netinstall` on non-Intel platforms (`QEMU` is NOT used if X86).  See Dockerfile, but Alpine Linux does not have a pre-built package, so it's borrowed from a Debian build for use on Alpine.    |
| URLVER | https://upgrade.mikrotik.com/routeros/NEWESTa7 | URL used to determine what version is "stable"/etc |
| PKGS_FILES | _computed_ | _read-only_, in logs shows the resolved "extra-package" to be installed


## Linux Install and Usage

#### Prerequisites
* Linux device (or virtual machine) with ethernet 
* Some familiarity with the UNIX shell and commands
* `make`, `wget`, and `unzip` installed on your system.

> **NOTE**
>
> Each distro is different.  Only limited testing was done on Linux, specifically virtualized Ubuntu.  While very generic POSIX commands/tools are used, still possible to get errors that stop `make` from running.  Please report any issues found, including errors.

#### Downloading Code to Run on Linux

You can download the Makefile itself to a new directory, But it may be easier to just use `git`, to make any future updates easier:

    ```
    cd ~
    git clone https://github.com/tikoci/netinstall.git
    cd netinstall 
    ```
To test it, just run `make download` to which will download ARM packages, not NOT run netinstall.  


#### Linux Usage Examples

The begin, `make` needs to be run from the **same directory** as the `Makefile`.  To use examples, the current directory in shell **must** be contain the `Makefile`.


> **INFO**
>
> `sudo` must be used on most desktop Linux distros for any operation that starts running `netinstall`, since privileged ports are used.
> But just downloading files, should not require `root` or `sudo` – but running `netinstall` might on most Linux distros since it listens on a privileged port (69/udp).
>
* Download files for "stable" on the "tile" CPU - but NOT run netinstall:
    ```sh
    make stable tile download 
    ```
* The runs netinstall using "testing" (`CHANNEL`) build with "mipsbe" (`ARCH`):
    ```sh
    sudo make testing mipsbe 
    ```
* To remove all cached downloaded files:
    ```sh
    make clean
    ```
* This command will continuously run the netinstall process in a loop.
    ```sh
    sudo make service
    ```
* All of `netinstall` options can be also provided using the `VAR=VAL` scheme after the `make`: 
    ```sh
    make run ARCH=mipsbe VER=7.14.3 VER_NETINSTALL=7.15rc3 PKGS="wifi-qcom container zerotier" CLIENTIP=192.168.88.7 OPTS="-e" 
    ```
    > `OPTS` is ace-in-the-hole since the value it just appended to `netinstall`, this can be used to control important stuff like `-e` (empty config after netinstall) vs `-r` (reset to defaults) options, or any valid option to netinstall.  `PKGS` is **only** for extra-packages – the base `routeros*.npk` is always included (based on `ARCH` and `VER`).



## `make` arguments for CLI (or Docker `CMD`)

The script is based on a `Makefile` and the `make` command in Linux.  One important detail is that `make` looks for the `Makefile` within the current working directory.  


### Basic usage

* `make` -  same as `make run`, see below
* `make run` - **CLI default** is run netinstall unit found and finished, then stop the container
* `make service` - **Dockerfile default** runs netinstall as a service until stopped manually
* `make download` - used on desktop to download packages before potentially disconnecting the network, then `make` can be used without internet access

### Using CLI "shortcuts"

Any targets provided via arguments to `make` will OVERRIDE any environment variable with the same name. _i.e._ CLI arguments win
* `make <stable|testing|long-term>` - specify the `CHANNEL` to use
* `make <arm|arm64|mipsbe|mmips|smips|ppc|tile>` - specify the `ARCH` to use

For example `make testing tile` which will start `netinstall` using the current "testing" channel version, for the "tile" architecture.  

### Combine `make` "shortcuts"

For offline use, while only one channel and one architecture can be used at a time...Downloaded files are cached until deleted manually or `make clean`. So to download without running, add a `download` to the end of `make stable mipsbe download`, and repeat for any versions you want to "cache".

> **TIP**
>
> The "shortcut" with `make` variables provided like `make download VER=7.12 ARCH=mmips CLIENTIP=192.168.88.4 VER_NETINSTALL=7.15rc3`.  Just don't mix TOO many, but output (or logs) should indicate the potential problem

### Troubleshooting and File Management

* `make clean` - remove all stored packages and netinstall; will be re-created at startup again
* `make nothing` - does nothing, except keep running; used to access `/container/shell` without starting anything
* `make dump` - for internal debugging use, not much data

    

### Wait, a C/C++ `Makefile`, why not python or node?
The aim here is to simplify the process of automatically downloading all the various packages and `netinstall` tool itself.  But also an experiment in approaches too.  Essentially the "code" is just an old-school UNIX `Makefile`, but beyond its history, it has some modern advantages:
 *  `make` is very good at maintaining a directory with all the needed files, so it downloads only when needed efficiently.  
 * By using [`.PHONY` targets](https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html), and non-traditional target names, _`make`_ this approach act more "script-like" than a C/C++ build tool.
 * `make` natively supports taking variables from **either** via `make` arguments or environment variables.  This is pretty handy to allow some code to support containerization and plain CLI usage
 * As a "script interpreter", `make` (plus busybox tools) is significantly smaller "runtime" than Python/Node/etc.  Before loading the packages, the container image is 6MB.  

The disadvantage is that is complex to understand unless one is already familiar with `Makefile`. It's a dense ~200-page manual (see "GNU make manual" in [HTML](https://www.gnu.org/software/make/manual/make.html) or [PDF](https://www.gnu.org/software/make/manual/make.pdf)).
 But since `make` deals well with state and files, it saves a lot of `if [ -f routeros* ] ... fi` stuff it takes to do the same as here in `bash`... 


After trying this, it does seem like a nifty trick in the bag to get a little more organization out of what is mainly some busybox and `/bin/sh` commands.  In particular, how it deals with variables from EITHER env or program args.  Anyway, worked well enough for me to write it up and share – both the tool and approach.

     



## Unlicensing

This work is marked with CC0 1.0. To view a copy of this license, visit https://creativecommons.org/publicdomain/zero/1.0/


