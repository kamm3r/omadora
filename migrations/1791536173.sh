echo "Install the libvips command-line tools for image picker thumbnails"

# Arch's libvips ships vipsthumbnail; Fedora splits it into vips-tools. Without
# it the background picker, which builds thumbnails before opening, drops every
# row and shows an empty grid.
omarchy-pkg-add vips-tools
