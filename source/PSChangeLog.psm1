$script:resourceHelperModulePath = Join-Path -Path $PSScriptRoot -ChildPath '.\Modules\DscResource.Common'

Import-Module -Name $script:resourceHelperModulePath

$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'

$NL = [System.Environment]::NewLine

<#
    .SYNOPSIS
        Takes a changelog in Keep a Changelog 1.0.0 format and parses the data
        into a PowerShell object.

    .DESCRIPTION
        This cmdlet parses the data in a changelog file using Keep a Changelog
        1.0.0 format into a PowerShell object.

    .PARAMETER Path
        Full path to the file CHANGELOG.md. Defaults to 'CHANGELOG.md'.

    .INPUTS
        This cmdlet does not accept pipeline input.

    .OUTPUTS
        This cmdlet outputs a PSCustomObject containing the changelog data.

    .EXAMPLE
        Get-ChangelogData
        Returns an object containing Header, Unreleased, Released, Footer,
        and LastVersion properties.

    .EXAMPLE
        Get-ChangelogData -Path '/source/CHANGELOG.md'
        Returns an object containing Header, Unreleased, Released, Footer,
        and LastVersion properties from the file located at the path
        '/source/CHANGELOG.md'.

    .NOTES
        This function is based on the function in the repository
        https://github.com/natescherer/ChangelogManagement

    .LINK
        https://github.com/johlju/PSChangeLog
#>
function Get-ChangelogData
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param
    (
        [Parameter()]
        [ValidateScript( { Test-Path -Path $_ })]
        [System.String]
        $Path = 'CHANGELOG.md'
    )

    $ChangeTypes = @('Added', 'Changed', 'Deprecated', 'Removed', 'Fixed', 'Security')
    $ChangelogData = Get-Content -Path $Path -Raw

    $Output = [PSCustomObject] @{
        Header      = ''
        Unreleased  = [PSCustomObject] @{ }
        Released    = @()
        Footer      = ''
        LastVersion = ''
    }

    # Split changelog into $Sections and split header and footer into their own variables
    [System.Collections.ArrayList]$Sections = $ChangelogData -split '## \['
    $Output.Header = $Sections[0]
    $Sections.Remove($Output.Header)
    if ($Sections[-1] -match '.*\[Unreleased\]:.*')
    {
        $Output.Footer = '[Unreleased]:' + ($Sections[-1] -split '\[Unreleased\]:')[1]
        $Sections[-1] = ($Sections[-1] -split '\[Unreleased\]:')[0]
    }

    <#
        Restore the leading '## [' onto each section that was previously removed
        by split function, and trim extra line breaks
    #>
    $i = 1
    while ($i -le $Sections.Count)
    {
        $Sections[$i - 1] = '## [' + $Sections[$i - 1]
        $i++
    }

    <#
        If found, split the Unreleased section into $UnreleasedTemp, then remove
        it from $Sections.
    #>
    if ($Sections[0] -match '## \[Unreleased\].*')
    {
        $UnreleasedTemp = $Sections[0]
        $Sections.Remove($UnreleasedTemp)
    }
    else
    {
        $UnreleasedTemp = ''
    }

    # Construct the $Output.Unreleased object
    foreach ($ChangeType in $ChangeTypes)
    {
        if ($UnreleasedTemp -notlike "*### $ChangeType*")
        {
            Set-Variable -Name "Unreleased$ChangeType" -Value $null
        }
        else
        {
            $Value = (($UnreleasedTemp -split "### $ChangeType$NL")[1] -split '###')[0].TrimEnd($NL) -split $NL | ForEach-Object { $_.TrimStart('- ') }
            Set-Variable -Name "Unreleased$ChangeType" -Value $Value
        }
    }

    $Output.Unreleased = [PSCustomObject] @{
        RawData = $UnreleasedTemp
        Link    = (($Output.Footer -split 'Unreleased\]: ')[1] -split $NL)[0]
        Data    = [PSCustomObject] @{
            Added      = $UnreleasedAdded
            Changed    = $UnreleasedChanged
            Deprecated = $UnreleasedDeprecated
            Removed    = $UnreleasedRemoved
            Fixed      = $UnreleasedFixed
            Security   = $UnreleasedSecurity
        }
    }

    # Construct the $Output.Released array
    foreach ($Release in $Sections)
    {
        foreach ($ChangeType in $ChangeTypes)
        {
            if ($Release -notlike "*### $ChangeType*")
            {
                Set-Variable -Name "Release$ChangeType" -Value $null
            }
            else
            {
                $Value = (($Release -split "### $ChangeType$NL")[1] -split '###')[0].TrimEnd($NL) -split $NL | ForEach-Object { $_.TrimStart('- ') }
                Set-Variable -Name "Release$ChangeType" -Value $Value
            }
        }

        $LoopVersionNumber = $Release.Split('[')[1].Split(']')[0]
        $Output.Released += [PSCustomObject]@{
            RawData = $Release
            Date    = Get-Date ($Release -split '\] \- ')[1].Split($NL)[0]
            Version = $LoopVersionNumber
            Link    = (($Output.Footer -split "$LoopVersionNumber\]: ")[1] -split $NL)[0]
            Data    = [PSCustomObject]@{
                Added      = $ReleaseAdded
                Changed    = $ReleaseChanged
                Deprecated = $ReleaseDeprecated
                Removed    = $ReleaseRemoved
                Fixed      = $ReleaseFixed
                Security   = $ReleaseSecurity
            }
        }
    }

    <#
        Set $Output.LastVersion to the version number of the latest release listed
        in the changelog, or null if there have not been any releases yet.
    #>
    if ($Output.Released[0].Version)
    {
        $Output.LastVersion = $Output.Released[0].Version
    }
    else
    {
        $Output.LastVersion = $null
    }

    $Output
}

