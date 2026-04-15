# Deployment Status Monitoring Script (PowerShell)
# Run periodically to track EC2 node provisioning and pod scheduling

param(
    [switch]$Watch = $false,
    [int]$Interval = 30
)

# Configuration
$CLUSTER_NAME = "ai-chatbot-cluster"
$NODE_GROUP_NAME = "ai-chatbot-node-group"
$REGION = "ap-southeast-2"
$NAMESPACE = "chatbot"

# Color functions
function Write-Header { 
    Write-Host $args[0] -ForegroundColor Cyan 
}
function Write-Success { 
    Write-Host $args[0] -ForegroundColor Green 
}
function Write-StatusWarn { 
    Write-Host $args[0] -ForegroundColor Yellow 
}
function Write-StatusError { 
    Write-Host $args[0] -ForegroundColor Red 
}
function Write-Info { 
    Write-Host $args[0] -ForegroundColor White 
}

# Main monitoring function
function Get-DeploymentStatus {
    Clear-Host
    Write-Header "════════════════════════════════════════════════════"
    Write-Header "  AI Chatbot Deployment Status Monitor"
    Write-Info "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Header "════════════════════════════════════════════════════`n"

    # Phase 1: Check Node Group Status
    Write-Warning "[Phase 1] Node Group Status:"
    try {
        $nodeGroupStatus = aws eks describe-nodegroup `
            --cluster-name $CLUSTER_NAME `
            --nodegroup-name $NODE_GROUP_NAME `
            --region $REGION `
            --output json | ConvertFrom-Json

        $status = $nodeGroupStatus.nodegroup.status
        $desiredSize = $nodeGroupStatus.nodegroup.scalingConfig.desiredSize
        $createdAt = $nodeGroupStatus.nodegroup.createdAt

        if ($status -eq "ACTIVE") {
            Write-Success "✓ Node Group Status: $status"
        } else {
            Write-Warning "⏳ Node Group Status: $status"
        }

        Write-Info "   Created: $createdAt"
        Write-Info "   Desired Size: $desiredSize"

        # Calculate elapsed time
        $createdTime = [DateTime]::Parse($createdAt)
        $elapsed = [DateTime]::UtcNow - $createdTime.ToUniversalTime()
        $elapsedMin = [int]$elapsed.TotalMinutes
        $elapsedSec = [int]$elapsed.Seconds
        Write-Info "   Elapsed Time: ${elapsedMin}m ${elapsedSec}s"
    } catch {
        Write-Error "   Error fetching node group status: $_"
    }
    Write-Host ""

    # Phase 2: Check Pod Status
    Write-Warning "[Phase 2] Kubernetes Pod Status:"
    try {
        $pods = kubectl get pods -n $NAMESPACE -o json | ConvertFrom-Json -ErrorAction SilentlyContinue
        
        if ($pods -and $pods.items) {
            $totalPods = @($pods.items).Count
            $runningPods = @($pods.items | Where-Object { $_.status.phase -eq "Running" }).Count
            $pendingPods = $totalPods - $runningPods

            if ($runningPods -eq $totalPods -and $totalPods -gt 0) {
                Write-Success "✓ All pods running: $runningPods/$totalPods"
            } elseif ($pendingPods -gt 0) {
                Write-Warning "⏳ Pods running: $runningPods/$totalPods (Pending: $pendingPods)"
            } else {
                Write-Error "✗ No pods found"
            }

            # Display pod table
            $pods.items | Select-Object `
                @{Name="NAME"; Expression={$_.metadata.name}},
                @{Name="READY"; Expression={$_.status.containerStatuses[0].ready}},
                @{Name="STATUS"; Expression={$_.status.phase}},
                @{Name="RESTARTS"; Expression={$_.status.containerStatuses[0].restartCount}},
                @{Name="AGE"; Expression={(Get-Date) - [DateTime]::Parse($_.metadata.creationTimestamp)}} | `
                Format-Table -AutoSize | `
                ForEach-Object { "   $_" }
        } else {
            Write-Warning "   ⏳ No pods found yet"
        }
    } catch {
        Write-Warning "   (kubectl not configured or not found)"
    }
    Write-Host ""

    # Phase 3: Check Services
    Write-Warning "[Phase 3] Kubernetes Services:"
    try {
        $services = kubectl get svc -n $NAMESPACE -o json | ConvertFrom-Json -ErrorAction SilentlyContinue
        
        if ($services -and $services.items) {
            $services.items | Select-Object `
                @{Name="NAME"; Expression={$_.metadata.name}},
                @{Name="TYPE"; Expression={$_.spec.type}},
                @{Name="CLUSTER-IP"; Expression={$_.spec.clusterIP}},
                @{Name="EXTERNAL-IP"; Expression={if ($_.status.loadBalancer.ingress) { $_.status.loadBalancer.ingress[0].hostname } else { "Pending" }}} | `
                Format-Table -AutoSize | `
                ForEach-Object { "   $_" }

            # Check frontend LoadBalancer IP
            $frontendSvc = $services.items | Where-Object { $_.metadata.name -eq "frontend-service" }
            if ($frontendSvc -and $frontendSvc.status.loadBalancer.ingress) {
                $ip = $frontendSvc.status.loadBalancer.ingress[0].hostname
                Write-Success "   ✓ Frontend IP: $ip"
            } else {
                Write-Warning "   ⏳ Frontend IP: Pending assignment"
            }
        } else {
            Write-Warning "   ⏳ No services created yet"
        }
    } catch {
        Write-Warning "   (kubectl not configured)"
    }
    Write-Host ""

    # Phase 4: Check Deployments
    Write-Warning "[Phase 4] Kubernetes Deployments:"
    try {
        $deployments = kubectl get deployment -n $NAMESPACE -o json | ConvertFrom-Json -ErrorAction SilentlyContinue
        
        if ($deployments -and $deployments.items) {
            $deployments.items | Select-Object `
                @{Name="NAME"; Expression={$_.metadata.name}},
                @{Name="DESIRED"; Expression={$_.spec.replicas}},
                @{Name="CURRENT"; Expression={$_.status.replicas}},
                @{Name="READY"; Expression={$_.status.readyReplicas}} | `
                Format-Table -AutoSize | `
                ForEach-Object { "   $_" }
        } else {
            Write-Warning "   ⏳ No deployments found yet"
        }
    } catch {
        Write-Warning "   (kubectl not configured)"
    }
    Write-Host ""

    # Phase 5: Check Nodes
    Write-Warning "[Phase 5] Kubernetes Nodes:"
    try {
        $nodes = kubectl get nodes -o json | ConvertFrom-Json -ErrorAction SilentlyContinue
        
        if ($nodes -and $nodes.items) {
            $nodes.items | Select-Object `
                @{Name="NAME"; Expression={$_.metadata.name}},
                @{Name="STATUS"; Expression={$_.status.conditions | Where-Object { $_.type -eq "Ready" } | Select-Object -ExpandProperty status}},
                @{Name="ROLES"; Expression={$_.metadata.labels."node.kubernetes.io/instance-type"}} | `
                Format-Table -AutoSize | `
                ForEach-Object { "   $_" }
        } else {
            Write-Warning "   ⏳ No worker nodes active yet"
        }
    } catch {
        Write-Warning "   (kubectl not configured)"
    }
    Write-Host ""

    Write-Header "════════════════════════════════════════════════════"
    Write-Warning "Summary:"
    Write-Info "Status: $status | Desired: $desiredSize | Pods: $runningPods/$totalPods (if available)"
    Write-Header "════════════════════════════════════════════════════`n"
}

# Main loop
if ($Watch) {
    Write-Info "Watch mode enabled. Press Ctrl+C to exit. Updating every $Interval seconds...`n"
    while ($true) {
        Get-DeploymentStatus
        Start-Sleep -Seconds $Interval
    }
} else {
    Get-DeploymentStatus
    Write-Info "`nTip: Run with -Watch flag to auto-refresh: .\scripts\monitor-deployment.ps1 -Watch -Interval 30"
}
