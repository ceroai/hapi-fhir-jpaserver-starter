#!/bin/sh
# Borra del keystore de Java ($1) las raíces de las que cuelgan las CAs
# intermedias de eMudhra cuyas claves privadas quedaron expuestas, para que
# la JVM no acepte certificados emitidos por ellas. Falla cerrado: si no
# puede leer el keystore, no da por ausente ninguna raíz.
set -eu

keystore="$1"
shift
set -- "AAA Certificate Services" "emSign ECC Root CA - G3"

# Lista el keystore en inglés y deja el listado en $out. Aborta si keytool
# falla, si el keystore está vacío o si no se leyó un alias por entrada.
list() {
  out=$(LC_ALL=C keytool -J-Duser.language=en -J-Duser.country=US \
    -list -v -keystore "$keystore" -storepass changeit) || {
    echo "keytool no pudo listar $keystore" >&2
    exit 1
  }
  total=$(printf '%s\n' "$out" | sed -n 's/^Your keystore contains \([0-9][0-9]*\) entr.*/\1/p')
  aliases=$(printf '%s\n' "$out" | grep -c '^Alias name: ' || true)
  if [ -z "$total" ] || [ "$total" -eq 0 ] || [ "$aliases" -ne "$total" ]; then
    echo "listado inesperado de $keystore: ${total:-?} entradas, $aliases alias" >&2
    exit 1
  fi
}

# Alias cuyo sujeto tiene CN=$1. Los alias pueden traer espacios
# (p. ej. "aaacertificateservices [jdk]"), por eso se toma la línea completa.
aliases_of() {
  printf '%s\n' "$out" | awk -v cn="CN=$1" '
    /^Alias name: /{a=substr($0, 13)}
    /^Owner: /{n=split(substr($0, 8), f, ", "); for (i=1; i<=n; i++) if (f[i]==cn) print a}'
}

list
for root in "$@"; do
  found=$(aliases_of "$root")
  case $(printf '%s' "$found" | grep -c '' || true) in
    0) echo "$root: no está en $keystore, nada que borrar" ;;
    1)
      echo "$root: borrando alias '$found' de $keystore"
      keytool -delete -keystore "$keystore" -storepass changeit -alias "$found"
      ;;
    *)
      echo "$root: se esperaba un alias y hay varios en $keystore: $found" >&2
      exit 1
      ;;
  esac
done

list
for root in "$@"; do
  if [ -n "$(aliases_of "$root")" ]; then
    echo "$root sigue en $keystore" >&2
    exit 1
  fi
done
echo "$keystore: $total entradas, sin las raíces de eMudhra"