<#
    .SYNOPSIS
        Adds an item to a changelog file in Keep a Changelog 1.0.0 format.

    .DESCRIPTION
        This cmdlet adds new Added/Changed/Deprecated/Removed/Fixed/Security items
        to the Unreleased section of a changelog in Keep a Changelog 1.0.0 format.

    .PARAMETER Path
        Full path to the file CHANGELOG.md. Defaults to 'CHANGELOG.md'.

    .PARAMETER OutputPath
        The path to the output file. Defaults to the same path as parameter Path.

    .PARAMETER Type
        The type of change for the entry to be added. Must be set to either 'Added',
        'Changed', 'Deprecated', 'Removed', 'Fixed', or 'Security'.

    .PARAMETER Data
        The value string of the entry to add to the change log.

    .INPUTS
        This cmdlet does not accept pipeline input.

    .OUTPUTS
        This cmdlet does not generate output.

    .EXAMPLE
        Add-ChangelogData -Type 'Added' -Data 'Spanish language translation'
        Does not generate output, but adds a new Added change into changelog at
        .\CHANGELOG.md.

    .EXAMPLE
        Add-ChangelogData -Type 'Removed' -Data 'TLS 1.0 support' -Path project\CHANGELOG.md
        Does not generate output, but adds a new Security change into changelog
        at project\CHANGELOG.md.

    .NOTES
        This function is based on the function in the repository
        https://github.com/natescherer/ChangelogManagement

    .LINK
        https://github.com/johlju/PSChangeLog
#>
function Add-ChangelogData
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateScript( { Test-Path -Path $_ })]
        [System.String]
        $Path = 'CHANGELOG.md',

        [Parameter()]
        [ValidatePattern('.*\.md')]
        [System.String]
        $OutputPath = $Path,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Added', 'Changed', 'Deprecated', 'Removed', 'Fixed', 'Security')]
        [System.String]
        $Type,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Data
    )

    $ChangeTypes = @('Added', 'Changed', 'Deprecated', 'Removed', 'Fixed', 'Security')
    $ChangelogData = Get-ChangelogData -Path $Path

    $Output = ''
    $Output += $ChangelogData.Header
    $Output += "## [Unreleased]$NL"
    foreach ($ChangeType in $ChangeTypes)
    {
        $ChangeMade = $false
        if ($Type -eq $ChangeType)
        {
            $Output += "### $ChangeType$NL"
            $Output += "- $Data$NL"
            $ChangeMade = $true
        }
        if ($ChangelogData.Unreleased.Data.$ChangeType)
        {
            if ($Output -notlike "*### $ChangeType*")
            {
                $Output += "### $ChangeType$NL"
            }
            foreach ($Datum in $ChangelogData.Unreleased.Data.$ChangeType)
            {
                $Output += "- $Datum$NL"
                $ChangeMade = $true
            }
        }
        if ($ChangeMade)
        {
            $Output += $NL
        }
    }
    foreach ($Release in $ChangelogData.Released)
    {
        $Output += $Release.RawData
    }
    $Output += $ChangelogData.Footer

    Set-Content -Value $Output -Path $OutputPath -NoNewline
}

