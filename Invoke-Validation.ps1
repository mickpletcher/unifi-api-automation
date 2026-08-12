[CmdletBinding()]
param(
    [switch]$CI,

    [switch]$Integration
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = $PSScriptRoot
$settingsPath = Join-Path $repositoryRoot 'PSScriptAnalyzerSettings.psd1'
$analysisPaths = @(
    (Join-Path $repositoryRoot 'UnifiOps.ps1')
    (Join-Path $repositoryRoot 'UnifiOps')
    (Join-Path $repositoryRoot 'Invoke-Validation.ps1')
)

foreach ($requiredModule in 'PSScriptAnalyzer', 'Pester') {
    if (-not (Get-Module -ListAvailable -Name $requiredModule)) {
        throw "$requiredModule is required. Install the pinned version documented in CONTRIBUTING.md."
    }
}

$findings = @(
    foreach ($path in $analysisPaths) {
        Invoke-ScriptAnalyzer -Path $path -Recurse -Settings $settingsPath
    }
)

if ($findings.Count -gt 0) {
    $findings | Format-Table RuleName, Severity, ScriptName, Line, Message -AutoSize
    throw "PSScriptAnalyzer reported $($findings.Count) finding(s)."
}

$configuration = New-PesterConfiguration
$configuration.Run.Path = Join-Path $repositoryRoot 'tests'
$configuration.Run.PassThru = $true
$configuration.Filter.ExcludeTag = if ($Integration) { @() } else { @('Integration') }
$configuration.Output.Verbosity = if ($CI) { 'Normal' } else { 'Detailed' }
$configuration.TestResult.Enabled = [bool]$CI
$configuration.TestResult.OutputPath = Join-Path $repositoryRoot 'TestResults.xml'
$configuration.TestResult.OutputFormat = 'NUnitXml'
$configuration.CodeCoverage.Enabled = $true
$configuration.CodeCoverage.Path = @(
    (Join-Path $repositoryRoot 'UnifiOps.ps1')
    (Join-Path $repositoryRoot 'UnifiOps/UnifiOps.Functions.ps1')
    (Join-Path $repositoryRoot 'UnifiOps/UnifiOps.psm1')
)
$configuration.CodeCoverage.OutputPath = Join-Path $repositoryRoot 'coverage.xml'
$configuration.CodeCoverage.OutputFormat = 'JaCoCo'
$configuration.CodeCoverage.CoveragePercentTarget = 80

$result = Invoke-Pester -Configuration $configuration
if ($result.FailedCount -gt 0) {
    throw "Pester reported $($result.FailedCount) failed test(s)."
}

[pscustomobject]@{
    AnalyzerFindings = $findings.Count
    TestsPassed      = $result.PassedCount
    TestsFailed      = $result.FailedCount
    TestsSkipped     = $result.SkippedCount
}
