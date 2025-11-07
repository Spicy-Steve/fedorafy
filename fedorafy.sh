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

# === Prevent usage if dnf is not found ===
if ! command -v dnf &> /dev/null; then
    echo "Something has gone terribly wrong, dnf was not found!"
    echo "Try to remedy this by installing dnf (if this is Fedora, of course) or by reinstalling Fedora from https://fedoraproject.org (legitimate site)"
    exit 1
fi

# === Add RPM Fusion media repo ===
echo "Adding required repositories..."
dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# === Update the system ===
echo "Making sure the system is up to date..."
dnf update -y

# === Swap codecs ===
echo "Installing full media codec support..."
dnf swap ffmpeg-free ffmpeg --allowerasing -y

# === Install GPU acceleration packages and NVIDIA driver ===
while true; do
    read -p "Enter GPU vendor (AMD/NVIDIA/Intel): " gpu
    gpu=${gpu,,}
    case "$gpu" in
        amd|intel|nvidia)
            break
            ;;
        *)
            echo "Invalid entry. Please enter AMD, NVIDIA, or Intel."
            ;;
    esac
done

if [ $gpu = "amd" ]; then
    read -p "Would you like to install ROCm? (recommended for broad compatibility) [Y/n]" rocm
    rocm=${rocm,,}
    if [[ $rocm = "y" || $rocm = "yes" || -z $rocm ]]; then
        echo "Adding ROCm repository..."
        dnf config-manager --add-repo=https://repo.radeon.com/rocm/yum/fedora/rocm.repo

        echo "Installing ROCm..."
        dnf install -y rocm-dkms rocm-utils rocm-libs rocm-dev
        dnf install -y hipblas rocrand rocthrust rocfft
    fi

    echo "Installing GPU accelerated media packages for AMD..."
    dnf install -y mesa-vdpau-drivers libva-utils

elif [ $gpu = "intel" ]; then
    echo "Installing GPU accelerated media packages for Intel..."
    dnf install -y intel-media-driver libva-utils 

elif [ $gpu = "nvidia"]; then
    echo "Installing NVIDIA driver and GPU accelerated media packages..."
    dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda libva-nvidia-driver

    read -p "Would you like to install additional CUDA libraries? (reccomended for Machine Learning) [Y/n]" mlcuda
    mlcuda=${mlcuda,,}
    if [[ $mlcuda = "y" || $mlcuda = "yes" || -z $mlcuda ]]; then
        echo "Adding CUDA repository..."
        dnf config-manager addrepo --from-repofile=https://developer.download.nvidia.com/compute/cuda/repos/fedora42/$(uname -m)/cuda-fedora42.repo
        dnf clean all

        echo "Installing additional CUDA libraries..."
        dnf config-manager setopt cuda-fedora42-$(uname -m).exclude=nvidia-driver,nvidia-modprobe,nvidia-persistenced,nvidia-settings,nvidia-libXNVCtrl,nvidia-xconfig
        dnf -y install cuda-toolkit xorg-x11-drv-nvidia-cuda
    fi

else
    echo "Invalid GPU vendor entered, re-run the script to try again..."
fi

# === Optionally install flatpak ===
read -p "Would you like to enable flatpak? [Y/n]" fpk
if [[ $fpk = "y" || $fpk = "yes" || -z $fpk ]]; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi
