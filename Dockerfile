# Base image
FROM docker.io/library/archlinux:base-devel

ENV DEVKITPRO=/opt/devkitpro
ENV DEVKITARM=/opt/devkitpro/devkitARM
ENV DEVKITPPC=/opt/devkitpro/devkitPPC

# Install dependencies
RUN pacman -Syu --needed --noconfirm pacman-contrib namcap git

RUN pacman-key --init
RUN pacman-key --recv BC26F752D25B92CE272E0F44F7FD5492264BB9D0 --keyserver keyserver.ubuntu.com
RUN pacman-key --lsign BC26F752D25B92CE272E0F44F7FD5492264BB9D0

RUN pacman -U https://pkg.devkitpro.org/devkitpro-keyring.pkg.tar.zst

RUN echo "[dkp-libs]" >> /etc/pacman.conf
RUN echo "Server = https://pkg.devkitpro.org/packages" >> /etc/pacman.conf

RUN pacman -Syu

# Setup user
RUN useradd -m builder && \
    echo 'builder ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
WORKDIR /home/builder
USER builder

# Install paru
RUN git clone https://aur.archlinux.org/paru-bin.git
RUN cd paru-bin && makepkg -si --noconfirm

# Copy files
COPY LICENSE README.md /
COPY entrypoint.sh /entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
