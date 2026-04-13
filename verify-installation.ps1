# Verification script for Windows
# Run with: .\verify-installation.ps1

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Installation Verification Script" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$allPassed = $true

function Test-Tool {
    param(
        [string]$ToolName,
        [string]$Command,
        [string]$ExpectedPattern
    )
    
    Write-Host "[*] Testing: $ToolName" -ForegroundColor Yellow
    
    try {
        $result = & cmd /c "$Command 2>&1"
        
        if ($result -match $ExpectedPattern) {
            Write-Host "    [OK] Installed" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "    [FAIL] Not found" -ForegroundColor Red
            $script:allPassed = $false
            return $false
        }
    }
    catch {
        Write-Host "    [FAIL] Error: $_" -ForegroundColor Red
        $script:allPassed = $false
        return $false
    }
}

Write-Host "CORE TOOLS:" -ForegroundColor Cyan
Write-Host "==========" -ForegroundColor Cyan

Test-Tool "Git" "git --version" "git version"
Test-Tool "Node.js" "node --version" "v\d+"
Test-Tool "npm" "npm --version" "\d+\.\d+\.\d+"
Test-Tool "Python" "python --version" "Python 3\."
Test-Tool "pip" "python -m pip --version" "pip \d+"

Write-Host "`nDOCKER TOOLS:" -ForegroundColor Cyan
Write-Host "=============" -ForegroundColor Cyan

Test-Tool "Docker" "docker --version" "Docker version"

Write-Host "`nKUBERNETES TOOLS:" -ForegroundColor Cyan
Write-Host "=================" -ForegroundColor Cyan

Test-Tool "kubectl" "kubectl version --client" "Client Version"
Test-Tool "Minikube" "minikube version" "minikube version"

Write-Host "`nCLOUD TOOLS:" -ForegroundColor Cyan
Write-Host "============" -ForegroundColor Cyan

Test-Tool "AWS CLI" "aws --version" "aws-cli"

Write-Host "`n========================================" -ForegroundColor Cyan

if ($allPassed) {
    Write-Host "`n[SUCCESS] All tools installed!" -ForegroundColor Green
    Write-Host "Ready to proceed with project setup.`n" -ForegroundColor Green
}
else {
    Write-Host "`n[WARNING] Some tools missing or not working!" -ForegroundColor Red
    Write-Host "Check INSTALLATION_GUIDE.md for troubleshooting.`n" -ForegroundColor Yellow
}

Write-Host "========================================`n" -ForegroundColor Cyan
