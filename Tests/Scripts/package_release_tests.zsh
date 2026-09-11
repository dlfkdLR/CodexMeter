#!/bin/zsh
set -euo pipefail

test_dir=${0:A:h}
project_root=${test_dir:h:h}
fixture_root=$(mktemp -d)
trap 'rm -rf "${fixture_root}"' EXIT

mkdir -p \
  "${fixture_root}/Config" \
  "${fixture_root}/Scripts" \
  "${fixture_root}/CodexMeter.app/Contents/MacOS" \
  "${fixture_root}/CodexMeter.app/Contents/Resources"
cp "${project_root}/Scripts/package_release.sh" \
  "${fixture_root}/Scripts/package_release.sh"
cp "${project_root}/Scripts/verify_license_notices.sh" "${fixture_root}/Scripts/"
for notice in LICENSE NOTICE; do
  cp "${project_root}/${notice}" "${fixture_root}/${notice}"
  cp "${project_root}/${notice}" "${fixture_root}/CodexMeter.app/Contents/Resources/${notice}.txt"
done
{
  print 'PRODUCT_NAME=CodexMeter'
  print 'MARKETING_VERSION=1.2.3'
} > "${fixture_root}/Config/Release.env"
{
  print '#!/bin/zsh'
  print 'set -euo pipefail'
  print 'destination=$2'
  print 'print "synthetic dmg" > "${destination}"'
} > "${fixture_root}/Scripts/make_dmg.sh"
chmod 755 "${fixture_root}/Scripts/package_release.sh" \
  "${fixture_root}/Scripts/make_dmg.sh"
print 'synthetic executable' \
  > "${fixture_root}/CodexMeter.app/Contents/MacOS/CodexMeter"

if [[ -e "${fixture_root}/Artifacts" ]]; then
  print -u2 'Fixture unexpectedly contains an Artifacts directory.'
  exit 1
fi

# A missing or modified notice must fail before any artifact is produced.
mv "${fixture_root}/CodexMeter.app/Contents/Resources/NOTICE.txt" "${fixture_root}/saved-NOTICE.txt"
if CODEXMETER_APP_PATH="${fixture_root}/CodexMeter.app" \
    "${fixture_root}/Scripts/package_release.sh" > "${fixture_root}/missing-notice.log" 2>&1; then
  print -u2 'Packaging accepted a missing Codenotch notice.'
  exit 1
fi
[[ ! -e "${fixture_root}/Artifacts" ]]
print 'Codenotch - MIT (truncated notice)' > "${fixture_root}/CodexMeter.app/Contents/Resources/NOTICE.txt"
if CODEXMETER_APP_PATH="${fixture_root}/CodexMeter.app" \
    "${fixture_root}/Scripts/package_release.sh" > "${fixture_root}/changed-notice.log" 2>&1; then
  print -u2 'Packaging accepted an incomplete Codenotch notice.'
  exit 1
fi
[[ ! -e "${fixture_root}/Artifacts" ]]
mv "${fixture_root}/saved-NOTICE.txt" "${fixture_root}/CodexMeter.app/Contents/Resources/NOTICE.txt"

CODEXMETER_APP_PATH="${fixture_root}/CodexMeter.app" \
  "${fixture_root}/Scripts/package_release.sh"

for expected in \
    CodexMeter-1.2.3.zip \
    CodexMeter-1.2.3.zip.sha256 \
    CodexMeter-1.2.3.dmg \
    CodexMeter-1.2.3.dmg.sha256 \
    SHA256SUMS.txt; do
  if [[ ! -f "${fixture_root}/Artifacts/${expected}" ]]; then
    print -u2 "Expected package output is missing: ${expected}"
    exit 1
  fi
done

(
  cd "${fixture_root}/Artifacts"
  shasum -a 256 -c CodexMeter-1.2.3.zip.sha256
  shasum -a 256 -c CodexMeter-1.2.3.dmg.sha256
  shasum -a 256 -c SHA256SUMS.txt
  grep ' CodexMeter-1.2.3.dmg$' SHA256SUMS.txt | shasum -a 256 -c -
)
ditto -x -k "${fixture_root}/Artifacts/CodexMeter-1.2.3.zip" "${fixture_root}/unzipped"
"${fixture_root}/Scripts/verify_license_notices.sh" "${fixture_root}/unzipped/CodexMeter.app"
print 'Package-release tests passed.'
