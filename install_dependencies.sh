#!/bin/bash

set -x
set -e

start_dir=$(pwd)

SMALT_VERSION="0.7.6"
BWA_VERSION="0.7.17"
TABIX_VERSION="master"
SAMTOOLS_VERSION="1.10"
MINIMAP2_VERSION="2.17"

SMALT_DOWNLOAD_URL="http://downloads.sourceforge.net/project/smalt/smalt-${SMALT_VERSION}-bin.tar.gz"
BWA_DOWNLOAD_URL="https://sourceforge.net/projects/bio-bwa/files/bwa-${BWA_VERSION}.tar.bz2/download"
TABIX_DOWNLOAD_URL="https://github.com/samtools/tabix/archive/${TABIX_VERSION}.tar.gz"
SAMTOOLS_DOWNLOAD_URL="https://github.com/samtools/samtools/releases/download/${SAMTOOLS_VERSION}/samtools-${SAMTOOLS_VERSION}.tar.bz2"
MINIMAP2_DOWNLOAD_URL="https://github.com/lh3/minimap2/releases/download/v${MINIMAP2_VERSION}/minimap2-${MINIMAP2_VERSION}_x64-linux.tar.bz2"

# Make an install location
if [ ! -d 'build' ]; then
  mkdir build
fi
cd build
build_dir=$(pwd)

# DOWNLOAD ALL THE THINGS
download () {
  url=$1
  download_location=$2

  if [ -e $download_location ]; then
    echo "Skipping download of $url, $download_location already exists"
  else
    echo "Downloading $url to $download_location"
    wget $url -O $download_location
  fi
}

download $SMALT_DOWNLOAD_URL "smalt-${SMALT_VERSION}.tgz"
download $BWA_DOWNLOAD_URL "bwa-${BWA_VERSION}.tbz"
download $TABIX_DOWNLOAD_URL "tabix-${TABIX_VERSION}.tgz"
download $SAMTOOLS_DOWNLOAD_URL "samtools-${SAMTOOLS_VERSION}.tbz"
download $MINIMAP2_DOWNLOAD_URL "minimap2-${MINIMAP2_VERSION}.tbz"

# Update dependencies
if [ "$TRAVIS" = 'true' ]; then
  echo "Using Travis's apt plugin"
else
  sudo apt-get update -q || true
  sudo apt-get install -y -q wget unzip zlib1g-dev cpanminus gcc bzip2 libncurses5-dev libncursesw5-dev libssl-dev libbz2-dev zlib1g-dev liblzma-dev r-base git curl locales
  sudo apt-get install -y -q bwa smalt libcurl4-openssl-dev tabix
fi

# Build all the things
## smalt
cd $build_dir
smalt_dir=$(pwd)/"smalt-${SMALT_VERSION}-bin"
if [ ! -d $smalt_dir ]; then
  tar xzfv smalt-${SMALT_VERSION}.tgz
fi
cd $smalt_dir
if [ ! -e "$smalt_dir/smalt" ]; then
  ln "$smalt_dir/smalt_x86_64" "$smalt_dir/smalt" 
fi

## bwa
cd $build_dir
bwa_dir=$(pwd)/"bwa-${BWA_VERSION}"
if [ ! -d $bwa_dir ]; then
  tar xjfv bwa-${BWA_VERSION}.tbz
fi
cd $bwa_dir
if [ ! -e "$bwa_dir/bwa" ]; then
  make
fi

## minimap2
cd $build_dir
minimap2_dir=$(pwd)/"minimap2-${MINIMAP2_VERSION}"
if [ ! -d $minimap2_dir ]; then
  tar xjfv minimap2-${MINIMAP2_VERSION}.tbz
fi


## tabix
cd $build_dir
tabix_dir=$(pwd)/"tabix-$TABIX_VERSION"
if [ ! -d $tabix_dir ]; then
  tar xzfv "${build_dir}/tabix-${TABIX_VERSION}.tgz"
fi
cd $tabix_dir
if [ -e ${tabix_dir}/tabix ]; then
  echo "Already built tabix"
else
  echo "Building tabix"
  make
fi

## samtools
cd $build_dir
samtools_dir=$(pwd)/"samtools-$SAMTOOLS_VERSION"
if [ ! -d $samtools_dir ]; then
  tar xjfv "${build_dir}/samtools-${SAMTOOLS_VERSION}.tbz"
fi
cd $samtools_dir
if [ -e ${samtools_dir}/samtools ]; then
  echo "Already built samtools"
else
  echo "Building samtools"
  sed -i 's/^\(DFLAGS=.\+\)-D_CURSES_LIB=1/\1-D_CURSES_LIB=0/' Makefile
  sed -i 's/^\(LIBCURSES=\)/#\1/' Makefile
  make prefix=${samtools_dir} install
fi

# Setup environment variables
update_path () {
  new_dir=$1
  if [[ ! "$PATH" =~ (^|:)"${new_dir}"(:|$) ]]; then
    export PATH=${new_dir}:${PATH}
  fi
}

update_path ${smalt_dir}
update_path ${bwa_dir}
update_path "${tabix_dir}"
update_path "${samtools_dir}"
update_path ${minimap2_dir}

cd $start_dir

# Install perl dependencies
cpanm Dist::Zilla
cpanm Dist::Zilla::PluginBundle::Starter

dzil authordeps --missing | cpanm
dzil listdeps --missing | cpanm

set +x
set +e
