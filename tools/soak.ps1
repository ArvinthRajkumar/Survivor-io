# Headless balance soak for Last Light: Swarmfall.
#
# Runs the automated pilot across hero/sector/seed combinations and prints one
# line per run plus a win-rate summary. Because a single run is dominated by RNG,
# always compare distributions rather than one result before retuning.
#
#   pwsh tools/soak.ps1                                   # every hero on sector 1
#   pwsh tools/soak.ps1 -Levels ash_wastes -Seeds 3       # one sector, 3 seeds
#   pwsh tools/soak.ps1 -Heroes nova -Levels all -Seeds 3
#
# Requires a Godot 4.x binary; set -Godot or drop it in tools/.

param(
    [string]   $Godot  = "",
    [string]   $Project = "",
    [string[]] $Heroes = @("nova"),
    [string[]] $Levels = @("neon_ruins"),
    [int]      $Seeds  = 1
)

# Godot writes warnings to stderr; PowerShell would otherwise treat those as
# terminating errors and abort the sweep.
$ErrorActionPreference = "Continue"

$AllHeroes = @("nova", "bramble", "rift", "aegis", "ember")
$AllLevels = @("neon_ruins", "ash_wastes", "flooded_vault", "moonfall_ridge")

# Invoked through `powershell -File`, a comma-separated list arrives as one
# string, so split it back out before matching.
$Heroes = $Heroes -split "," | Where-Object { $_ -ne "" }
$Levels = $Levels -split "," | Where-Object { $_ -ne "" }
if ($Heroes -contains "all") { $Heroes = $AllHeroes }
if ($Levels -contains "all") { $Levels = $AllLevels }

if ([string]::IsNullOrEmpty($Project)) {
    $Project = Split-Path -Parent $PSScriptRoot
}
if ([string]::IsNullOrEmpty($Godot)) {
    $candidate = Get-ChildItem -Path $PSScriptRoot -Filter "Godot_v4*console.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $candidate) {
        $candidate = Get-ChildItem -Path $PSScriptRoot -Filter "Godot_v4*.exe" -ErrorAction SilentlyContinue |
            Select-Object -First 1
    }
    if ($null -eq $candidate) {
        throw "No Godot binary found in $PSScriptRoot. Pass -Godot <path>."
    }
    $Godot = $candidate.FullName
}

# Long enough for the longest sector (13 min) at a fixed 60 fps step.
$Frames = 55000

$results = @()
foreach ($hero in $Heroes) {
    foreach ($level in $Levels) {
        for ($i = 0; $i -lt $Seeds; $i++) {
            $seed = 20260907 + ($i * 7919)
            $line = & $Godot --headless --path $Project --fixed-fps 60 --quit-after $Frames -- `
                --smoke "--hero=$hero" "--level=$level" "--seed=$seed" 2>&1 |
                Select-String -Pattern "\[smoke\]" | Select-Object -First 1
            if ($null -eq $line) { $line = "(no result - run crashed or timed out)" }
            $text = "$line"
            $win = $text -match "VICTORY"
            $results += [pscustomobject]@{
                Hero = $hero; Level = $level; Seed = $seed; Win = $win; Line = $text
            }
            $tag = if ($win) { "WIN " } else { "LOSS" }
            "{0,-8} {1,-15} seed {2,-10} {3}  {4}" -f $hero, $level, $seed, $tag, ($text -replace "\[smoke\] ", "")
        }
    }
}

""
"--- summary ---"
foreach ($group in $results | Group-Object Level) {
    $wins = ($group.Group | Where-Object { $_.Win }).Count
    "{0,-15} {1}/{2} wins" -f $group.Name, $wins, $group.Count
}
