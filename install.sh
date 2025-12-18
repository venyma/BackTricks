#!/bin/bash
set -e

CHROOT_DIR="/opt/debian-modern"
DEBIAN_RELEASE="bookworm"

echo "[+] BackTrack 5 Modern Integration Script"
sleep 2

if ! grep -qi backtrack /etc/issue; then
    echo "[-] NOT BACKTRACK."
    exit 1
fi

apt-get update || true
apt-get install -y debootstrap wget curl ca-certificates \
                   x11-xserver-utils pulseaudio fuse

if [ ! -d "$CHROOT_DIR" ]; then
    debootstrap --arch=i386 $DEBIAN_RELEASE $CHROOT_DIR http://deb.debian.org/debian/
fi

for fs in proc sys dev dev/pts; do
    mkdir -p $CHROOT_DIR/$fs
    mount --bind /$fs $CHROOT_DIR/$fs || true
done

mkdir -p $CHROOT_DIR/home
mount --bind /root $CHROOT_DIR/home/root || true

mount --bind /etc/os-release $CHROOT_DIR/etc/os-release || true

cp /etc/resolv.conf $CHROOT_DIR/etc/

cat << 'EOF' > $CHROOT_DIR/root/setup.sh
#!/bin/bash
set -e

apt update
apt install -y sudo curl git wget build-essential \
               firefox-esr chromium \
               python3 python3-pip python3-venv pipx \
               nodejs npm \
               pulseaudio \
               zsh tmux neovim \
               wireshark nmap sqlmap hydra \
               locales fuse

wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/ms.gpg
echo "deb [signed-by=/usr/share/keyrings/ms.gpg] https://packages.microsoft.com/repos/code stable main" \
    > /etc/apt/sources.list.d/vscode.list
apt update
apt install -y code

echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen

ln -sf /home/root /root

pipx ensurepath

chsh -s /usr/bin/zsh root
EOF

chmod +x $CHROOT_DIR/root/setup.sh
chroot $CHROOT_DIR /root/setup.sh

pulseaudio --start || true

create_launcher() {
    NAME="$1"
    CMD="$2"

    cat << EOF > /usr/local/bin/$NAME
#!/bin/sh
xhost +local: >/dev/null
export DISPLAY=:0
export PULSE_SERVER=127.0.0.1
chroot $CHROOT_DIR /bin/bash -c "$CMD"
EOF

    chmod +x /usr/local/bin/$NAME
}

create_launcher backtricks-fox "firefox-esr"
create_launcher backtricks-vscode "code --no-sandbox"
create_launcher backtricks-chromium "chromium --no-sandbox"
create_launcher backtricks-wireshark "wireshark"

cat << EOF > /usr/share/applications/firefox-modern.desktop
[Desktop Entry]
Name=Firefox (BackTricks)
Exec=/usr/local/bin/backtricks-fox
Type=Application
Icon=firefox
Categories=Network;WebBrowser;
EOF

cat << EOF > /usr/share/applications/vscode-modern.desktop
[Desktop Entry]
Name=VS Code (BackTricks)
Exec=/usr/local/bin/backtricks-vscode
Type=Application
Icon=code
Categories=Development;
EOF

cat << EOF > /usr/share/applications/chromium-modern.desktop
[Desktop Entry]
Name=Chromium (Modern)
Exec=/usr/local/bin/backtricks-chromium
Type=Application
Icon=chromium
Categories=Network;WebBrowser;
EOF

if ! grep -q debian-modern /etc/rc.local; then
cat << EOF >> /etc/rc.local
mount --bind /proc $CHROOT_DIR/proc
mount --bind /sys $CHROOT_DIR/sys
mount --bind /dev $CHROOT_DIR/dev
mount --bind /dev/pts $CHROOT_DIR/dev/pts
pulseaudio --start
exit 0
EOF
fi

echo "[+] Done."
echo "[+] Completed."
