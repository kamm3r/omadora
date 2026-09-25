echo "Activate the Omarchy theme for existing T3 Code installs"

omarchy-pkg-present t3code || exit 0
omarchy-install-ai-t3-code
