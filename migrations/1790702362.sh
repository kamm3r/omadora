echo "Install the compiler and Qt pieces for building Omarchy-style apps"

# The omarchy-app agent skill builds apps the way Hype, Monologue, and Omacut
# are built: C++ and Qt Quick, compiled with qmake6 and make, with SVG icons,
# audio and video through Qt Multimedia, and heavy media work through ffmpeg.
# Qt arrived only as a dependency of those apps, and the compiler not at all.
# Fedora names: qmake6 comes with qt6-qtbase-devel, and a machine that swapped
# to RPM Fusion's ffmpeg keeps it rather than conflicting with ffmpeg-free.
omarchy-pkg-add gcc-c++ make qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtmultimedia-devel qt6-qtsvg-devel qt6-qtwayland-devel
if omarchy-cmd-missing ffmpeg; then
  omarchy-pkg-add ffmpeg-free
fi