<#
    .SYNOPSIS
        Creates a new, blank changelog in Keep a Changelog 1.0.0 format.

    .DESCRIPTION
        This cmdlet creates a new, blank changelog in Keep a Changelog 1.0.0 format.

    .PARAMETER Path
        Full path to the output file. Defaults to 'CHANGELOG.md'.

    .PARAMETER NoSemVer
        If the statement about semantic versioning should be excluded from the
        changelog.

    .INPUTS
        This cmdlet does not accept pipeline input.

    .OUTPUTS
        This cmdlet does not generate output.

    .EXAMPLE
        New-Changelog
        Does not generate output, but creates a new changelog at .\CHANGELOG.md

    .EXAMPLE
        New-Changelog -Path project\CHANGELOG.md -NoSemVer
        Does not generate output, but creates a new changelog at project\CHANGELOG.md
        while excluding SemVer statement from the header

    .NOTES
        This function is based on the function in the repository
        https://github.com/natescherer/ChangelogManagement

    .LINK
        https://github.com/johlju/PSChangeLog
#>
function New-Changelog
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path = 'CHANGELOG.md',

        [Parameter()]
        #
        [System.Management.Automation.SwitchParameter]
        $NoSemVer
    )

    $Output = ''

    $Output += "# Changelog$NL"
    $Output += "All notable changes to this project will be documented in this file.$NL$NL"
    $Output += 'The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)'
    if ($NoSemVer -eq $false)
    {
        $Output += ",$NL"
        $Output += 'and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)'
    }
    $Output += ".$NL$NL"
    $Output += "## [Unreleased]$NL"

    Set-Content -Value $Output -Path $Path -NoNewline
}

<#
    .SYNOPSIS
        Takes all unreleased changes listed in changelog, adds them to a new version,
        and makes a new, blank Unreleased section.

    .DESCRIPTION
        This cmdlet automates the updating of change logs in Keep a Changelog 1.0.0 format at release time. It
        takes all changes in the Unreleased section, adds them to a new section with a version number you specify,
        then makes a new, blank Unreleased section.

    .PARAMETER ReleaseVersion
        The version number for the new release.

    .PARAMETER Path
        Full path to the output file. Defaults to 'CHANGELOG.md'.

    .PARAMETER OutputPath
        The path to the output file. Defaults to the same path as parameter Path.

    .PARAMETER LinkMode
        The mode used for adding links at the bottom of the change log for new
        versions. Can be set to either;
        - 'Automatic' - adding based pattern provided via -LinkPattern
        - 'Manual' - adding placeholders which will need manually updated
        - 'None' - not adding any links.

    .PARAMETER LinkPattern
        Pattern used for adding links at the bottom of the Changelog when parameter
        'LinkMode' is set to 'Automatic'. This is a hashtable with three properties
        (FirstRelease, NormalRelease, and Unreleased) that defines the format for
        the three possible types of links. The current version in the patterns
        should be replaced with {CUR} and the previous version with {PREV}.
        See examples for details on format of hashtable.

    .INPUTS
        This cmdlet does not accept pipeline input.

    .OUTPUTS
        This cmdlet does not generate output except in the event of an error or
        notice.

    .EXAMPLE
        Update-Changelog -ReleaseVersion '1.1.1' -LinkMode 'None'
        Does not generate output, but:

        1. Takes all Unreleased changes in .\CHANGELOG.md and adds them to a new
           release tagged with ReleaseVersion and today's date.
        2. Creates a new blank Unreleased section

    .EXAMPLE
        Update-Changelog -ReleaseVersion '1.1.1' -LinkMode 'Manual'
        Does not generate output, but:

        1. Takes all Unreleased changes in .\CHANGELOG.md and adds them to a new
           release tagged with ReleaseVersion and today's date.
        2. Creates a new blank Unreleased section

        Links must manually be updated in the output file.

    .EXAMPLE
        Update-Changelog -ReleaseVersion '1.1.1' -LinkMode 'Automatic' -LinkPattern @{FirstRelease='https://github.com/testuser/testrepo/tree/v{CUR}'; NormalRelease='https://github.com/testuser/testrepo/compare/v{PREV}..v{CUR}'; Unreleased='https://github.com/testuser/testrepo/compare/v{CUR}..HEAD'}
        Does not generate output, but:

        1. Takes all Unreleased changes in .\CHANGELOG.md and adds them to a new
           release tagged with ReleaseVersion and today's date.
        2. Updates links according to LinkPattern.
        3. Creates a new blank Unreleased section

    .NOTES
        This function is based on the function in the repository
        https://github.com/natescherer/ChangelogManagement

    .LINK
        https://github.com/johlju/PSChangeLog
