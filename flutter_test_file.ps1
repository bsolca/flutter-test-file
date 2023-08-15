# Author: Benjamin Solcà (github.com/bsolca)
# Description: This script is used to create a test file for a given file name in a Flutter project.
# Usage: Run the script in the folder where the file is located.

# Exit function prompting Exit
function ExitPrompted {
    Write-Host "Exit"
    exit
}

# Gets the filename from the user and validates it.
function Get-Filename {
    $fileName = Read-Host "Enter the file name (my_file or my_file.dart)"

    while ($fileName -eq "" -or $fileName.Contains(".") -eq $false) {
        if ($fileName -eq "") {
            Write-Host "File name cannot be empty"
        }
        elseif ($fileName.Contains(".") -eq $false) {
            $fileName = "$fileName.dart"
        }
        else {
            Get-Filename
        }
    }

    return $fileName
}

# Get the path from the given file name and checks if it is unnique.
function Get-ValidFilePath($currentPath, $fileName, [int]$retryLimit = 3) {
    $files = Get-ChildItem -Path $currentPath -Filter $fileName -Recurse

    if ($files.Count -eq 0) {
        if ($retryLimit -gt 0) {
            Write-Host "No file found with the name: $fileName"
            Write-Host "Retry attempts left: $retryLimit"
            return (Get-ValidFilePath $currentPath $fileName ($retryLimit - 1))
        }
        else {
            Write-Host "No file found after maximum retries."
            ExitPrompted
        }
    }
    elseif ($files.Count -gt 1) {
        Write-Host "More than one file found with the name: $fileName"
        ExitPrompted
    }

    $testFilePath = $files[0].FullName

    if ($testFilePath.Contains("lib") -eq $false) {
        Write-Host "File path does not contain lib folder"
        ExitPrompted
    }

    Write-Host "File path found at:`n$testFilePath"
    return $testFilePath
}

# Function that call  git mv $sourcePath $destinationPath and return true if no error otherwise false
function Read-MoveWithGit($sourcePath, $destinationPath) {
    try {
        git mv $sourcePath $destinationPath 2>$null
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
    }
    catch {
        return $false
    }
    return $true
}

# Function to move the file with SVN
function Read-MoveWithSvn($sourcePath, $destinationPath) {
    try {
        svn move $sourcePath $destinationPath
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
    }
    catch {
        return $false
    }
    return $true
}

function Read-MovingMethod($sourcePath, $destinationPath) {
    # Check if the destination directory exists, and create it if needed
    $destinationDirectory = [System.IO.Path]::GetDirectoryName($destinationPath)
    if (-not (Test-Path -Path $destinationDirectory)) {
        New-Item -Path $destinationDirectory -ItemType Directory -Force
    }

    $movedWithGit = Read-MoveWithGit $sourcePath $destinationPath
    if (-not $movedWithGit) {
        $movedWithSvn = Read-MoveWithSvn $sourcePath $destinationPath
        # if false move with powershell
        if (-not $movedWithSvn) {
            Move-Item -Path $sourcePath -Destination $destinationPath -Force
        }
    }

    # if no error print success
    if ($?) {
        $pathWithoutFileName = Split-Path -Path $sourcePath
        Remove-EmptyDirectory $pathWithoutFileName
        Write-Host "Test file moved to: $destinationPath, happy testing!"
    }
    else {
        Write-Host "Error moving the file"
        ExitPrompted
    }
}


# Function to query whether to move the file
function Read-ToMoveTestFile($sourcePath, $destinationPath) {
    $moveFile = Read-Host "Do you want to move the file to the right place? (Y/n)"

    if ($moveFile -eq "n") {
        ExitPrompted
    }
    elseif ($moveFile -eq "Y" -or $moveFile -eq "y" -or $moveFile -eq "") {
        Read-MovingMethod $sourcePath $destinationPath
    }
    else {
        Write-Host "Wrong input, please try again"
        Read-ToMoveTestFile $sourcePath $destinationPath
    }
}

# Function to remove an empty directory
function Remove-EmptyDirectory($directoryPath) {
    do {
        # Check if the directory contains files
        $hasFiles = $null
        if (Test-Path -Path $directoryPath) {
            $hasFiles = (Get-ChildItem -Path $directoryPath).Count -gt 0
        }

        if (-not $hasFiles -and $null -ne $directoryPath) {
            $parentDirectory = Split-Path -Path $directoryPath -Parent
            Remove-Item -Path $directoryPath -Force
            $directoryPath = $parentDirectory
        }
    }
    while (-not $hasFiles -and $null -ne $directoryPath)
}

# Try add the file to git otherwise return false
function Read-AddToGit($testFilePath) {
    try {
        git add $testFilePath 2>$null
        if ($LASTEXITCODE -ne 0) {
            return
        }
    }
    catch {
        return
    }
    return
}

# Try add the file to svn otherwise return false
function Read-AddToSvn($testFilePath) {
    try {
        svn add --parents $testFilePath
        if ($LASTEXITCODE -ne 0) {
            return
        }
    }
    catch {
        return
    }
    return
}

# Function to create a new test file
function New-TestFile($testFilePath, $testFileName) {
    New-Item -Path $testFilePath -ItemType File -Force
    Read-AddToGit $testFilePath
    Read-AddToSvn $testFilePath

    Write-Host "Test file created: $testFilePath"
}

# Function to query whether to move the file
function Read-ToMove($testFiles, $testFilePath) {
    $numberFiles = $testFiles.Count

    if ($numberFiles -ne 1) {
        Write-Host "Test file name found more than once ($numberFiles), please fix manually."
        ExitPrompted
    }

    $testFileExisting = $testFiles[0].FullName

    if ($testFileExisting -eq $testFilePath) {
        Write-Host "Test file already exists at the right place:`n$testFilePath"
        ExitPrompted
    }

    Write-Host "Current location: $testFileExisting"
    Write-Host "Correct location: $testFilePath"

    Read-ToMoveTestFile $testFileExisting $testFilePath
}

function Main() {
    $currentPath = Get-Location
    Write-Host "Flutter Test File (tft)"

    $fileName = Get-Filename
    $fileNamePath = Get-ValidFilePath $currentPath $fileName

    $testFilePath = $fileNamePath.Replace("lib", "test")
    $testFilePath = $testFilePath.Insert($testFilePath.LastIndexOf("."), "_test")

    $testFileName = $fileName.Replace(".", "_test.")

    # Check if the test file name already exists somewhere
    $testFiles = Get-ChildItem -Path $currentPath -Filter $testFileName -Recurse

    if ($testFiles.Count -ne 0) {
        Read-ToMove $testFiles $testFilePath
    }
    else {
        New-TestFile $testFilePath $testFileName
        ExitPrompted
    }
}

Main
