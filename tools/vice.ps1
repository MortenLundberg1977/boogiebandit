# Runs a program in VICE and drives it through the remote monitor.
# Usage: powershell -File tools\vice.ps1 build\souldrive.prg "wait 3; shot build\a.png; poke 0300 01; wait 2; peek 0300 10; quit"
# Commands (separated by ;):
#   wait <seconds>        let the emulator run
#   shot <file.png>       screenshot
#   poke <hex> <hex..>    write bytes (address and values in hex)
#   peek <hex> [count]    print bytes
#   mon <text>            any VICE monitor command, then continue
#   raw <text>            any VICE monitor command, stay stopped ("raw x" continues)
#                         (in mon and raw, ^ stands for a double quote: attach ^file.tap^ 1)
#   quit                  close VICE
param([Parameter(Mandatory)][string]$Prg, [string]$Script = "wait 3; shot build\shot.png; quit", [switch]$Warp, [string]$Extra = "")

$ErrorActionPreference = "Stop"
$vice = (Get-Command x64sc).Source
$port = 6510
$viceArgs = @("-default", "-remotemonitor", "-remotemonitoraddress", "ip4://127.0.0.1:$port",
              "-autostartprgmode", "1", "+confirmonexit", "-sound",
              "+drive8truedrive", "-trapdevice8", "-autostart-warp")
if ($Warp) { $viceArgs += "-warp" }
$viceArgs += @($Extra -split " " | Where-Object { $_ })   # e.g. -Extra "-8 build\boogiebandit.d64 -1 build\test.tap"
$viceArgs += (Resolve-Path $Prg).Path
$proc = Start-Process -FilePath $vice -ArgumentList $viceArgs -PassThru

$client = $null
for ($i = 0; $i -lt 50 -and -not $client; $i++) {
    Start-Sleep -Milliseconds 200
    try { $client = New-Object System.Net.Sockets.TcpClient("127.0.0.1", $port) } catch { $client = $null }
}
if (-not $client) { throw "Could not connect to the VICE monitor" }
$stream = $client.GetStream()
$writer = New-Object System.IO.StreamWriter($stream); $writer.AutoFlush = $true
$buf = New-Object byte[] 65536

function Read-Monitor([int]$ms = 400) {
    $sb = New-Object System.Text.StringBuilder
    $deadline = (Get-Date).AddMilliseconds($ms)
    while ((Get-Date) -lt $deadline) {
        if ($stream.DataAvailable) {
            $n = $stream.Read($buf, 0, $buf.Length)
            [void]$sb.Append([System.Text.Encoding]::ASCII.GetString($buf, 0, $n))
            $deadline = (Get-Date).AddMilliseconds(150)
        } else { Start-Sleep -Milliseconds 20 }
    }
    $sb.ToString()
}
function Mon([string]$cmd) {
    $writer.WriteLine($cmd)
    $out = Read-Monitor
    $writer.WriteLine("x")
    [void](Read-Monitor 100)
    $out
}

foreach ($raw in ($Script -split ";")) {
    $c = $raw.Trim(); if (-not $c) { continue }
    $parts = $c -split "\s+"
    switch ($parts[0]) {
        "wait" { Start-Sleep -Milliseconds ([double]$parts[1] * 1000) }
        "shot" { $f = [System.IO.Path]::GetFullPath($parts[1]); [void](Mon "screenshot `"$f`" 2"); Write-Output "shot $f" }
        "poke" { [void](Mon ("> " + $parts[1] + " " + ($parts[2..($parts.Length-1)] -join " "))) }
        "peek" { $n = if ($parts.Length -gt 2) { [Convert]::ToInt32($parts[2], 16) } else { 16 }
                 $a = [Convert]::ToInt32($parts[1], 16)
                 Write-Output (Mon ("m {0:x4} {1:x4}" -f $a, ($a + $n - 1))) }
        "mon"  { Write-Output (Mon ($c.Substring(4).Replace("^", [string][char]34))) }
        "raw"  { $writer.WriteLine($c.Substring(4).Replace("^", [string][char]34)); Write-Output (Read-Monitor) }   # stays in the monitor
        "quit" { $writer.WriteLine("quit"); Start-Sleep -Milliseconds 300 }
    }
}
$client.Close()
if (-not $proc.HasExited) { Start-Sleep -Milliseconds 500; if (-not $proc.HasExited) { $proc.Kill() } }
