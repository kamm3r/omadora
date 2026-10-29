echo "Raise the inotify instance budget for the desktop and development tools"

read -r instances < /proc/sys/fs/inotify/max_user_instances
if (( instances < 1024 )); then
  sudo sysctl -w fs.inotify.max_user_instances=1024
fi
