param(
    [Parameter(Mandatory)]
    [string] $Godot,
    [ValidateRange(1, 600)]
    [int] $Seconds = 120,
    [ValidatePattern('^[0-9]+x[0-9]+$')]
    [string] $Resolution = '1280x720',
    [switch] $NoShadows,
    [ValidatePattern('^[a-zA-Z0-9_-]+
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$engine = (Resolve-Path -LiteralPath $Godot).Path
$data = [IO.Path]::GetFullPath((Join-Path $project ".godot/benchmark-data/$CacheProfile"))
[IO.Directory]::CreateDirectory($data) | Out-Null
$benchmarkArgs = @("--seconds=$Seconds")
if ($NoShadows) { $benchmarkArgs += '--no-shadows' }
$previous = $env:APPDATA
try {
    $env:APPDATA = $data
    & $engine --path $project --resolution $Resolution --position 0,0 --script res://tools/benchmark.gd -- @benchmarkArgs
    $code = $LASTEXITCODE
} finally {
    $env:APPDATA = $previous
}
exit $code
)]
    [string] $CacheProfile = 'benchmark'
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$engine = (Resolve-Path -LiteralPath $Godot).Path
$cacheName = if ($FreshCache) { 'benchmark-' + [guid]::NewGuid().ToString('N') } else { 'benchmark' }
$data = [IO.Path]::GetFullPath((Join-Path $project ".godot/benchmark-data/$cacheName"))
[IO.Directory]::CreateDirectory($data) | Out-Null
$benchmarkArgs = @("--seconds=$Seconds")
if ($NoShadows) { $benchmarkArgs += '--no-shadows' }
$previous = $env:APPDATA
try {
    $env:APPDATA = $data
    & $engine --path $project --resolution $Resolution --position 0,0 --script res://tools/benchmark.gd -- @benchmarkArgs
    $code = $LASTEXITCODE
} finally {
    $env:APPDATA = $previous
}
exit $code
