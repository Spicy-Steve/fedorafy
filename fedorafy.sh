# === Detect root privilages ===
if [[ $EUID -ne 0 ]]; then
    echo "Please run this script with sudo or as root user instead of $USER"
    exit 1
fi

# === Info ===
echo "This script is intended to be ran on a fresh installation of Fedora, last updated for verison 43"
echo "For unattended versions of this script, download one of the other scripts from "
read -p "Do you wish to being setup? [Y/n]" start
start=${start,,}
if [[ $start = "y" || $start ="yes" || -z $start ]]; then
    continue
else
    exit 1
fi

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
    echo "Installing GPU accelerated media packages for AMD..."
    dnf install -y mesa-vdpau-drivers libva-utils

    read -p "Would you like to install ROCm? (recommended for Machine Learning) [Y/n]" rocm
    rocm=${rocm,,}
    if [[ $rocm = "y" || $rocm = "yes" || -z $rocm ]]; then
        echo "Adding ROCm repository..."
        wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
        rpm -ivh epel-release-latest-10.noarch.rpm
        dnf config-manager --enable codeready-builder-for-rhel-10-x86_64-rpms
        dnf install -y python3-setuptools python3-wheel
        
        echo "Installing ROCm..."usermod -a -G render,video $LOGNAME # Add the current user to the render and video groups
        dnf install -y rocm
    fi

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
fi

# === Optionally install flatpak ===
read -p "Would you like to enable flatpak? [Y/n]" fpkrepo
fpkrepo=${fpkrepo,,}
if [[ $fpkrepo = "y" || $fpkrepo = "yes" || -z $fpkrepo ]]; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    # === Ask for flatpaks ===
    read -p "Would you like to install essential flatpaks? [Y/n]" fpk
    fpk=${fpk,,}
    if [[ $fpk = "y" || $fpk = "yes" || -z $fpk ]]; then
        flatpak install -y com.github.tchx84.Flatseal org.localsend.localsend_app com.dec05eba.gpu_screen_recorder
    else
        echo "Skipping..."
        continue
    fi
else
    echo "Skipping..."
    continue
fi


# === Ask for gaming packages ===
read -p "Would you like to install essential gaming packages? [Y/n]" game
game=${game,,}
if [[ $game = "y" || $game = "yes" || -z $game ]]; then
    echo "Installing essential gaming packages..."
    dnf install -y steam goverlay wine
    
    if [[ $fpkrepo = "y" || $fpkrepo = "yes" || -z $fpkrepo ]]; then
        flatpak install -y com.github.Matoking. protontricks net.davidotek.pupgui2
    fi
fi
# === Self deletion after everything ===
echo "Cleaning up..."
trap 'rm -f -- "$0"' EXIT

echo "=== Setup Complete! ==="
read -p "Do you wish to reboot? (please make sure everything is saved) [Y/n]" reboot
reboot=${reboot,,}
if [[ $reboot = "y" || $reboot = "yes" || -z $reboot ]]; then
    reboot now
fi
