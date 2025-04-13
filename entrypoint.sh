#!/bin/bash
set -e

# Set path
WORKPATH=$GITHUB_WORKSPACE/$INPUT_PATH
HOME=/home/builder
BASEDIR="$PWD"

echo "::group::Copying files from $WORKPATH to $HOME/gh-action"
# Set path permision
cd $HOME
mkdir gh-action
cd gh-action
chmod -R a+rw ./
cp -rfv "$GITHUB_WORKSPACE"/.git ./
cp -fv "$WORKPATH"/PKGBUILD ./
echo "::endgroup::"

# Update archlinux-keyring
if [[ $INPUT_ARCHLINUX_KEYRING == true ]]; then
    echo "::group::Updating archlinux-keyring"
    sudo pacman -Syu --noconfirm archlinux-keyring
    echo "::endgroup::"
fi

# Update pkgver
if [[ -n $INPUT_PKGVER ]]; then
    echo "::group::Updating pkgver on PKGBUILD"
    sed -i "s:^pkgver=.*$:pkgver=$INPUT_PKGVER:g" PKGBUILD
    git diff PKGBUILD
    echo "::endgroup::"
fi

# Update pkgver
if [[ -n $INPUT_PKGREL ]]; then
    echo "::group::Updating pkgrel on PKGBUILD"
    sed -i "s:^pkgrel=.*$:pkgrel=$INPUT_PKGREL:g" PKGBUILD
    git diff PKGBUILD
    echo "::endgroup::"
fi

# Update checksums
if [[ $INPUT_UPDPKGSUMS == true ]]; then
    echo "::group::Updating checksums on PKGBUILD"
    updpkgsums
    git diff PKGBUILD
    echo "::endgroup::"
fi

# Generate .SRCINFO
if [[ $INPUT_SRCINFO == true ]]; then
    echo "::group::Generating new .SRCINFO based on PKGBUILD"
    makepkg --printsrcinfo >.SRCINFO
    git diff .SRCINFO
    echo "::endgroup::"
fi

# Validate with namcap
if [[ $INPUT_NAMCAP == true ]]; then
    echo "::group::Validating PKGBUILD with namcap"
    namcap -i PKGBUILD
    echo "::endgroup::"
fi

# Install depends using paru from aur
if [[ $INPUT_AUR == true ]]; then
    echo "::group::Installing depends using paru"
    source PKGBUILD
    paru -Syu --removemake --needed --noconfirm "${depends[@]}" "${makedepends[@]}"
    echo "::endgroup::"
fi

# Run makepkg
if [[ -n $INPUT_FLAGS ]]; then
    echo "::group::Running makepkg with flags"

    makepkg $INPUT_FLAGS

    # Get array of packages to be built
    mapfile -t PKGFILES < <( makepkg --packagelist )
    echo "Package(s): ${PKGFILES[*]}"
    
    # Report built package archives
    i=0
    for PKGFILE in "${PKGFILES[@]}"; do
        # makepkg reports absolute paths, must be relative for use by other actions
        RELPKGFILE="$(realpath --relative-base="$BASEDIR" "$PKGFILE")"
        # Caller arguments to makepkg may mean the pacakge is not built
        if [ -f "$PKGFILE" ]; then
            echo "pkgfile$i=$RELPKGFILE" >> $GITHUB_OUTPUT
        else
            echo "Archive $RELPKGFILE not built"
        fi
        (( ++i ))
    done

    echo "::endgroup::"
fi

echo "::group::Copying files from $HOME/gh-action to $WORKPATH"
sudo cp -fv PKGBUILD "$WORKPATH"/PKGBUILD
if [[ -e .SRCINFO ]]; then
    sudo cp -fv .SRCINFO "$WORKPATH"/.SRCINFO
fi
echo "::endgroup::"