#>
function Update-Changelog
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        #
        [System.String]
        $ReleaseVersion,

        [Parameter()]
        [ValidateScript( { Test-Path -Path $_ })]
        [System.String]
        $Path = 'CHANGELOG.md',

        [Parameter()]
        [ValidatePattern('.*\.md')]
        [System.String]
        $OutputPath = $Path,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Automatic', 'Manual', 'None')]
        [System.String]
        $LinkMode,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]
        $LinkPattern
    )

    if (($LinkMode -eq 'Automatic') -and -not ($LinkPattern))
    {
        $errorMessage = $script:localizedData.ParameterMissing -f 'LinkPattern', 'LinkMode', 'Automatic'

        New-InvalidArgumentException -ArgumentName 'LinkMode' -Message $errorMessage
    }

    $ChangelogData = Get-ChangelogData -Path $Path

    <#
        Create $NewRelease by removing header from old Unreleased section

        Using the regular expression '\r?\n' to look for either CRLF or just LF.
        This resolves issue #11.
    #>
    $NewRelease = $ChangelogData.Unreleased.RawData -replace '## \[Unreleased\]\r?\n', ''

    if ([System.String]::IsNullOrWhiteSpace($NewRelease))
    {
        throw $script:localizedData.NoChangesDetected
    }

    # Edit $NewRelease to add version number and today's date
    $Today = (Get-Date -Format 'o').Split('T')[0]
    $NewRelease = "## [$ReleaseVersion] - $Today$NL" + $NewRelease

    # Inject links into footer
    if ($LinkMode -eq 'Automatic')
    {
        if ($ChangelogData.Released -ne '')
        {
            $NewFooter = ('[Unreleased]: ' + ($LinkPattern['Unreleased'] -replace '{CUR}', $ReleaseVersion) + "$NL" +
                "[$ReleaseVersion]: " + (($LinkPattern['NormalRelease'] -replace '{CUR}', $ReleaseVersion) -replace '{PREV}', $ChangelogData.LastVersion) + "$NL" +
                ($ChangelogData.Footer.Trim() -replace '\[Unreleased\].*', '').TrimStart($NL))
        }
        else
        {
            $NewFooter = ('[Unreleased]: ' + ($LinkPattern['Unreleased'] -replace '{CUR}', $ReleaseVersion) + "$NL" +
                "[$ReleaseVersion]: " + ($LinkPattern['FirstRelease'] -replace '{CUR}', $ReleaseVersion))
        }
    }
    elseif ($LinkMode -eq 'Manual')
    {
        if ($ChangelogData.Released -ne '')
        {
            $NewFooter = ("[Unreleased]: ENTER-URL-HERE$NL" +
                "[$ReleaseVersion]: ENTER-URL-HERE$NL" +
                ($ChangelogData.Footer.Trim() -replace '\[Unreleased\].*', '').TrimStart($NL))

        }
        else
        {
            $NewFooter = ("[Unreleased]: ENTER-URL-HERE$NL" +
                "[$ReleaseVersion]: ENTER-URL-HERE")
        }

        Write-Output -InputObject ($script:localizedData.LinkModeSetToManual -f 'LinkMode','Manual')
    }
    else
    {
        $NewFooter = $ChangelogData.Footer.Trim()
    }

    # Build & write updated CHANGELOG.md
    $Output += $ChangelogData.Header
    $Output += "## [Unreleased]$NL$NL"
    $Output += $NewRelease

    if ($ChangelogData.Released)
    {
        #$Output += $NL
        foreach ($Release in $ChangelogData.Released)
        {
            $Output += $Release.RawData
        }
    }

    $Output += $NewFooter

    Set-Content -Value $Output -Path $OutputPath -NoNewline
}

<#
    .SYNOPSIS
        Takes a changelog in Keep a Changelog 1.0.0 format and converts it to another format.

    .DESCRIPTION
        This cmdlet converts a changelog file using Keep a Changelog 1.0.0 format into one of several other formats.
        Valid formats are Release (same as input, but with the Unreleased section removed), Text
        (markdown and links removed), and TextRelease (Unreleased section, markdown, and links removed).

    .PARAMETER Path
        Parameter description

    .PARAMETER OutputPath
        Parameter description

    .PARAMETER Format
        Parameter description

    .PARAMETER NoHeader
        Parameter description

    .INPUTS
        This cmdlet does not accept pipeline input.

    .OUTPUTS
        This cmdlet does not generate output.

    .EXAMPLE
        ConvertFrom-Changelog -Path .\CHANGELOG.md -Format Release -OutputPath docs\CHANGELOG.md
        Does not generate output, but creates a file at docs\CHANGELOG.md that is the same as the input with the Unreleased section removed.

    .EXAMPLE
        ConvertFrom-Changelog -Path .\CHANGELOG.md -Format Text -OutputPath CHANGELOG.txt
        .Does not generate output, but creates a file at CHANGELOG.txt that has header, markdown, and links removed.

    .NOTES
        This function is based on the function in the repository
        https://github.com/natescherer/ChangelogManagement

    .LINK
        https://github.com/johlju/PSChangeLog
#>
function ConvertFrom-Changelog
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateScript( { Test-Path -Path $_ })]
        # Path to the changelog; defaults to '.\CHANGELOG.md'
        [System.String]
        $Path = 'CHANGELOG.md',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        # The path to the output changelog file; defaults to source path
        [System.String]
        $OutputPath = $Path,

        [Parameter(Mandatory = $true)]
        # Format to convert changelog into. Valid values are Release (same as input, but with the Unreleased
        # section removed), Text (markdown and links removed), and TextRelease (Unreleased section, markdown, and
        # links removed).
        [ValidateSet('Release', 'Text', 'TextRelease')]
        [System.String]
        $Format,

        [Parameter()]
        # Exclude header from output
        [System.Management.Automation.SwitchParameter]
        $NoHeader
    )

    $ChangelogData = Get-ChangelogData -Path $Path
    $Output = ''

    if ($NoHeader -eq $false)
    {
        if ($Format -like 'Text*')
        {
            $Output += (($ChangelogData.Header -replace '\[', '') -replace '\]', ' ').Trim()
        }
        else
        {
            $Output += $ChangelogData.Header.Trim()
        }
    }

    if ($Format -notlike '*Release')
    {
        if ($Output -ne '')
        {
            $Output += "$NL$NL"
        }

        $Output += $ChangelogData.Unreleased.RawData.Trim()
    }

    foreach ($Release in $ChangelogData.Released)
    {
        if ($Output -ne '')
        {
            $Output += "$NL$NL"
        }

        $Output += $Release.RawData.Trim()
    }

    if ($Format -eq 'Release')
    {
        $Output += "$NL$NL"
        $Output += $ChangelogData.Footer -replace "\[Unreleased\].*$NL", ''
    }

    if ($Format -like 'Text*')
    {
        $Output = $Output -replace '### ', ''
        $Output = $Output -replace '## ', ''
        $Output = $Output -replace '# ', ''
    }

    Set-Content -Value $Output -Path $OutputPath -NoNewline
}
