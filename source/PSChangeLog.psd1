
@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'PSChangeLog.psm1'

    # Version number of this module.
    ModuleVersion     = '0.0.1'

    GUID              = 'f19599ff-c084-4f90-9d05-e58c7d804015'

    # Author of this module
    Author            = 'Johan Ljunggren'

    # Company or vendor of this module
    CompanyName       = 'Viscalyx'

    # Copyright statement for this module
    Copyright         = '(c) PSChangeLog contributors.'

    # Description of the functionality provided by this module
    Description       = 'Manage change log files in the keepachangelog.com format.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.0'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Get-ChangelogData'
        'Add-ChangelogData'
        'New-Changelog'
        'Update-Changelog'
        'ConvertFrom-Changelog'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport   = @()

    # DSC resources to export from this module
    DscResourcesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = 'changelog', 'keepachangelog'

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/johlju/PSChangeLog/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/johlju/PSChangeLog'

            # ReleaseNotes of this module
            ReleaseNotes = ''

            # Prerelease string of this module
            Prerelease = ''
        } # End of PSData hashtable
    } # End of PrivateData hashtable
}

