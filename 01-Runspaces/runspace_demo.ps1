# Variables
$rsThreadCount = 5
$rsMSecondWaitCheck = 300

# Initiate a Runspace Pool
$runspacePool = [runspacefactory]::CreateRunspacePool(1, $rsThreadCount)
$runspacePool.Open()
$rsJobs = @()

# This is the scriptblock that is going to run. In this example we get an input parameter, set a random sleep time and then return a message with the values.
$rsScriptBlock = {
    Param ($x)
    $secondsWait = Get-Random -Maximum 5 -Minimum 1
    start-sleep $secondsWait
    return "Passed Iteration Value: $x | Random Wait(Sec): $secondsWait | Date: $(Get-Date)"
}

1..20 | Foreach-Object {

    # Set a hash for splatting params. We will send the current iteration value to the next runspace instance.
    $rsParams = @{
        x = $_
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
            # NOTE: maybe we don't want to process each result as it comes in... we can set up another loop to process $rsJobs later
            $job.Runspace.EndInvoke($job.State)
            $job.Runspace.Dispose()
            $job.Processed = $true
        }
    }
}

$RunspacePool.Dispose()