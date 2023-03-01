$host.UI.RawUI.ForegroundColor = "White"
$host.UI.RawUI.BackgroundColor = "Black"
# powershell version compatibility for PSScriptRoot
if (!$PSScriptRoot) { $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }
$pwd_path = $PSScriptRoot
$git_dir = $pwd_path.Replace("$repo_src_name/scripts", "") 
$git_dir = $git_dir.Replace("/$repo_src_name/scripts", "") 
$git_dir = $git_dir.Replace("\$repo_src_name\scripts", "") 
$git_dir = $git_dir.Replace("$repo_src_name\scripts", "") 
$git_dir += "/$repo_src_name"
# jump to bottom line without clearing scrollback
Write-Output "$([char]27)[2J"

function restart_prompt {
    Write-Host "`r`nA restart is required for the changes to take effect. " -ForegroundColor Magenta -BackgroundColor "Black"
    $confirmation = Read-Host "`r`nType 'reboot now' to reboot your computer now`r`n ..or hit ENTER to skip" 
    if ($confirmation -ieq 'reboot now') {
        Restart-Computer -Force
    }
}

function install_all {
    param ($pwd_path, $git_dir)

    Set-Location $git_dir

    # use windows-features-wsl-add to handle windows features install 
    # installing first to make sure environment has powershell 2
    $winconfig = "$pwd_path/devels-advocate/add-windows-features.ps1"
    &$winconfig = Invoke-Expression -command "$pwd_path/devels-advocate/add-windows-features.ps1"


    Write-Host "`r`nThe following programs will now be installed:" -ForegroundColor Magenta
    Write-Host "`t- WinGet`r`n`t- Github CLI`r`n`t- Visual Studio Code`r`n`t- Docker Desktopr`n`t- Windows Terminal" -ForegroundColor Magenta
    Write-Host "`r`nClose window to quit at any time"

    if (!(Test-Path -Path "$git_dir/.winget-installed" -PathType Leaf)) {
        # install winget and use winget to install everything else
        $host.UI.RawUI.BackgroundColor = "Black"
        $software_name = "WinGet"
        $winget = "$pwd_path/devels-advocate/get-latest-winget.ps1"
        Write-Host "`n`r`n`rInstalling $software_name ..."  -BackgroundColor "Black"
        &$winget = Invoke-Expression -command "$pwd_path/devels-advocate/get-latest-winget.ps1" 
        Write-Host "true" | Out-File -FilePath "$git_dir/.winget-installed"
    }

    if (!(Test-Path -Path "$git_dir/.github-installed" -PathType Leaf)) {
        $host.UI.RawUI.BackgroundColor = "Black"
        $software_name = "Github CLI"
        Write-Host "`n`rInstalling $software_name ..." -BackgroundColor "Black"
        Invoke-Expression -Command "winget install -e --id GitHub.cli"
        $host.UI.RawUI.BackgroundColor = "Black"
        Invoke-Expression -Command "winget install --id Git.Git -e --source winget"
        Write-Host "`n`r" -BackgroundColor "Black"
        &$winget = Invoke-Expression -command "$pwd_path/devels-advocate/get-latest-winget.ps1" 
        Write-Host "true" | Out-File -FilePath "$git_dir/.github-installed"
    }

    if (!(Test-Path -Path "$git_dir/.vscode-installed" -PathType Leaf)) {
        $host.UI.RawUI.BackgroundColor = "Black"
        $software_name = "Visual Studio Code (VSCode)"
        Write-Host "`r`nInstalling $software_name`r`n" -BackgroundColor "Black"
        Invoke-Expression -Command "winget install Microsoft.VisualStudioCode --override '/SILENT /mergetasks=`"!runcode,addcontextmenufiles,addcontextmenufolders`"'" 
        Write-Host "true" | Out-File -FilePath "$git_dir/.vscode-installed"
    }

    if (!(Test-Path -Path "$git_dir/.docker-installed" -PathType Leaf)) {
        $host.UI.RawUI.BackgroundColor = "Black"
        $software_name = "Docker Desktop"
        Write-Host "`r`nInstalling $software_name`r`n" -BackgroundColor "Black"
        Invoke-Expression -Command "winget install --id=Docker.DockerDesktop -e" 
        Write-Host "true" | Out-File -FilePath "$git_dir/.docker-installed"
    }

    if (!(Test-Path -Path "$git_dir/.wterminal-installed" -PathType Leaf)) {
        # $windows_terminal_install = Read-Host "`r`nInstall Windows Terminal? ([y]/n)"
        # if ($windows_terminal_install -ine 'n' -And $windows_terminal_install -ine 'no') { 
        $host.UI.RawUI.BackgroundColor = "Black"
        $software_name = "Windows Terminal"
        Write-Host "`r`nInstalling $software_name`r`n" -BackgroundColor "Black"
        Invoke-Expression -Command "winget install Microsoft.WindowsTerminal" 
        # }
        Write-Host "true" | Out-File -FilePath "$git_dir/.wterminal-installed"
    }

    Write-Host "`r`nA restart may be required for the changes to take effect. " -ForegroundColor Magenta -BackgroundColor "Black"
    $confirmation = Read-Host "`r`nType 'reboot now' to reboot your computer now`r`n ..or hit ENTER to skip" 
    if ($confirmation -ieq 'reboot now') {
        Restart-Computer -Force
    }
}

# source of the below self-elevating script: https://blog.expta.com/2017/03/how-to-self-elevate-powershell-script.html#:~:text=If%20User%20Account%20Control%20(UAC,select%20%22Run%20with%20PowerShell%22.
# Self-elevate the script if required
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
        Start-Process -FilePath PowerShell.exe -Verb Runas -WindowStyle "Maximized" -ArgumentList $CommandLine
        Exit
    }
}
# source of the above self-elevating script: https://blog.expta.com/2017/03/how-to-self-elevate-powershell-script.html#:~:text=If%20User%20Account%20Control%20(UAC,select%20%22Run%20with%20PowerShell%22.


try {
    # refresh environment variables
    cmd /c start powershell -Command "$git_dir/scripts/choco/refresh-env.cmd"

    Set-Location $git_dir
    # if git status works and finds devels-workshop repo, assume the install has been successfull and this script was ran once before
    $git_status = git remote show origin 
    # determine if git status works by checking output for LICENSE - see typical output of git status here: https://amitd.co/code/shell/git-status-porcelain
    if ($git_status.NotContains("github.com/kindtek/devels-workshop")) {
        install_all $pwd_path $git_dir
    }
}
catch {
    install_all $pwd_path $git_dir
}

# try {
    # refresh environment variables
    cmd /c start powershell -Command "$git_dir/scripts/choco/refresh-env.cmd"

    $repo_src_owner = 'kindtek'
    $repo_src_name = 'devels-workshop'
    $repo_src_branch = 'windows'

    # test git
    $git_version = git --version 

    Write-Host "attempting to clone repo... " -ForegroundColor "DarkBlue"
    # if it works remove the directory and the manually downloaded files..
    if (Test-Path -Path "$git_dir") {
        Set-Location $git_dir
        Set-Location ../
        Rename-Item -Path "$git_dir" -NewName "$git_dir-temp" -Force 
        Remove-Item "$git_dir-temp" -Force -Recurse 
    }
    $host.UI.RawUI.BackgroundColor = "Black"
    # .. and then clone the repo
    git clone "https://github.com/$repo_src_owner/$repo_src_name.git" --branch $repo_src_branch "$git_dir"
    Set-Location "$git_dir"
    $host.UI.RawUI.BackgroundColor = "Black"
    git submodule update --force --recursive --init --remote
    $host.UI.RawUI.BackgroundColor = "Black"
# }
# if git is not recognized try to limp along with the manually downloaded files
# catch {}

# refresh env again
cmd /c start powershell -Command "$git_dir/scripts/choco/refresh-env.cmd" 

$user_input = (Read-Host "`r`nopen Docker Dev environment? [y]/n")
if ( $user_input -ine "n" ) {
    Start-Process "https://open.docker.com/dashboard/dev-envs?url=https://github.com/kindtek/devels-workshop@main" -WindowStyle "Hidden"
} 

Write-Host "`r`nSetup complete!`r`n" -ForegroundColor Green -BackgroundColor "Black"

try {
    # @TODO: maybe start in new window
    $start_devs_playground = Read-Host "`r`nStart Devel's Playground ([y]/n)"
    $software_name = "Docker Desktop"
    if ($start_devs_playground -ine 'n' -And $start_devs_playground -ine 'no') { 
        # launch docker desktop and keep it open 
        Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -WindowStyle "Hidden"
        Write-Host "`r`n`r`nWaiting for $software_name to come online ..." -BackgroundColor "Black" -ForegroundColor "Yellow"
        Write-Host "`r`nNOTE: $software_name is required to be running for the Devel's Playground to work. Do NOT quit $software_name until you are done running it.`r`nYou can minimize $software_name by pressing WIN + Down arrow" -BackgroundColor "Black" -ForegroundColor "Yellow"

        $docker_success1 = $false
        $docker_success2 = $false
        $docker_tries = 0
        do {
            $docker_tries++
            $docker_status_now = (docker version)
            Start-Sleep -seconds 5
            # debug
            write-host "$docker_status_now`r`n"
            # $check_again = Read-Host "keep checking? (y[n])"
            if (!($docker_status_now.Contains("error"))){
                if ($docker_success1 -eq $true){
                    $docker_success2 = $true
                }
                else {
                    $docker_success1 = $true
                }
            }
        }
        while ((!($docker_success2)) -Or $docker_tries -lt 6)
        # debug
        # while ((!($docker_success2)) -Or $check_again -ieq 'y')

        if ($docker_succes2){
            # // commenting out background building process because this is NOT quite ready.
            # // would like to run in separate window and then use these new images in devel's playground 
            # // if they are more up to date than the hub - which could be a difficult process
            # $cmd_command = "$git_dir/devels_playground/scripts/docker-images-build-in-background.ps1"
            # &$cmd_command = cmd /c start powershell -Command "$git_dir/devels_playground/scripts/docker-images-build-in-background.ps1" -WindowStyle "Maximized"
            # Write-Host "`r`n" -BackgroundColor "Black"
            $host.UI.RawUI.BackgroundColor = "Black"
            $devs_playground = "$git_dir/devels-playground/scripts/wsl-import-docker-image.cmd"
            &$devs_playground = cmd /c start powershell -Command "$git_dir/devels-playground/scripts/wsl-import-docker-image.cmd"
        }
        else {
            Write-Host "Failed to launch docker. Not able to start Devel's Playground. Please restart and run the script again:" -ForegroundColor "Yellow"
            Write-Host "powershell -executionpolicy remotesigned -Command `"Invoke-WebRequest https://raw.githubusercontent.com/kindtek/powerhell-remote/devels-workshop/install.ps1 -OutFile install-kindtek-devels-workshop.ps1`"; powershell -executionpolicy remotesigned -File install-kindtek-devels-workshop.ps1"
        }
    }
}
catch {}

try {
    Remove-Item "$git_dir".replace($repo_src_name, "install-$repo_src_owner-$repo_src_name.ps1") -Force -ErrorAction SilentlyContinue
    Write-Host "`r`nCleaning up..  `r`n"
    # make extra sure this is not a folder that is not important (ie: system32 - which is a default location)
    if ($git_dir.Contains($repo_src_name) -And $git_dir.NotContains("System32") ) {
        Remove-Item $git_dir -Recurse -Confirm -Force -ErrorAction SilentlyContinue
    }
}
catch {
    Write-Host "Run the following command to delete installation files:`r`n(will also remove Devel's Playground)`r`nRemove-Item $git_dir -Recurse -Confirm -Force`r`n"
}


