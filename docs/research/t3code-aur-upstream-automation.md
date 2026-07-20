# Automatización de versiones upstream en `t3code-aur`

Investigación realizada el 20 de julio de 2026 sobre el checkout local
`/compartir/clones/t3code-aur`, en el commit
[`d9717ca`](https://github.com/maria-rcks/t3code-aur/commit/d9717ca7289b99ca7cc17f88ad975d465eb66d6b).

## Respuesta corta

`t3code-aur` usa las dos cosas: **GitHub Actions como orquestador de CI** y
**cuatro scripts Bash propios** para la lógica del dominio. Actions aporta el
reloj, el disparo manual, la matriz de paquetes, el contenedor Arch Linux, los
tokens y la subida del artefacto. Los scripts consultan las releases de
upstream, detectan el cambio, reescriben `PKGBUILD`, preparan los archivos
compartidos y sincronizan un repositorio Git del AUR. La declaración del propio
repositorio coincide con esa implementación
([`README.md`, líneas 29–40](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/README.md#L29-L40),
[`publish-aur.yml`, líneas 25–88](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L25-L88)).
No hay Renovate, Dependabot, webhook de upstream ni una acción especializada
para el AUR en el árbol inspeccionado; el único workflow llama directamente a
los scripts propios
([raíz del repositorio en `d9717ca`](https://github.com/maria-rcks/t3code-aur/tree/d9717ca7289b99ca7cc17f88ad975d465eb66d6b)).

El flujo completo es:

```text
cron / push / ejecución manual
  → consultar hasta 100 releases de pingdotgg/t3code
  → elegir release + AppImage según la variante
  → comparar SHA-256 con un archivo de estado
  → actualizar PKGBUILD y regenerar .SRCINFO si cambió
  → construir el paquete en Arch Linux
  → publicar PKGBUILD/.SRCINFO/recursos en el Git remoto del AUR
  → guardar PKGBUILD/.SRCINFO/SHA nuevos en el repositorio de GitHub
```

Las etapas y su orden están codificadas directamente en el workflow
([`publish-aur.yml`, líneas 88–215](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L88-L215)).

## 1. Disparadores y decisión de publicar

El workflow se ejecuta al hacer `push` a `main`, cada seis horas mediante
`0 */6 * * *`, o manualmente con `workflow_dispatch`. La ejecución manual tiene
un booleano `force_publish`, `false` por defecto
([`publish-aur.yml`, líneas 3–15](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L3-L15)).
El cron es sondeo, no un webhook de upstream; GitHub documenta además que los
workflows programados usan el último commit de la rama por defecto y que, sin
zona horaria explícita, el cron se interpreta en UTC
([documentación oficial de `on.schedule`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#onschedule)).

La decisión exacta es la siguiente
([`publish-aur.yml`, líneas 101–125](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L101-L125)):

| Evento | Hash cambió | `force_publish` | Resultado |
|---|---:|---:|---|
| `schedule` | sí | no aplica | actualiza, construye y publica |
| `schedule` | no | no aplica | termina sin construir ni publicar |
| `push` a `main` | cualquiera | no aplica | construye y publica; solo actualiza versión si cambió el hash |
| manual | sí | cualquiera | actualiza, construye y publica |
| manual | no | `true` | construye e intenta publicar los metadatos existentes |
| manual | no | `false` | termina sin construir ni publicar |

Por tanto, un cambio de mantenimiento en `main` vuelve a publicar las dos
variantes aunque upstream no haya cambiado. Como el payload AUR incorpora un
archivo `.upstream-commit` con `GITHUB_SHA`, un nuevo commit de `main` normalmente
produce también un commit nuevo en cada repositorio AUR
([`publish_aur.sh`, líneas 39–47 y 74–81](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts/publish_aur.sh#L39-L81)).

## 2. Una matriz para estable y nightly

Un solo job usa una matriz de dos entradas, ejecutadas de una en una mediante
`max-parallel: 1`. `fail-fast: false` permite que la otra variante continúe si
una falla:

- `t3code-bin` usa los archivos de la raíz, acepta releases no prerelease cuyo
  tag empiece por `v` y publica a `t3code-bin.git`.
- `t3code-nightly-bin` usa `packages/t3code-nightly-bin/`, exige
  `prerelease=true`, un tag con forma
  `vX.Y.Z-nightly...`, y publica a `t3code-nightly-bin.git`.

Ambas variantes buscan un AppImage x86_64 cuyo nombre cumpla
`^T3-Code-.*-x86_64\.AppImage$`. Las rutas, filtros, archivos de estado,
payloads y destinos AUR son datos de la matriz, no bifurcaciones duplicadas del
script
([`publish-aur.yml`, líneas 27–55](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L27-L55)).

## 3. Cómo detecta una nueva versión

`scripts/check_upstream.sh` ejecuta
`gh api repos/$UPSTREAM_REPO/releases?per_page=100`. Con `jq`, descarta drafts,
compara el campo `prerelease` con la variante, aplica la expresión regular al
tag y toma el **primer** resultado filtrado; después toma el primer asset que
coincida con la expresión del AppImage
([`check_upstream.sh`, líneas 4–41](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts/check_upstream.sh#L4-L41)).
La API usada es la lista de releases de GitHub, no la lista de tags; la
documentación oficial confirma que no incluye tags sin una release asociada y
que `per_page` admite como máximo 100
([REST API: List releases](https://docs.github.com/en/rest/releases/releases#list-releases)).

Para el checksum primero lee `asset.digest` y elimina el prefijo `sha256:`. Si
GitHub no devuelve digest, descarga el AppImage con tres reintentos de `curl` y
calcula `sha256sum` localmente
([`check_upstream.sh`, líneas 43–58](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts/check_upstream.sh#L43-L58));
el campo `digest` forma parte del esquema oficial de un release asset
([REST API de release assets](https://docs.github.com/en/rest/releases/assets)).

La versión para Arch sale del tag: quita el prefijo `v`, cambia guiones por
guiones bajos y elimina caracteres fuera de letras, dígitos, `_`, `.`, y `+`.
Por ejemplo, `v0.0.29-nightly.20260720.858` se convierte en
`0.0.29_nightly.20260720.858`
([`check_upstream.sh`, líneas 60–61](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts/check_upstream.sh#L60-L61),
[`packages/t3code-nightly-bin/PKGBUILD`, líneas 3–10](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/packages/t3code-nightly-bin/PKGBUILD#L3-L10)).

La señal de cambio no es el tag ni `pkgver`: es exclusivamente que el SHA-256
actual sea distinto del contenido de `upstream.sha256` de esa variante. El
script exporta el resultado y todos los metadatos mediante `$GITHUB_OUTPUT`
([`check_upstream.sh`, líneas 63–98](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts/check_upstream.sh#L63-L98)).

## 4. Actualización de `PKGBUILD`, checksum y `.SRCINFO`

Cuando el hash cambia, `scripts/update_pkgbuild.sh` lee el `pkgver` y `pkgrel`
actuales. Si cambia `pkgver`, fija `pkgrel=1`; si el `pkgver` calculado es igual,
incrementa `pkgrel`. Luego reemplaza con `sed` cinco datos del `PKGBUILD`:
`pkgver`, `pkgrel`, `_upstream_tag`, `_upstream_version` y el primer checksum del
bloque `sha256sums`; finalmente sobrescribe el archivo de estado con el nuevo
SHA-256
([`update_pkgbuild.sh`, líneas 31–61](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts/update_pkgbuild.sh#L31-L61)).

El primer checksum corresponde al AppImage; los dos siguientes corresponden al
icono y a `LICENSE`, que son recursos compartidos y no se recalculan en este
flujo
([`PKGBUILD`, líneas 48–57](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/PKGBUILD#L48-L57)).
Para nightly, `stage_shared_assets.sh` copia esos dos recursos desde la raíz al
directorio del paquete antes de construir
([`stage_shared_assets.sh`, líneas 4–25](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts/stage_shared_assets.sh#L4-L25),
[`publish-aur.yml`, líneas 148–155](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L148-L155)).

`.SRCINFO` no se edita con `sed`: CI crea un usuario no root, le entrega el
workspace y ejecuta `makepkg --printsrcinfo > .SRCINFO`. Después hace una
construcción real con `makepkg -f --nodeps --noconfirm`, y solo si tiene éxito
sube el `.pkg.tar.zst` como artefacto del workflow
([`publish-aur.yml`, líneas 141–175](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L141-L175)).
La construcción corre dentro de `archlinux:base-devel`; el workflow instala
`git`, OpenSSH, `rsync`, `curl`, GitHub CLI y `jq`
([`publish-aur.yml`, líneas 56–69](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L56-L69)).

## 5. Publicación al AUR y persistencia en GitHub

`scripts/publish_aur.sh` prepara en `/tmp/aur-payload` solo los archivos
declarados por la matriz, los aplana a la raíz y agrega `.upstream-commit`.
Después configura una clave SSH temporal, obtiene las host keys de
`aur.archlinux.org` con `ssh-keyscan`, clona el repositorio AUR y ejecuta
`rsync -a --delete` para que su contenido sea exactamente el payload. Si hay
cambios, crea un commit y hace push; clone y push se reintentan tres veces con
esperas de 5 y 10 segundos
([`publish_aur.sh`, líneas 11–29 y 36–81](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts/publish_aur.sh#L11-L81)).
Ese `.upstream-commit` contiene el `GITHUB_SHA` que disparó la ejecución, no el
commit automático de metadatos que se crea al final
([`publish_aur.sh`, línea 47](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts/publish_aur.sh#L47)).

Solo después de publicar al AUR, y solo si el hash cambió, el workflow agrega
`PKGBUILD`, `.SRCINFO` y `upstream.sha256`, crea un commit como
`github-actions[bot]`, hace `git pull --rebase` y empuja a la rama que disparó
el workflow
([`publish-aur.yml`, líneas 177–215](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L177-L215)).
El rebase fue agregado expresamente para incorporar el commit producido por la
entrada anterior de la matriz serial
([commit `ff5db15`](https://github.com/maria-rcks/t3code-aur/commit/ff5db158bd4f61212c0e1a8c1ae6970395e4634b)).

## 6. Secretos, variables y permisos

Hay dos credenciales con responsabilidades separadas:

- El `GITHUB_TOKEN` efímero se expone como `GH_TOKEN` para consultar la API y,
  mediante `actions/checkout`, autentica el push de metadatos al repositorio. El
  workflow concede `contents: write`; `actions/checkout` persiste por defecto
  ese token para comandos Git posteriores
  ([`publish-aur.yml`, líneas 17–23, 63–74 y 88–99](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L17-L99),
  [documentación oficial de `actions/checkout`](https://github.com/actions/checkout#checkout-v4)).
- `secrets.AUR_SSH_PRIVATE_KEY` se entrega únicamente al paso de publicación y
  el script falla si no existe fuera de `DRY_RUN`. Se escribe con modo `0600` y
  se usa con `IdentitiesOnly` y verificación estricta contra el archivo
  `known_hosts` recién generado
  ([`publish-aur.yml`, líneas 177–188](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L177-L188),
  [`publish_aur.sh`, líneas 31–61](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts/publish_aur.sh#L31-L61)).

Como inferencia operativa, una sola clave debe estar autorizada para empujar a
los dos destinos AUR codificados en la matriz; el workflow no admite una clave
distinta por variante
([`publish-aur.yml`, líneas 33–55](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L33-L55),
[líneas 177–185](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L177-L185)).

`UPSTREAM_REPO`, nombre/email del autor AUR y rama AUR son variables de
repositorio opcionales con valores por defecto. Las URLs AUR, filtros y payloads
viven en la matriz y no son secretos
([`publish-aur.yml`, líneas 20–55 y 179–185](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L20-L55)).

El push hecho con el `GITHUB_TOKEN` no genera recursivamente otra ejecución por
el trigger `push`; GitHub define esa supresión precisamente para evitar ciclos
([documentación oficial de `GITHUB_TOKEN`](https://docs.github.com/en/actions/concepts/security/github_token#when-github_token-triggers-workflow-runs)).

## 7. Evidencia de que opera automáticamente

La automatización estable ya estaba completa en el commit inicial
([commit `4a1979b`](https://github.com/maria-rcks/t3code-aur/commit/4a1979baa635cd65f3de5366a82f3099771583c8));
la variante nightly se agregó después como una segunda entrada reutilizando los
mismos scripts
([commit `8364ef2`](https://github.com/maria-rcks/t3code-aur/commit/8364ef20f3e63232c1a24ca2930a149f13b5212b)).
El historial contiene commits sucesivos firmados como autor por
`github-actions[bot]`, tanto para estable
([`0.0.28`, commit `965ddbf`](https://github.com/maria-rcks/t3code-aur/commit/965ddbf2fac830dcb07be668d8b1ffd3f3f4552e))
como para nightly
([`0.0.29_nightly.20260720.858`, commit `d9717ca`](https://github.com/maria-rcks/t3code-aur/commit/d9717ca7289b99ca7cc17f88ad975d465eb66d6b)).
También registra endurecimientos nacidos de operación real, como reintentos ante
fallos transitorios del AUR
([commit `9989e95`](https://github.com/maria-rcks/t3code-aur/commit/9989e957b71c8ad3b0dcea3022601eae9c873e7a)).

## 8. Limitaciones y riesgos del diseño actual

1. **Latencia y sondeo limitado.** Una release se descubre en el próximo ciclo
   de seis horas; no existe notificación desde upstream. Solo se pide la primera
   página de 100 releases y se toma el primer match, sin paginar ni ordenar en el
   cliente. Si una variante válida queda fuera de esa ventana, no se encontrará
   ([`check_upstream.sh`, líneas 12–24](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts/check_upstream.sh#L12-L24)).
   Del mismo modo, si una release contiene más de un asset cuyo nombre coincide,
   toma el primero y no exige unicidad
   ([`check_upstream.sh`, líneas 32–41](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts/check_upstream.sh#L32-L41)).

2. **El checksum es la identidad de la release.** Un tag nuevo que reutilice
   bytes idénticos no actualiza el paquete en una ejecución programada. En el
   caso inverso, reemplazar el asset del mismo tag incrementa `pkgrel`, que sí es
   una decisión adecuada para un rebuild, pero depende de que la mutación se
   refleje en `digest` o en la descarga
   ([`check_upstream.sh`, líneas 63–71](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts/check_upstream.sh#L63-L71),
   [`update_pkgbuild.sh`, líneas 39–44](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts/update_pkgbuild.sh#L39-L44)).

3. **Parser deliberadamente frágil.** La actualización supone asignaciones
   literales al comienzo de una línea y que el checksum del AppImage es la
   primera cadena del bloque `sha256sums`. Un refactor de formato del
   `PKGBUILD` puede hacer que `sed` no cambie lo esperado sin una validación
   posicional posterior específica
   ([`update_pkgbuild.sh`, líneas 31–59](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts/update_pkgbuild.sh#L31-L59)).

4. **Publicación no atómica.** Primero se empuja al AUR y después al repositorio
   fuente. Si el segundo push falla, el AUR ya quedó actualizado, mientras que
   el archivo de estado en GitHub no; la siguiente ejecución volverá a detectar
   el cambio. El script AUR evita commits vacíos, pero no hay rollback
   distribuido
   ([`publish-aur.yml`, líneas 177–215](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L177-L215),
   [`publish_aur.sh`, líneas 74–81](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts/publish_aur.sh#L74-L81)).

5. **No hay control de concurrencia entre ejecuciones.** `max-parallel: 1`
   serializa las dos entradas dentro de una misma matriz, pero el workflow no
   declara `concurrency`; dos runs distintos pueden consultar y tratar de
   publicar el mismo estado simultáneamente. El `pull --rebase` soluciona el
   desfase entre entradas de una ejecución, no garantiza exclusión mutua global
   ([`publish-aur.yml`, líneas 25–32](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L25-L32),
   [líneas 190–215](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L190-L215)).

6. **La sincronización es destructiva por diseño.** `rsync --delete` borra del
   checkout AUR cualquier archivo no incluido en el payload. Esto mantiene el
   AUR como espejo exacto, pero obliga a declarar todo archivo que se quiera
   conservar
   ([`publish_aur.sh`, líneas 63–68](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts/publish_aur.sh#L63-L68)).

7. **Host key obtenida en el mismo canal que se pretende autenticar.** El uso de
   `StrictHostKeyChecking=yes` evita aceptar una clave distinta de la escrita en
   `known_hosts`, pero esa clave se obtiene justo antes con `ssh-keyscan`, sin
   una huella previamente fijada. Como inferencia de seguridad, esto no ofrece
   el mismo anclaje de confianza que versionar/verificar una huella oficial
   conocida
   ([`publish_aur.sh`, líneas 55–61](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts/publish_aur.sh#L55-L61)).

8. **Entorno y acciones no fijados de forma inmutable.** Usa
   `ubuntu-latest`, `archlinux:base-devel`, `actions/checkout@v4` y
   `actions/upload-artifact@v4`, no digests de imagen ni SHAs completos. El
   resultado depende de versiones móviles del runner, la imagen, paquetes y tags
   de acciones
   ([`publish-aur.yml`, líneas 28–74](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L28-L74),
   [líneas 169–175](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L169-L175)).

9. **Validación enfocada, no instalación completa.** `makepkg --nodeps`
   construye sin resolver ni comprobar todas las dependencias declaradas, y solo
   se contempla el AppImage `x86_64`; no hay matriz de arquitecturas ni prueba de
   arranque de la aplicación
   ([`publish-aur.yml`, líneas 163–175](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L163-L175),
   [`PKGBUILD`, líneas 3–10](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/PKGBUILD#L3-L10),
   [líneas 59–68](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/PKGBUILD#L59-L68)).

10. **No hay una suite de pruebas del automatismo.** El árbol inspeccionado no
    contiene pruebas, ShellCheck ni actionlint; la validación se produce al
    ejecutar el flujo real y construir el paquete. Esto deja regresiones de los
    filtros y transformaciones de texto a cargo de la siguiente ejecución
    ([raíz del repositorio en `d9717ca`](https://github.com/maria-rcks/t3code-aur/tree/d9717ca7289b99ca7cc17f88ad975d465eb66d6b),
    [`publish-aur.yml`, líneas 76–86](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L76-L86)).

## 9. Patrón transferible a otro paquete AUR

La parte más reusable no es copiar literalmente el YAML, sino conservar sus
separaciones:

1. una configuración declarativa por paquete (repo upstream, filtro de release,
   filtro de asset, rutas, estado, destino AUR);
2. un detector idempotente que solo produce metadatos;
3. un actualizador pequeño de `PKGBUILD` y estado;
4. regeneración de `.SRCINFO` con `makepkg`, seguida de una construcción real;
5. un publicador AUR independiente con modo seco, detección de diff y
   reintentos;
6. persistencia del estado en el repositorio para que el siguiente sondeo pueda
   comparar.

Esas fronteras ya aparecen en los cuatro scripts (`check_upstream.sh`,
`update_pkgbuild.sh`, `stage_shared_assets.sh`, `publish_aur.sh`) y en el
workflow que solo los parametriza
([`scripts/`](https://github.com/maria-rcks/t3code-aur/tree/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/scripts),
[`publish-aur.yml`, líneas 25–55](https://github.com/maria-rcks/t3code-aur/blob/d9717ca7289b99ca7cc17f88ad975d465eb66d6b/.github/workflows/publish-aur.yml#L25-L55)).
Al trasladarlo conviene corregir al menos tres puntos: declarar `concurrency`,
usar como identidad `(tag, checksum)` en lugar de solo checksum, y fijar de
forma verificable acciones, imagen y host key. Estas tres son recomendaciones
derivadas de las limitaciones anteriores, no comportamientos que el repositorio
actual ya implemente.
