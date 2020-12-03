#!/bin/bash

set -o errexit
set -o nounset

saturation=$1
version=$2
format=$3
method=$4
build_dir=$5
name=OpenMoji-${saturation^}

mkdir -p "$build_dir"

to_munge=$(mktemp)
rsync -ru "/mnt/$saturation/svg/" "$build_dir/scale/"
grep -FL '<g transform="translate(36 0) scale(1.3) translate(-36 0)">' \
     "$build_dir"/scale/*.svg \
     >"$to_munge" \
  || true
xargs --no-run-if-empty <"$to_munge" \
      sed -E -i \
          -e 's/(<svg .*>)/\1\n<g transform="translate(36 0) scale(1.3) translate(-36 0)">/;' \
          -e 's/(<\/svg>)/<\/g>\n\1/;'
xargs --no-run-if-empty <"$to_munge" \
      xmlstarlet edit \
                 --inplace \
                 --omit-decl \
                 -N svg=http://www.w3.org/2000/svg \
                 --update '/svg:svg/@viewBox' \
                 --value '-11 -11 91 91'
rm "$to_munge"

cat >"$build_dir/$name.toml" <<-EOF
	output_file = "$build_dir/$name.$method.ttf"
	color_format = "$method"

	[axis.wght]
	name = "Weight"
	default = 400

	[master.regular]
	style_name = "Regular"
	srcs = ["$build_dir/scale/*.svg"]

	[master.regular.position]
	wght = 400
EOF

nanoemoji --build_dir="$build_dir" \
          --config="$build_dir/$name.toml"

sed "s/Color/${saturation^}/;" \
    /mnt/font/OpenMoji-Color.ttx \
    > "$build_dir/$name.ttx"

xmlstarlet edit --inplace --update \
    '/ttFont/name/namerecord[@nameID="5"][@platformID="3"]' \
    --value "$version" \
    "$build_dir/$name.ttx"
ttx -m "$build_dir/$name.$method.ttf" \
    -o "/mnt/font/$method/$name$format.ttf" \
    "$build_dir/$name.ttx"
