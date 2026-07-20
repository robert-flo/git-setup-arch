pkgname=git-setup
pkgver=0.1.0
pkgrel=1
pkgdesc='Configure Git, GitHub, SSH and GPG interactively'
arch=('any')
url='https://github.com/robert-flo/git-setup---hermes-agent-era'
license=('MIT')
options=('!debug')
depends=('git' 'github-cli' 'gnupg' 'openssh' 'git-delta')
source=(
  "${pkgname}-${pkgver}.tar.gz::${url}/archive/refs/tags/v${pkgver}.tar.gz"
  "${pkgname}"
)
sha256sums=(
  'd3559179dc27806a2b90f352fcea2adf8b485e949c7a6f561b566208f20173b7'
  'e1940018f1f1f042fdb697fdfcf022076cfcd2821c3689aaa3fd5c6d3583f150'
)

package() {
  local source_dir="${srcdir}/git-setup---hermes-agent-era-${pkgver}"
  local payload_dir="${pkgdir}/opt/${pkgname}"

  install -d "${payload_dir}"/{helper,lib,scripts,templates/git}
  install -Dm755 "${source_dir}/git-setup" "${payload_dir}/git-setup"
  install -Dm755 "${source_dir}/helper/"* "${payload_dir}/helper/"
  install -Dm755 "${source_dir}/lib/"* "${payload_dir}/lib/"
  install -Dm755 "${source_dir}/scripts/"* "${payload_dir}/scripts/"
  install -Dm644 "${source_dir}/templates/git/"* "${payload_dir}/templates/git/"
  install -Dm755 "${srcdir}/${pkgname}" "${pkgdir}/usr/bin/${pkgname}"
  install -Dm644 /dev/stdin "${pkgdir}/usr/share/applications/${pkgname}.desktop" << 'DESKTOP_ENTRY'
[Desktop Entry]
Name=git-setup
Comment=Configure Git, GitHub, SSH and GPG interactively
Exec=git-setup
TryExec=git-setup
Terminal=true
Type=Application
Icon=utilities-terminal
Categories=Development;Utility;
Keywords=Git;GitHub;SSH;GPG;
DESKTOP_ENTRY
}
