<#
    .SYNOPSIS
        Public Pester function tests.
#>
[OutputType()]
Param ()

#region Functions used in tests
Function Test-VcDownloads {
    <#
        .SYNOPSIS
            Tests downloads from Get-VcList are sucessful.
    #>
    [CmdletBinding()]
    Param (
        [Parameter()]
        [PSCustomObject] $VcList,

        [Parameter()]
        [string] $Path
    )
    $Output = $False
    ForEach ($Vc in $VcList) {
        $Folder = Join-Path (Join-Path (Join-Path $(Resolve-Path -Path $Path) $Vc.Release) $Vc.Architecture) $Vc.ShortName
        $Target = Join-Path $Folder $(Split-Path -Path $Vc.Download -Leaf)
        If (Test-Path -Path $Target -PathType Leaf) {
            Write-Verbose "$($Target) - exists."
            $Output = $True
        }
        Else {
            Write-Warning "$($Target) - not found."
            $Output = $False
        }
    }
    Write-Output $Output
}
#endregion

#region Pester tests
Describe 'Get-VcList' -Tag "Get" {
    Context 'Return built-in manifest' {
        It 'Given no parameters, it returns supported Visual C++ Redistributables' {
            $VcList = Get-VcList
            $VcList | Should -HaveCount 10
        }
        It 'Given valid parameter -Export All, it returns all Visual C++ Redistributables' {
            $VcList = Get-VcList -Export All
            $VcList | Should -HaveCount 34
        }
        It 'Given valid parameter -Export Supported, it returns all Visual C++ Redistributables' {
            $VcList = Get-VcList -Export Supported
            $VcList | Should -HaveCount 14
        }
        It 'Given valid parameter -Export Unsupported, it returns unsupported Visual C++ Redistributables' {
            $VcList = Get-VcList -Export Unsupported
            $VcList | Should -HaveCount 20
        }
    }
    Context 'Validate Get-VcList array properties' {
        $VcList = Get-VcList
        ForEach ($vc in $VcList) {
            It "VcRedist [$($vc.Name), $($vc.Architecture)] has expected properties" {
                $vc.Name.Length | Should -BeGreaterThan 0
                $vc.ProductCode.Length | Should -BeGreaterThan 0
                $vc.Version.Length | Should -BeGreaterThan 0
                $vc.URL.Length | Should -BeGreaterThan 0
                $vc.Download.Length | Should -BeGreaterThan 0
                $vc.Release.Length | Should -BeGreaterThan 0
                $vc.Architecture.Length | Should -BeGreaterThan 0
                $vc.ShortName.Length | Should -BeGreaterThan 0
                $vc.Install.Length | Should -BeGreaterThan 0
                $vc.SilentInstall.Length | Should -BeGreaterThan 0
            }
        }
    }
    Context 'Return external manifest' {
        It 'Given valid parameter -Path, it returns Visual C++ Redistributables from an external manifest' {
            $Json = Join-Path -Path $ProjectRoot -ChildPath "Redists.json"
            Export-VcManifest -Path $Json
            $VcList = Get-VcList -Path $Json
            $VcList.Count | Should -BeGreaterOrEqual 10
        }
    }
    Context 'Test fail scenarios' {
        It 'Given an JSON file that does not exist, it should throw an error' {
            $Json = Join-Path -Path $ProjectRoot -ChildPath "RedistsFail.json"
            { Get-VcList -Path $Json } | Should Throw
        }
        It 'Given an invalid JSON file, should throw an error on read' {
            $Json = Join-Path -Path $ProjectRoot -ChildPath "README.MD"
            { Get-VcList -Path $Json } | Should Throw
        }
    }
}

Describe 'Export-VcManifest' -Tag "Export" {
    Context 'Export manifest' {
        It 'Given valid parameter -Path, it exports an JSON file' {
            $Json = Join-Path -Path $ProjectRoot -ChildPath "Redists.json"
            Export-VcManifest -Path $Json
            Test-Path -Path $Json | Should -Be $True
        }
    }
    Context 'Export and read manifest' {
        It 'Given valid parameter -Path, it exports an JSON file' {
            $Json = Join-Path -Path $ProjectRoot -ChildPath "Redists.json"
            Export-VcManifest -Path $Json
            $VcList = Get-VcList -Path $Json
            $VcList.Count | Should -BeGreaterOrEqual 10
        }
    }
    Context 'Test fail scenarios' {
        It 'Given an invalid path, it should throw an error' {
            { Export-VcManifest -Path (Join-Path -Path (Join-Path -Path $ProjectRoot -ChildPath "Temp") -ChildPath "Temp.json") } | Should Throw
        }
    }
}

