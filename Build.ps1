param([switch]$appVeyor=$false)

function Confirm-AdministratorContext
{
    $administrator = [Security.Principal.WindowsBuiltInRole] "Administrator"
    $identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $identity.IsInRole($administrator)
}

function Use-AdministratorContext
{
    if (-not (Confirm-AdministratorContext))
    {
        $arguments = "& '" + $myinvocation.mycommand.definition + "'"
        Start-Process powershell -Verb runAs -ArgumentList $arguments
        Break
    }
}

function Install-BuildPrerequisite()
{
    foreach ($arg in $args)
    {
        if (-not (Get-Module -Name $arg))
        {
            Use-AdministratorContext
            Get-Module -Name $arg -Force -SkipPublisherCheck
        }
    }
}

function Invoke-StaticAnalysis
{
    $result = Invoke-ScriptAnalyzer -Path "." -Recurse
    $result
    if ($result.Length -gt 0)
    {
        Stop-Build "Found $($result.Length) static analysis issues"
    }
    else
    {
        Write-Output "Static analysis finding clean"
    }
}
function Invoke-Build
{
    if ($appVeyor)
    {
        Write-Output "Running build in AppVeyor build server context"
    }
    else
    {
        Write-Output "Running build in developer context"
    }
    Write-Output "Checking static analysis findings"
    Invoke-StaticAnalysis
    Write-Output "Running tests"
    Invoke-Test
    Write-Output "Build finished"
}

function Send-TestResult([string]$resultsPath)
{
    $url = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
    (New-Object 'System.Net.WebClient').UploadFile($url, (Resolve-Path $resultsPath))
}
function Invoke-Test
{
    $resultsPath = ".\TestResults.xml"
    Invoke-Pester -EnableExit -OutputFormat NUnitXml -OutputFile $resultsPath
    if ($appVeyor)
    {
        Send-TestResult $resultsPath
    }
}

Invoke-Build