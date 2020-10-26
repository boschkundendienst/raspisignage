#!/bin/bash
  
# install prerequisites
pacman -Syu
pacman -S qt5-webkit git gcc make

# clone repository
git clone https://github.com/Topguy/mlbrowser.git

# prepare for build
cd mlbrowser
mkdir build
cd build
qmake DEFINES+=_BROWSER_ DEFINES+=_MOUSE_ DEFINES+=_PROPERTYCHANGER_ ../src/mlbrowser.pro

# build
make

# install
make install

echo "to uninstall run"
echo "   make uninstall"
echo "from within $(pwd)"
echo ""
echo "You can try  to run    mlbrowser -z 1 -platform linuxfb http://www.mofarennen.de"
