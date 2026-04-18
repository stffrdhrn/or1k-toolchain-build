#!/bin/bash
# Update the readme with the latest versions from our Dockerfile

DIR=$(dirname $0)
readme=$DIR/readme.md
dockerfile=$DIR/or1k-toolchain-build/Dockerfile

# Replace the versions in the example make command
replace_make() {
  local key=$1; shift
  local val=$1; shift
  echo "..make before.."
  grep $key= $readme
  sed -i -e "s/$key=[^ ]\+/$key=$val/" $readme
  echo "..make after.."
  grep $key= $readme
}

# replace default text
# `GCC_VERSION` - (default `15.1.0`)
replace_default() {
  local key=$1; shift
  local val=$1; shift
  echo "..default before.."
  grep "\`$key\` - " $readme
  echo "..default after.."
  sed -i -e "s/\`$key\` - (default \`[^ ]\+\`)/\`$key\` - (default \`$val\`)/" $readme
  echo "..default after.."
  grep "\`$key\` - " $readme
}

for envver in `grep '^ENV.*_VERSION=' $dockerfile`; do
  # skip the ENV bit
  if [ $envver == ENV ]; then
    continue
  fi

  key=${envver%%=*}
  value=${envver##*=}

  echo $key=$value
  replace_make $key $value
  replace_default $key $value
done