Describe 'Save-VcRedist' -Tag "Save" {
    Context 'Download Redistributables' {
        It 'Downloads supported Visual C++ Redistributables' {
            If (Test-Path -Path env:Temp -ErrorAction SilentlyContinue) {
                $Path = Join-Path -Path $env:Temp -ChildPath "VcDownload"
                If (!(Test-Path $Path)) { New-Item $Path -ItemType Directory -Force }
                $VcList = Get-VcList
                Write-Host "`tDownloading VcRedists." -ForegroundColor Cyan
                Save-VcRedist -VcList $VcList -Path $Path -ForceWebRequest
                Test-VcDownloads -VcList $VcList -Path $Path | Should -Be $True
            }
            Else {
                Write-Warning -Message "env:Temp does not exist."
            }
        }
    }
    Context "Test pipeline support" {
        It "Should not throw when passed via pipeline with no parameters" {
            If (Test-Path -Path env:Temp -ErrorAction SilentlyContinue) {
                New-Item -Path (Join-Path -Path $env:Temp -ChildPath "VcTest") -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
                Push-Location -Path (Join-Path -Path $env:Temp -ChildPath "VcTest")
                Write-Host "`tDownloading VcRedists." -ForegroundColor Cyan
                { Get-VcList | Save-VcRedist -ForceWebRequest } | Should -Not -Throw
                Pop-Location
            }
            Else {
                Write-Warning -Message "env:Temp does not exist."
            }
        }
    }
    Context 'Test fail scenarios' {
        It 'Given an invalid path, it should throw an error' {
            { Save-VcRedist -Path (Join-Path -Path $ProjectRoot -ChildPath "Temp") } | Should -Throw
        }
    }
}

Describe 'Install-VcRedist' -Tag "Install" {
    Context 'Test exception handling for invalid VcRedist download path' {
        If (Test-Path -Path env:Temp -ErrorAction SilentlyContinue) {
            It "Should throw when passed via pipeline with no parameters" {
                Push-Location -Path $env:Temp
                { Get-VcList | Install-VcRedist } | Should -Throw
                Pop-Location
            }
        }
        Else {
            Write-Warning -Message "env:Temp does not exist."
        }
    }
    Context 'Install Redistributables' {
        If (Test-Path -Path env:Temp -ErrorAction SilentlyContinue) {
            $VcRedists = Get-VcList
            $Path = Join-Path -Path $env:Temp -ChildPath "VcDownload"
            Write-Host "`tInstalling VcRedists." -ForegroundColor Cyan
            $Installed = Install-VcRedist -VcList $VcRedists -Path $Path -Silent
            ForEach ($Vc in $VcRedists) {
                It "Installed the VcRedist: '$($vc.Name)'" {
                    $vc.ProductCode -match $Installed.ProductCode | Should -Not -BeNullOrEmpty
                }
            }
        }
        Else {
            Write-Warning -Message "env:Temp does not exist."
        }
    }
}

If (($Null -eq $PSVersionTable.OS) -or ($PSVersionTable.OS -like "*Windows*")) {

    Describe 'Get-InstalledVcRedist' -Tag "Install" {
        Context 'Validate Get-InstalledVcRedist array properties' {
            $VcList = Get-InstalledVcRedist
            ForEach ($vc in $VcList) {
                It "VcRedist '$($vc.Name)' has expected properties" {
                    $vc.Name.Length | Should -BeGreaterThan 0
                    $vc.Version.Length | Should -BeGreaterThan 0
                    $vc.ProductCode.Length | Should -BeGreaterThan 0
                    $vc.UninstallString.Length | Should -BeGreaterThan 0
                }
            }
        }
    }

    Describe 'Uninstall-VcRedist' -Tag "Uninstall" {
        Context 'Uninstall VcRedists' {
            Write-Host "`tUninstalling VcRedists." -ForegroundColor Cyan
            { Uninstall-VcRedist -Release 2008, 2010 -Confirm:$False } | Should -Not -Throw
        }
    }

}
#endregion
