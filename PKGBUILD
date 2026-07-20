pkgname=git-setup
pkgver=0.1.0
pkgrel=1
pkgdesc='Configure Git, GitHub, SSH and GPG interactively'
arch=('any')
url='https://github.com/robert-flo/git-setup---hermes-agent-era'
license=('MIT')
depends=('git' 'github-cli' 'gnupg' 'openssh' 'git-delta')
source=(
  "${pkgname}::${url}/archive/refs/tags/v${pkgver}.tar.gz"
  "${pkgname}"
)
sha256sums=('SKIP' 'SKIP')

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
}
