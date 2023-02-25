# if (Split-Path -Parent){
$PSCommandPath | Split-Path -Parent
$host.UI.RawUI.ForegroundColor = "White"
$host.UI.RawUI.BackgroundColor = "Black"
Clear-Host
function install_software {
    param (
        $software_id,
        $software_name,
        $install_command,
        $verify_installed,
        $force_install
    )
    # function built using https://keestalkstech.com/2017/10/powershell-snippet-check-if-software-is-installed/

    if ($verify_installed -eq $true) {
        $installed = $null -ne (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -eq $software_id })
        if ($installed -eq $false) {
            if ($force_install -eq $false) {
                # give user the option to install
                $install = Read-Host "`r`n$software_name recommended but not found. Install now? (y/[n])".ToLower()
                if ($install -eq 'y' -Or $install -eq 'yes') { 
                    Write-Host "`r`n"
                    Write-Host "Installing $software_name..."
                    Invoke-Expression $install_command
                }
                else {
                    Write-Host "skipping $software_name install"
                }
            }
            $install = Read-Host "`r`n$software_name required. Install now or quit? (y/[q])"
            $install = $install.ToLower()
            # @TODO: investigate code refactoring for duplicate code
            if ($install -eq 'y' -Or $install -eq 'yes') { 
                Write-Host "Installing $software_name..."
                Invoke-Expression $install_command
            }
            else {
                Write-Host "skipping $software_name install and exiting..."
                exit
            }
        }
        else {
            Write-Host "`r`n$software_name already installed." -ForegroundColor Yellow
        }
    }
    elseif ($force_install -eq $false) { 
        $install = Read-Host "`r`n$software_name recommended. Install now? (y/[n])"
        $install = $install.ToLower()
        # @TODO: investigate code refactoring for duplicate code
        if ($install -eq 'y' -Or $install -eq 'yes') { 
            Write-Host "Installing $software_name..."
            Invoke-Expression $install_command
        }
        else {
            Write-Host "skipping $software_name install"
        }
    }
    else {
        # force_install: true, verify_install: false
        $install = Read-Host "`r`n$software_name required. Install now or quit? (y/[q])"
        $install = $install.ToLower()
        if ($install -eq 'y' -Or $install -eq 'yes') { 
            Write-Host "Installing $software_name..."
            Invoke-Expression $install_command

        }
        else {
            Write-Host "skipping $software_name install and exiting..."
            exit
        }
    }

    $host.UI.RawUI.BackgroundColor = "Black"
}

function restart_prompt {
    Write-Host "`r`nA restart is required for the changes to take effect. " -ForegroundColor Magenta
    $confirmation = Read-Host "`r`nRestart now (y/[n])?" 
    if ($confirmation -ieq 'y') {
        Restart-Computer -Force
    }
}


# open terminal with admin priveleges
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    
    # get a head start on building custom docker images using machine settings and without admin priveleges
    $pwd_path = Split-Path -Path $PSCommandPath
    Push-Location 'docker-to-wsl/scripts'
    # holy moly getting this invoke-wmimethod was tough - great reference here: https://slai.github.io/posts/powershell-and-external-commands-done-right/
    $cmd_args = "$pwd_path/docker-to-wsl/scripts/images-build.bat" 
    &$cmd_args = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList cmd "$pwd_path/docker-to-wsl/scripts/images-build.bat"
    Pop-Location

    $software_id = $software_name = "WinGet"
    $install_command = "powershell.exe -ExecutionPolicy Unrestricted -command '& $pwd_path/docker-to-wsl/scripts/get-latest-winget.ps1'"
    # write-host "install command: $install_command"
    $verify_installed = $false
    $force_install = $true
    
    install_software $software_id $software_name $install_command $verify_installed $force_install
        
    # @TODO: find a way to check if windows terminal is installed
    $software_id = $software_name = "Windows Terminal"
    $install_command = "winget install Microsoft.WindowsTerminal"
    $verify_installed = $false
    $force_install = $false
    install_software $software_id $software_name $install_command $verify_installed $force_install

    $software_id = "Git_is1"
    $software_name = "Github CLI"
    $install_command = "winget install -e --id GitHub.cli"
    $verify_installed = $true
    $force_install = $true
    install_software $software_id $software_name $install_command $verify_installed $force_install

    # use windows-features-wsl-add to handle windows features install
    powershell "& $pwd_path/docker-to-wsl/scripts/windows-features-wsl-add/configure-windows-features.ps1"


    # @TODO: find a way to check if VSCode is installed
    $software_id = $software_name = "Visual Studio Code (VSCode)"
    $install_command = "winget install Microsoft.VisualStudioCode --override '/SILENT /mergetasks=`"!runcode,addcontextmenufiles,addcontextmenufolders`"'"
    $verify_installed = $false
    $force_install = $true
    install_software $software_id $software_name $install_command $verify_installed $force_install


    # Docker Desktop happens to work for both id and name
    $software_id = $software_name = "Docker Desktop"
    $install_command = "winget install --id=Docker.DockerDesktop  -e"
    $verify_installed = $true
    $force_install = $true
    install_software $software_id $software_name $install_command $verify_installed $force_install

    # launch docker desktop
    C:\"Program Files"\Docker\Docker\"Docker Desktop".exe

    Write-Host "`r`nA restart may be required for the changes to take effect. " -ForegroundColor Magenta
    $confirmation = Read-Host "`r`nRestart now (y/[n])?" 
    if ($confirmation -ieq 'y') {
        Restart-Computer -Force
    }
    else {

        if ((Read-Host "`r`nopen Docker Dev environment? [y]/n") -ine 'n'  ) {
            Start-Process "https://open.docker.com/dashboard/dev-envs?url=https://github.com/kindtek/docker-to-wsl@dev"
        } 


        # start WSL docker import tool
        $pwd_path = Split-Path -Path $PSCommandPath
        $full_path = "& $pwd_path/docker-to-wsl/scripts/wsl-import.ps1" 
        # Start-Process "powershell" "/c $full_path"
        Start-Process powershell.exe $full_path -Verb runAs -WindowStyle "Maximized"

        $user_input = (Read-Host "`r`nopen Docker Dev environment? [y]/n")
        if ( $user_input -ne 'n' ) {
            Start-Process "https://open.docker.com/dashboard/dev-envs?url=https://github.com/kindtek/docker-to-wsl@dev" -WindowStyle "Hidden"
        }  

        Write-Output "DONE!"
    }
}
else {
    # launch admin console
    Start-Process -FilePath "powershell" -ArgumentList "$('-File ""')$(Get-Location)$('\')$($MyInvocation.MyCommand.Name)$('""')" -Verb runAs -Wait -WindowStyle "Maximized"
}    



