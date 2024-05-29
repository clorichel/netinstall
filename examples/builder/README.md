## Building the `netinstall` image locally

The following mini-project has an **example** `Dockerfile` and build script that shows how to customize `netinstall` using a local build.

### _Example:_ Building packages into the container at build time.
The `Dockerfile` shows using `ENV` to set the netinstall options built into the container, using the DockerHub version as the "base image".  Additional, the example shows `make download`, which causes the RouterOS packages to be downloaded.  Those packages will be part of the image, so if `netinstall-*.tar` is used on RouterOS, no downloading or even any /container/env should be needed - the values will come from your customized `Dockerfile` here.

> [!TIP]
>
> In the example `Dockerfile`, the variable have the same maining as described in the project [`README.md`](../../README.md).  You can add other `make` commands, and/or remove the `make download` if you want too.

### Build using `docker buildx`

There are many ways to build containers.  Here [Docker Desktop](https://www.docker.com/products/docker-desktop/) is assumed.

The basic command is just:
```
docker buildx build --platform=linux/arm64 --output "type=oci,dest=mynetinstall.tar" --tag mynetinstall .
```
And if familar with Docker, it's not hard. 

#### Using `./build.sh` Build Scripts Here

To build the image, there is `./build.sh` to build three `tar` files, one for each RouterOS architecutre that supports `/container`.   

If you need to build the `Dockerfile`, for one platform just provide the RouterOS architecutre name:
```
./build.sh arm64
``` 
Valid architecture values are "arm64", "arm", and "x86" - these values apply to the /container - the container can contain packages for **any** architecture. 


> **NOTE**
>
> `./build-multi.sh` is the main builder - it does the "heavy lifting" to _actually_ build the packages from `./build.sh`.  But using all three support platforms in one "multi-platform" image is far from idea here.  _i.e._ The image file be **huge** if _all packages_ for _all platforms_ were used with the `make download` in the example. 
