# === Detect root privilages ===
if [[ $EUID -ne 0 ]]; then
    echo "Please run this script with sudo or as root user instead of $USER"
    exit 1
fi

# === Detect distro ===
if [ -f /etc/fedora-release ]; then
    echo "Fedora detected!"
    echo "Starting post-install setup for $USER"
else
    echo "You are not running Fedora! Stopping script..."
    exit 1
fi

# === Add RPM Fusion repo ===
echo "Adding required repositories..."
dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# === Update the system ===
echo "Making sure the system is up to date..."
dnf update -y

# === Swap codecs ===
echo "Installing full media codec support..."
dnf swap ffmpeg-free ffmpeg --allowerasing -y

# === DVD Support ===
echo "Installing packages for DVDs..."
dnf install -y rpmfusion-free-release-tainted
dnf install -y libdvdcss

# === Install GPU acceleration packages and NVIDIA driver ===
echo "What is your GPU vendor?"
echo "Please enter AMD/NVIDIA/Intel"
read gpu
gpu=${gpu,,}

if [ $gpu = "amd" ]; then
    echo "Adding ROCm repository..."
    dnf config-manager --add-repo=https://repo.radeon.com/rocm/yum/fedora/rocm.repo

    echo "Installing ROCm..."
    dnf install -y rocm-dkms rocm-utils rocm-libs rocm-dev
    dnf install -y hipblas rocrand rocthrust rocfft

    echo "Installing ROCm & codec packages for AMD..."
    dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
    dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld
elif [ $gpu = "intel" ]; then
    echo "Installing GPU acceleration packages for Intel..."
    dnf install -y intel-media-driver
elif [ $gpu = "nvidia"]; then
    echo "Installing NVIDIA driver and GPU acceleration packages..."
    dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda libva-nvidia-driver
else
    echo "Invalid GPU vendor entered, re-run the script to try again..."
fi

# === Optionally install flatpak ===
read -p "Would you like to enable flatpak? [Y/n]" fpk
if [[ $fpk = "y" || $fpk = "yes" || -z $fpk ]]; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi
