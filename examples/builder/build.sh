#! /bin/sh
set -e

ROSARCH_DEFAULT="arm64 arm x86"
IMAGE=netinstall

ROSARCHARGS=${@:1}
ROSARCH=${ROSARCH:-${ROSARCHARGS:-$ROSARCH_DEFAULT}}
echo "Starting platform-specific build using $ROSARCH"
for rosarch in $ROSARCH; do 
  TAG=$IMAGE-$rosarch

  case $rosarch in
    arm64) PLATFORMS=linux/arm64 ;;
    arm) PLATFORMS=linux/arm/v7 ;;
    x86) PLATFORMS=linux/amd64 ;;
    *) echo "Bad platform: $rosarch"; exit -1 ;;
  esac

  echo "Build OCI with single, specific-platform using tag $TAG"
  source ./build-multi.sh

  echo "\tCompleted. Built $PLATFORMS platform-specific image: $(pwd)$TAG.tar"
done
