# make sure that targets have winrm ports open and winrm is configured

# Variables
$rsThreadCount = 2
$rsMSecondWaitCheck = 300
$targets = @("jojo1","win2022-001","win2019-001")
$jsonoutput = "c:\temp\rs-sysinfo-$((New-Guid).guid).json"


# Initiate a Runspace Pool
$runspacePool = [runspacefactory]::CreateRunspacePool(1, $rsThreadCount)
$runspacePool.Open()
$rsJobs = @()
$rsResults = @()

# This is the scriptblock that is going to run. In this example we take the target param and get some basic system info from that system.
$rsScriptBlock = {
    Param ($target)
    $computerSystemInfo = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $target
    # Note: as a hash table this will not make a table with many instances so we type it as a pscustomobject
    $result = [PSCustomObject]@{
        computerName = $computerSystemInfo.PSComputerName
        memoryGB = [int]($computerSystemInfo.TotalPhysicalMemory/1024/1024/1024)
        processors = $computerSystemInfo.NumberOfProcessors
        logicalProcs = $computerSystemInfo.NumberOfLogicalProcessors
    }
    return $result
}

foreach ($target in $targets) {

    # Set a hash for splatting params. We will send the current iteration value to the next runspace instance.
    $rsParams = @{
        target = $target
    }

    # Create a powershell instance in the runspace pool and add properties such as the scriptblock to run and parameters
    $psRunscpace = [powershell]::Create()
    $psRunscpace.RunspacePool = $runspacePool
    [void]$psRunscpace.AddScript($rsScriptBlock)
    [void]$psRunscpace.AddParameters($rsParams)

    # In the hash below we are basically putting the powershell runspace object and the invocation output into an object.
    # This technique allows us to keep the job and the output associated in the same object.
    # Basically, if the property for the runspace has iscomplete true... then let's check the output in the while statement
    $rsJobs += @{
        Runspace = $psRunscpace
        State = $psRunscpace.BeginInvoke()
        Processed = $false
    }
}
while ($rsJobs.State.IsCompleted -contains $false) {
    # Note: All the runspaces above are created as soon as possible. And then the pool activates threads according to the limit.
    # If we have a large number of threads (1000s 1000000s), and we think reviewing all of the jobs is slowing things down, we can raise the $rsMSecondWaitCheck
    Start-Sleep -Milliseconds $rsMSecondWaitCheck
    foreach ($job in $rsJobs){
        if ($job.State.IsCompleted -and !$job.Processed){
            # This is where we get the return. We can record it or do some work with the results.
            # We are adding each result to an array of results
            $rsResults += $job.Runspace.EndInvoke($job.State)
            $job.Runspace.Dispose()
            $job.Processed = $true
        }
    }
}

$rsResults | Out-GridView
$rsResults | convertto-json -depth 100 | set-content -Path $jsonoutput
notepad.exe $jsonoutput

$RunspacePool.Dispose()