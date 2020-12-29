Write-Output "--- system details"
$Properties = 'Caption', 'CSName', 'Version', 'BuildType', 'OSArchitecture'
Get-CimInstance Win32_OperatingSystem | Select-Object $Properties | Format-Table -AutoSize

# chocolatey functional tests fail so delete the chocolatey binary to avoid triggering them
Remove-Item -Path C:\ProgramData\chocolatey\bin\choco.exe -ErrorAction SilentlyContinue

$ErrorActionPreference = 'Stop'

Write-Output "--- Enable Ruby 2.7"
Write-Output "Add Uru to Environment PATH"
$env:PATH = "C:\Program Files (x86)\Uru;" + $env:PATH
[Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine)

Write-Output "Register Installed Ruby Version 2.7 With Uru"
Start-Process "C:\Program Files (x86)\Uru\uru_rt.exe" -ArgumentList 'admin add C:\ruby27\bin' -Wait
uru 271
if (-not $?) { throw "Can't Activate Ruby. Did Uru Registration Succeed?" }

Write-Output "--- configure winrm"

winrm quickconfig -q

Write-Output "--- update bundler"

ruby -v
if (-not $?) { throw "Can't run Ruby. Is it installed?" }

$env:BUNDLER_VERSION=$(findstr bundler omnibus_overrides.rb | %{ $_.split(" ")[3] })
$env:BUNDLER_VERSION=($env:BUNDLER_VERSION -replace '"', "")
Write-Output $env:BUNDLER_VERSION

gem install bundler -v $env:BUNDLER_VERSION --force --no-document --quiet
if (-not $?) { throw "Unable to update Bundler" }
bundle --version

Write-Output "--- bundle install"
bundle install --jobs=3 --retry=3 --without omnibus_package
if (-not $?) { throw "Unable to install gem dependencies" }

Write-Output "+++ bundle exec rake spec:functional"
bundle exec rake spec:functional
if (-not $?) { throw "Chef functional specs failing." }
