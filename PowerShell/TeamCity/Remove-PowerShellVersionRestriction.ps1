param(
    [string]
    $TeamCityUrl,

    [string]
    $UserName,

    [string]
    $Password
)

if ($TeamCityUrl -eq '' -or $UserName -eq '' -or $Password -eq '') {

    Write-Host ""
    Write-Host "    Removes the PowerShell version restriction from buildTypes."
    Write-Host "    A conflict error will be thrown in case the version restriction is inherited"
    Write-Host "    from a template, this has to be fixed manually!"
    Write-Host ""
    Write-Host "    Usage: .\Remove-PowerShellVersionRestriction.ps1 'http://some.teamcity.local' '<username>' '<password>'`n"
    Write-Host ""
    return
} 

$securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $securePassword

$buildTypes = Invoke-RestMethod -Uri "$($TeamCityUrl)/httpAuth/app/rest/buildTypes" -Credential $credentials
$buildTypeCount = $buildTypes.buildTypes.Count
$buildTypeIndex = 1

Write-Host "Checking $($buildTypeCount) build types..."

$buildTypes.buildTypes.buildType | %{

    $completed = [int] (($buildTypeIndex / $buildTypeCount) * 100)
    Write-Progress -Activity "Removing PowerShell version restriction..." -Status "Completed $($completed)%" -CurrentOperation "$($buildTypeIndex) of $($buildTypeCount) : $($_.href)" -PercentComplete $completed

    $buildTypeInfo = $_
    $buildTypeHref = $_.href
    $buildType = Invoke-RestMethod -Uri "$($TeamCityUrl)$($buildTypeHref)" -Credential $credentials;

    $buildType.buildType.steps.step | % {
        $step = $_
        $_.properties | % {
            $_.property | Where-Object { $_.name -eq 'jetbrains_powershell_minVersion' } | %{
                $stepHref = "$($TeamCityUrl)$($buildTypeHref)/steps/$($step.id)"
                # Build types based on template will generate a conflict -> Fix manually
                Write-Host $stepHref

                $buildStep = Invoke-RestMethod -Uri $stepHref -Credential $credentials
                $propToRemove = $buildStep.step.properties.property | Where-Object { $_.name -eq 'jetbrains_powershell_minVersion' }
                $buildStep.step.properties.RemoveChild( $propToRemove )

                Invoke-RestMethod -Uri $stepHref -Method Put -Body $buildStep -ContentType "application/xml" -Credential $credentials
            }
        }
    }

    $buildTypeIndex++
}

Write-Host "Done"