$rsThreadCount = 5
$rsMSecondWaitCheck = 300
$runspacePool = [runspacefactory]::CreateRunspacePool(1, $rsThreadCount)
$runspacePool.Open()
$rsJobs = @()
$rsScriptBlock = {
    Param ($x)
    sleep 3
    return "Passed Value: $x and a Random Value: $(Get-Random)"
}

1..20 | Foreach-Object {
        $rsParams = @{
            x = "value1"
        }
        $powerShell = [powershell]::Create()
        $powerShell.RunspacePool = $runspacePool
        $powerShell.AddScript($rsScriptBlock)
        $powerShell.AddParameters($rsParams)
        $rsJobs += @{
            Runspace = $powershell
            State = $powerShell.BeginInvoke()
            Processed = $false
        }
}
while ($rsJobs.State.IsCompleted -contains $false) {
    Start-Sleep -Milliseconds $rsMSecondWaitCheck
    foreach ($job in $rsJobs){
        if ($job.State.IsCompleted -and !$job.Processed){
            # This is where we get the return. We can record it or do some work with the results.
            $job.Runspace.EndInvoke($job.State)
            $job.Runspace.Dispose()
            $job.Processed = $true
        }
    }
}

$RunspacePool.Dispose()