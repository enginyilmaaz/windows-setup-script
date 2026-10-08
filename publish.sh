#!/usr/bin/env bash
# Sync README.md + windows-setup.ps1 into the public Gist that https://bit.ly/... resolves to.
# Uses the logged-in `gh` account (needs the `gist` scope).
#
#   ./publish.sh              # sanity-check, then update the gist
#   ./publish.sh --check-only # only syntax-check, touch no network
#   ./publish.sh --diff       # show what the gist currently differs by, change nothing
#
# The gist is the artefact users actually run, so it must never drift from the repo.
# The payload is sent through `jq --rawfile`, which keeps the files byte-exact UTF-8 —
# publishing by hand from PowerShell has mangled the README's emoji into "??" before.
set -euo pipefail
cd "$(dirname "$0")"

GIST_ID="5dc585f42032cc2d2736433590555484"
DESC="Windows Post-Installation Setup Script — irm https://bit.ly/windows-ey | iex"
FILES=(README.md windows-setup.ps1)

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -Command '$e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path ./windows-setup.ps1),[ref]$null,[ref]$e); if($e){$e|%{$_.Message}; exit 1} else {"windows-setup.ps1: syntax ok"}'
else
  echo "windows-setup.ps1: (pwsh not present — skipped syntax check)"
fi
[ "${1:-}" = "--check-only" ] && exit 0

# Publish what is committed, never the working tree: uncommitted edits must not reach
# users, and on Windows the checkout is CRLF (core.autocrlf) while the gist is LF.
if [ "${1:-}" != "--diff" ] && ! git diff --quiet HEAD -- "${FILES[@]}"; then
  echo "uncommitted changes in ${FILES[*]} — commit them first, then publish."
  exit 1
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for f in "${FILES[@]}"; do git show "HEAD:$f" > "$tmp/$f"; done

# The gist is the source users curl; refuse to overwrite a copy that is AHEAD of the
# repo (someone published a fix straight to the gist without committing it).
remote_newer=0
for f in "${FILES[@]}"; do
  # Normalise CRLF and the trailing newline the gist API appends, so only real
  # content differences are reported. No leading slash on the endpoint: Git Bash
  # rewrites "/gists/..." into a Windows path, and a failed fetch must stop the run
  # instead of passing for "no difference".
  gh api "gists/$GIST_ID" --jq ".files[\"$f\"].content" | sed 's/\r$//' > "$tmp/gist-$f"
  if ! diff -q <(sed -e :a -e '/^\n*$/{$d;N;};/\n$/ba' "$tmp/gist-$f") \
                <(sed -e :a -e '/^\n*$/{$d;N;};/\n$/ba' "$tmp/$f") >/dev/null 2>&1; then
    echo "differs from the gist: $f"
    # diff exits 1 on a difference; keep that from tripping `set -e` before the next file.
    [ "${1:-}" = "--diff" ] && { diff -u "$tmp/$f" "$tmp/gist-$f" || true; } | head -60
    remote_newer=1
  fi
done
[ "${1:-}" = "--diff" ] && exit 0
[ "$remote_newer" = 0 ] && { echo "gist already matches the repo — nothing to do."; exit 0; }

echo
read -r -p "Overwrite the gist with the repo's copy? [y/N] " ans
case "$ans" in y|Y|yes|YES|Yes) ;; *) echo "aborted — the gist was not touched."; exit 1 ;; esac

jq -n --arg d "$DESC" --rawfile r "$tmp/README.md" --rawfile s "$tmp/windows-setup.ps1" \
   '{description:$d, files:{"README.md":{content:$r},"windows-setup.ps1":{content:$s}}}' \
  | gh api -X PATCH "gists/$GIST_ID" --input - >/dev/null
echo "gist updated: https://gist.github.com/enginyilmaaz/$GIST_ID"
