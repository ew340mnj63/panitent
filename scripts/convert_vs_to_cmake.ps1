param(
    [Parameter(Mandatory=$true)][string]$Solution
)

$root = Split-Path $Solution -Parent
$solName = [IO.Path]::GetFileNameWithoutExtension($Solution)
$rootCmake = Join-Path $root 'CMakeLists.txt'

@("cmake_minimum_required(VERSION 3.10)", "project($solName)", "") | Set-Content $rootCmake

Get-Content $Solution | Where-Object { $_ -match '^Project\("' } | ForEach-Object {
    $parts = $_ -split '"'
    $name = $parts[3]
    $path = $parts[5]
    $projFile = Join-Path $root $path
    if (-not (Test-Path $projFile)) { return }

    $projDir = Split-Path $path
    $configType = (Select-String -Path $projFile -Pattern '<ConfigurationType>([^<]+)</ConfigurationType>' -List | Select-Object -First 1).Matches[0].Groups[1].Value
    $sources = Select-String -Path $projFile -Pattern '<ClCompile Include="([^"]+)' | ForEach-Object { $_.Matches[0].Groups[1].Value.Replace('\\','/') }

    if ($configType -eq 'StaticLibrary') {
        $libCmake = Join-Path $root $projDir 'CMakeLists.txt'
        "add_library($name STATIC" | Set-Content $libCmake
        $sources | ForEach-Object { "    $_" | Add-Content $libCmake }
        ")" | Add-Content $libCmake
        if ($projDir -ne '') { "add_subdirectory($projDir)" | Add-Content $rootCmake }
    }
    else {
        if ($projDir -ne '') { $sources = $sources | ForEach-Object { "$projDir/$_" } }
        "add_executable($name" | Add-Content $rootCmake
        $sources | ForEach-Object { "    $_" | Add-Content $rootCmake }
        ")" | Add-Content $rootCmake
    }
}
