# This was necessary to do `asdf install postgres`:
# (I also had to follow the `brew install` instructions at
#  https://github.com/smashedtoatoms/asdf-postgres?tab=readme-ov-file#mac)
export PKG_CONFIG_PATH="/opt/homebrew/bin/pkg-config:$(brew --prefix icu4c)/lib/pkgconfig:$(brew --prefix curl)/lib/pkgconfig:$(brew --prefix zlib)/lib/pkgconfig"
