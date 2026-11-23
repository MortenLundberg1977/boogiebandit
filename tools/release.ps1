# Builds the game and publishes it as a GitHub release for the version in
# version.asm (tag v<version>), with the disk image, the tape image and the
# program attached, so they can be downloaded from the repository's
# Releases page. Run on main after the version's commit is pushed:
#   powershell -ExecutionPolicy Bypass -File tools\release.ps1
# An existing release for that version gets the new files (replaced).
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
[Environment]::CurrentDirectory = $root

$m = Select-String -Path version.asm -Pattern '\.var VERSION = "([0-9.]+)"'
if (-not $m) { throw "No VERSION in version.asm" }
$version = $m.Matches[0].Groups[1].Value
$tag = "v$version"

cmd /c "`"$root\build.bat`" nosend"
if ($LASTEXITCODE -ne 0) { throw "The build failed" }

$files = @("build\boogiebandit.d64", "build\boogie.prg", "build\boogie-reu.prg")
foreach ($f in $files) { if (-not (Test-Path $f)) { throw "Missing $f" } }

git rev-parse -q --verify "refs/tags/$tag" | Out-Null
if ($LASTEXITCODE -ne 0) {
    git tag $tag
    git push origin $tag
}

$existing = @(gh release list --limit 200 --json tagName -q ".[].tagName")
if ($existing -contains $tag) {
    gh release upload $tag @files --clobber
} else {
    $notes = "Boogie Bandit $version for the Commodore 64 (PAL).`n`n" +
             "- boogiebandit.d64: disk image (LOAD`"BOOGIE`",8 then RUN; or open it in VICE)`n" +
             "- boogie.prg: the program on its own (Kung Fu Flash, SD card loaders, emulators)`n" +
             "- boogie-reu.prg: the REU edition (needs an REU for its extras, e.g. the newspaper when you are busted; also on the d64 as BOOGIE REU)"
    gh release create $tag @files --title "Boogie Bandit $version" --notes $notes --latest
}
if ($LASTEXITCODE -ne 0) { throw "gh failed" }
Write-Output "Released $tag"
