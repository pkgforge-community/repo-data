#!/usr/bin/env bash
## <DO NOT RUN STANDALONE, meant for CI Only>
## Meant to Sync all Repos (Releases) with About|Description: (AUTOSYNCED) 
## Requires: https://github.com/Azathothas/Arsenal/blob/main/misc/Linux/install_dev_tools.sh
# bash <(curl -qfsSL "https://pub.ajam.dev/repos/Azathothas/Arsenal/misc/Linux/install_dev_tools.sh")
## Self: https://raw.githubusercontent.com/pkgforge-community/repo-data/refs/heads/main/scripts/updater.sh
# bash <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge-community/repo-data/refs/heads/main/scripts/updater.sh")
## OPTS:
# CLEAN_RELEASES=1|ON updater --> Deletes pre-existing Releases
#-------------------------------------------------------#


#-------------------------------------------------------#
##ENV
export TZ="UTC"
SYSTMP="$(dirname $(mktemp -u))" && export SYSTMP="${SYSTMP}"
TMPDIR="$(mktemp -d)" && export TMPDIR="${TMPDIR}" ; echo -e "\n[+] Using TEMP: ${TMPDIR}\n"
export CLEAN_RELEASES
##Repos
 gh repo list "pkgforge-community" --limit 10000 --json "name,isFork,description,url,isArchived" -q '.[] | select(.isFork == true and .isArchived != true and (.description // "" | test("AUTOSYNCED"; "i"))) | .url' | sort -u | shuf -o "${TMPDIR}/FORKS.txt"
 if [[ ! -s "${TMPDIR}/FORKS.txt" || $(wc -l < "${TMPDIR}/FORKS.txt") -le 10 ]]; then
   echo -e "\n[✗] FATAL: Not Enough Repos... (Something went Wrong..?)\n"
  return 1 || exit 1
 fi
##Funcs
 source <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge-community/repo-data/refs/heads/main/scripts/updater.sh")
 if ! declare -F updater &>/dev/null && ! declare -F sync-repo-releases &>/dev/null; then
   echo -e "\n[✗] FATAL: updater could NOT BE Found\n"
  return 1 || exit 1
 fi
#-------------------------------------------------------#


#-------------------------------------------------------#
##Sync
pushd "${TMPDIR}" >/dev/null 2>&1
 readarray -t "FORKS" < "${TMPDIR}/FORKS.txt"
 #Enable Issues
 printf "%s\n" "${FORKS[@]}" | sed 's|https://github.com/||' | xargs -P "$(($(nproc)+1))" -I "{}" gh api "/repos/{}" -X "PATCH" --field "has_issues=true" >/dev/null
 #Sync Releases
 printf "%s\n" "${FORKS[@]}" | xargs -P "$(($(nproc)+1))" -I "{}" bash -c 'sync_repo "{}"'
#Exit
popd >/dev/null 2>&1
#-------------------------------------------------------#
