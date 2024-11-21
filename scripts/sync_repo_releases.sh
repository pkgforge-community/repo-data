#!/usr/bin/env bash
## <DO NOT RUN STANDALONE, meant for CI Only>
## Meant to Sync all Repos (Releases) with About|Description: (AUTOSYNCED) 
## Requires: https://github.com/Azathothas/Arsenal/blob/main/misc/Linux/install_dev_tools.sh
# bash <(curl -qfsSL "https://pub.ajam.dev/repos/Azathothas/Arsenal/misc/Linux/install_dev_tools.sh")
## Self: https://raw.githubusercontent.com/pkgforge-community/repo-data/refs/heads/main/scripts/sync_repo_releases.sh
# bash <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge-community/repo-data/refs/heads/main/scripts/sync_repo_releases.sh")
## OPTS:
# CLEAN_RELEASES=1|ON sync_repo_releases --> Deletes pre-existing Releases
#-------------------------------------------------------#


#-------------------------------------------------------#
##ENV
export TZ="UTC"
SYSTMP="$(dirname $(mktemp -u))" && export SYSTMP="${SYSTMP}"
TMPDIR="$(mktemp -d)" && export TMPDIR="${TMPDIR}" ; echo -e "\n[+] Using TEMP: ${TMPDIR}\n"
export CLEAN_RELEASES
##Repos
 gh repo list "pkgforge-community" --limit 10000 --json "name,isFork,description,url" -q '.[] | select(.isFork == true and (.description // "" | test("AUTOSYNCED"; "i"))) | .url' | sort -u -o "${TMPDIR}/FORKS.txt"
 if [[ ! -s "${TMPDIR}/FORKS.txt" || $(wc -l < "${TMPDIR}/FORKS.txt") -le 10 ]]; then
   echo -e "\n[✗] FATAL: Not Enough Repos... (Something went Wrong..?)\n"
  exit 1
 fi
#-------------------------------------------------------#


#-------------------------------------------------------#
##Sync
pushd "${TMPDIR}" >/dev/null 2>&1
 readarray -t "FORKS" < "${TMPDIR}/FORKS.txt"
 sync_repo()
 {
  #Arg
  FORKED_REPO="${1:-$(echo "$@" | tr -d '[:space:]')}" ; export FORKED_REPO
  #Cleanup Releases
   if [ "${CLEAN_RELEASES}" = "1" ] || [ "${CLEAN_RELEASES}" = "ON" ]; then
      for E_RELEASE in $(gh release list --repo "${FORKED_REPO}" --json 'tagName' -q '.[].tagName'); do
       gh release delete "${E_RELEASE}" --repo "${FORKED_REPO}" --cleanup-tag --yes
     done
   fi
  #Get Source Repo
   SRC_REPO="$(gh repo view "${FORKED_REPO}" --json parent -q '.parent | "https://github.com/" + .owner.login + "/" + .name' | tr -d '[:space:]')"
   TMPSUFFIX="$(date --utc '+%H%M%S.%3N')"
   rm -rvf "${TMPDIR}/TAGS-${TMPSUFFIX}.txt" 2>/dev/null
   gh release list --repo "${SRC_REPO}" --limit 5 --json 'tagName' -q '.[].tagName' | sort -u -o "${TMPDIR}/TAGS-${TMPSUFFIX}.txt"
   if [[ -s "${TMPDIR}/TAGS-${TMPSUFFIX}.txt" && $(wc -l < "${TMPDIR}/TAGS-${TMPSUFFIX}.txt") -gt 1 ]]; then
     readarray -t "SRC_TAGS" < "${TMPDIR}/TAGS-${TMPSUFFIX}.txt"
       for SRC_TAG in "${SRC_TAGS[@]}"; do
        unset SRC_JSON SRC_RELEASE_NAME SRC_RELEASE_BODY SRC_TAG_SNAP
        if gh release list --repo "${FORKED_REPO}" --json 'tagName' -q ".[].tagName" | grep -q "${SRC_TAG}"; then
         echo -e "[+] Skipping ${SRC_TAG} --> ${FORKED_REPO} (Already Exists)"
        else
        #Fetch Release Info
         SRC_JSON="$(gh release view "${SRC_TAG}" --repo "${SRC_REPO}" --json 'tagName,body,name')"
         if [ -z "${SRC_JSON}" ]; then
           echo -e "[+] Skipping ${SRC_TAG} <-- ${SRC_REPO}"
           return 1 || exit 1
         else
          #Create Release Name & Body
           SRC_RELEASE_NAME="$(echo "${SRC_JSON}" | jq -r '.name')"
           SRC_RELEASE_BODY="$(echo "${SRC_JSON}" | jq -r '.body')"
          #Create src release
           echo "[+] Creating Release "${SRC_TAG}" --> ${FORKED_REPO}"
           gh release create "${SRC_TAG}" --repo "${FORKED_REPO}" --title "${SRC_RELEASE_NAME}" --notes "${SRC_RELEASE_BODY}"
          #Create src snap release 
           SRC_TAG_SNAP="${SRC_TAG}-$(date --utc "+%Y%m%dT%H%M%S")"
           echo "[+] Creating Release "${SRC_TAG}" --> ${FORKED_REPO}"
           gh release create "${SRC_TAG_SNAP}" --repo "${FORKED_REPO}" --title "${SRC_RELEASE_NAME}" --notes "${SRC_RELEASE_BODY}"
          #Upload to created Release 
           if gh release list --repo "${FORKED_REPO}" --json 'tagName' -q ".[].tagName" | grep -q "${SRC_TAG_SNAP}"; then
            #Upload Release
             rm -rvf "${TMPDIR}/ASSETS-${TMPSUFFIX}.txt" 2>/dev/null
             gh release view "${SRC_TAG}" --repo "${SRC_REPO}" --json 'assets' --jq '.assets[].url' | sort -u -o "${TMPDIR}/ASSETS-${TMPSUFFIX}.txt"
             readarray -t "SRC_ASSETS" < "${TMPDIR}/ASSETS-${TMPSUFFIX}.txt"
             OUTDIR="${TMPDIR}/$(date --utc '+%H%M%S.%3N')" ; export OUTDIR
             mkdir -pv "${OUTDIR}" ; pushd "${OUTDIR}" >/dev/null 2>&1
              #Download
               printf "%s\n" "${SRC_ASSETS[@]}" | xargs -P "$(($(nproc)+1))" -I '{}' curl -qfSLO '{}' ; ls -lah "${OUTDIR}"
              #Upload (Src)
               find "." -type f -size +3c -print0 | xargs -0 -P "$(($(nproc)+1))" -I '{}' gh release upload "${SRC_TAG}" --repo "${FORKED_REPO}" '{}'
              #Upload (Snapshot) 
               find "." -type f -size +3c -print0 | xargs -0 -P "$(($(nproc)+1))" -I '{}' gh release upload "${SRC_TAG_SNAP}" --repo "${FORKED_REPO}" '{}'
             popd >/dev/null 2>&1 ; rm -rvf "${OUTDIR}" 2>/dev/null
           fi
         fi
        fi
       done
   else
     echo -e "[+] Skipping ${SRC_REPO} (No Release Tag)..."
   fi
 }
export -f sync_repo
printf "%s\n" "${FORKS[@]}" | xargs -P "$(($(nproc)+1))" -I "{}" bash -c 'sync_repo "{}"'
#Exit
popd >/dev/null 2>&1
#-------------------------------------------------------#
