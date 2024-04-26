# Author: Aviad Ofek
# Description: This script retrieves GPU information from a remote server using Posh-SSH module and displays it in the console. 
#              It shows the GPU index, name, load, and memory usage with visual bars. 
#              The load bar is colorized based on the load percentage, and the memory usage bar represents usage out of total memory. 
#              Each GPU's information is separated by a line of asterisks for better readability.


# from Powershell window - $OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8
#   .\GPU_Monitoring_Script.ps1



# Import required modules (ensure they are installed as necessary)
Import-Module Posh-SSH

# Server credentials
$serverIP = "SERVER IP"  # Server IP address
$username = "USERNAME"           # Username
$securePassword = ConvertTo-SecureString "PASSWORD123" -AsPlainText -Force  # Password
$credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)

# Establish SSH connection and handle potential errors
try {
    $session = New-SSHSession -ComputerName $serverIP -Credential $credential -ErrorAction Stop
}
catch {
    Write-Host "Failed to establish SSH connection: $($_.Exception.Message)"
    exit
}

# Function to get GPU information including temperature
function Get-GpuInfo {
    try {
        $gpuInfoCommand = "nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader"
        $gpuInfo = Invoke-SSHCommand -SessionId $session.SessionId -Command $gpuInfoCommand
        return $gpuInfo.Output
    }
    catch {
        Write-Host "Failed to retrieve GPU information: $($_.Exception.Message)"
        return "Error retrieving GPU information"
    }
}

# Function to display a visual bar for GPU load, memory usage, or temperature
function Display-LoadBar($currentValue, $totalValue, $label) {
    $barLength = 50  # The total length of the load bar
    $percentageUsed = ($currentValue / $totalValue) * 100  # Calculate the percentage used
    $filledLength = [Math]::Round($percentageUsed * $barLength / 100)
    $filledBar = '█' * $filledLength
    $emptyBar = '-' * ($barLength - $filledLength)

    # Determine bar color based on the label and the percentage used
    switch ($label) {
        "Load Bar" {
            if ($percentageUsed -ge 90) {
                $barColor = "Red"
            } elseif ($percentageUsed -ge 50) {
                $barColor = "Yellow"
            } else {
                $barColor = "Green"
            }
            $displayPercentage = "{0:N2}%" -f $percentageUsed  # Display with two decimal places
        }
        "Memory Usage Bar" {
            if ($percentageUsed -ge 90) {
                $barColor = "Red"
            } elseif ($percentageUsed -ge 50) {
                $barColor = "Yellow"
            } else {
                $barColor = "Green"
            }
            $displayPercentage = "{0:N2}%" -f $percentageUsed  # Display with two decimal places
        }
        "Temperature Bar" {
            if ($currentValue -ge 90) {
                $barColor = "Red"
            } elseif ($currentValue -ge 50) {
                $barColor = "Yellow"
            } else {
                $barColor = "Green"
            }
            $displayPercentage = "{0}°C" -f $currentValue  # Display without decimal places for temperature
        }
    }

    # Output the label and the bar with separate colors
    Write-Host "${label}: " -NoNewline
    Write-Host $filledBar -NoNewline -ForegroundColor $barColor
    Write-Host $emptyBar -NoNewline
    Write-Host " $displayPercentage"  # Display the percentage or temperature after the bar
}




# Loop to continuously check and display GPU information
try {
    while ($true) {
        $currentInfo = Get-GpuInfo
        Clear-Host  # Clear the console for a fresh display
        Write-Host "Current GPU Load Information $serverIP : $(Get-Date)"
        Write-Host ""  # Add a blank line for spacing

foreach ($line in $currentInfo) {
    $details = $line -split ", "
    $gpuIndex = $details[0]
    $gpuName = $details[1]
    $loadPercent = $details[2] -replace '%', ''  # Strip the percentage sign for calculations
    $usedMemory = [int]($details[3] -replace '\sMiB', '')  # Remove ' MiB' and convert to integer
    $totalMemory = [int]($details[4] -replace '\sMiB', '')  # Remove ' MiB' and convert to integer
    $temperature = [int]($details[5] -replace '\sC', '')  # Remove ' C' and convert to integer

    Write-Host "GPU Index: $gpuIndex"
    Write-Host "GPU Name: $gpuName"
    Write-Host "GPU Load:"
    Display-LoadBar $loadPercent 100 "Load Bar"
    Write-Host "Memory Used: $usedMemory MiB of $totalMemory MiB"
    Display-LoadBar $usedMemory $totalMemory "Memory Usage Bar"
    Write-Host "Temperature:"
    Display-LoadBar $temperature 100 "Temperature Bar"
    Write-Host ""  # Add a blank line for readability
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor DarkGray

}

        Start-Sleep -Seconds 5  # Refresh every 5 seconds
    }
}
finally {
    # Ensure the SSH session is closed when the script exits
    if ($session) {
        Remove-SSHSession -SessionId $session.SessionId
    }
}
