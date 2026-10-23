#!/bin/sh
# Borra del keystore de Java ($1) las raíces de las que cuelgan las CAs
# intermedias de eMudhra cuyas claves privadas quedaron expuestas, para que
# la JVM no acepte certificados emitidos por ellas.
set -eu

keystore="$1"
owners='CN=(AAA Certificate Services|emSign ECC Root CA - G3)(,|$)'

list() { keytool -list -v -keystore "$keystore" -storepass changeit; }

# Los alias pueden traer espacios (p. ej. "aaacertificateservices [jdk]").
list | awk -v re="$owners" '/^Alias name: /{a=substr($0, 13)} /^Owner: / && $0 ~ re {print a}' |
  while IFS= read -r alias; do
    keytool -delete -keystore "$keystore" -storepass changeit -alias "$alias"
  done

if list | grep -Eq "^Owner: .*$owners"; then
  echo "quedaron raíces sin borrar en $keystore" >&2
  exit 1
fi
