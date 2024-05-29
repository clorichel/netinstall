#! /bin/sh
set -e

# variables controlling build
IMAGE=${IMAGE:-container}
PLATFORMS=${PLATFORMS:-"linux/arm64 linux/arm/v7 linux/amd64"}
TAG=${TAG:-$IMAGE-multi}
BUILDX_BUILDER_NAME=routeros-platforms-builder

# verify system
echo "Building multiplatform image for: $PLATFORMS"
echo "Verify docker installation" 
docker info > /dev/null
docker buildx version

# get the list of installed platforms (removing commas to keep sh list)
PLATFORM_NAMES=`docker buildx ls --format '{{.Name}}'`
PLATFORM_LIST=`docker buildx ls --format '{{.Platforms}}'`

# verify platforms are available
for platform in $PLATFORMS; do
    echo "\tChecking buildx has platform: $platform"
    echo $PLATFORM_LIST | grep -q $platform
    echo "\tVerify buildx has platform: $platform"
done
BUILDX_PLATFORMS=`echo $PLATFORMS | tr ' ' ','`
echo "\tAll platforms found, using buildx platform=$BUILDX_PLATFORMS"

echo "\tRun buildx create to create builder for requested platforms"
if [[ $PLATFORM_NAMES != *"$BUILDX_BUILDER_NAME"* ]]; then 
    docker buildx create --platform=$BUILDX_PLATFORMS --name $BUILDX_BUILDER_NAME 
fi

echo "\tRun buildx build to make the actually image"
docker buildx build --builder $BUILDX_BUILDER_NAME  --platform=$BUILDX_PLATFORMS --output "type=oci,dest=$TAG.tar" --tag $TAG .

echo "\tRemove custom multiplatform builder'"
docker buildx rm $BUILDX_BUILDER_NAME

echo "\t'ls' .tar file build"
ls -lh $TAG.tar

echo "\tCompleted.  Built OCI image: $(pwd)$TAG.tar"


# Author's Note: Ignore the irony of using a shell script to do a "build" of a Makefile container
