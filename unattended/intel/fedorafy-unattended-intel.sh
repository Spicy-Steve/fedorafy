# === Detect root privilages ===
if [[ $EUID -ne 0 ]]; then
    echo "Please run this script with sudo or as root user instead of $USER"
    exit 1
fi

# === Info ===
echo "Hope you know what you're doing, good luck!"

# === Detect distro ===
if [ -f /etc/fedora-release ]; then
    echo "Fedora detected!"
    echo "Starting post-install setup..."
else
    echo "You are not running Fedora! Stopping script..."
    exit 1
fi

# === Prevent usage if dnf is not found ===
if ! command -v dnf &> /dev/null; then
    echo "Something has gone terribly wrong, dnf was not found!"
    echo "Try to remedy this by installing dnf (if this is Fedora, of course) or by reinstalling Fedora from https://fedoraproject.org (legitimate site)"
    exit 1
fi

# === Set DNF defaultyes to "Y" ===
echo "Setting DNF to assume 'yes' for all prompts..."
echo "defaultyes=True" >> /etc/dnf/dnf.conf

# === Add RPM Fusion media repo ===
echo "Adding required repositories..."
dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# === Update the system ===
echo "Making sure the system is up to date..."
dnf update -y

# === Swap codecs ===
echo "Installing full media codec support..."
dnf swap ffmpeg-free ffmpeg --allowerasing -y

# === Install GPU acceleration packages ===
echo "Installing GPU accelerated media packages for Intel..."
dnf install -y intel-media-driver libva-utils

# === Install flatpak ===
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y com.github.tchx84.Flatseal org.localsend.localsend_app com.dec05eba.gpu_screen_recorder

# === Self deletion after everything ===
echo "Cleaning up..."
trap 'rm -f -- "$0"' EXIT

echo "=== Setup Complete! ==="
reboot now
