<#
.SYNOPSIS
  Deploys the FinOps Cost Management views as SHARED views at a given scope.

.EXAMPLE
  # Subscription scope
  ./Deploy-FinOpsViews.ps1 -Scope "/subscriptions/<subId>"

  # Management group scope, custom tag names, with a budget KPI
  ./Deploy-FinOpsViews.ps1 -Scope "/providers/Microsoft.Management/managementGroups/<mgId>" `
      -CostCenterTag "cost-center" -AppTag "workload" -EnvTag "env" `
      -BudgetId "/subscriptions/<subId>/providers/Microsoft.Consumption/budgets/<budgetName>"

  # Preview only
  ./Deploy-FinOpsViews.ps1 -Scope "/subscriptions/<subId>" -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string] $Scope,
    [string] $CostCenterTag = "CostCenter",
    [string] $AppTag        = "Application",
    [string] $EnvTag        = "Environment",
    [string] $BudgetId      = "",            # optional: full resource ID of a Consumption budget
    [string] $ApiVersion    = "2023-11-01",
    [string] $ViewsPath     = (Join-Path $PSScriptRoot "views")
)

$ErrorActionPreference = "Stop"
if (-not (Get-AzContext)) { Connect-AzAccount | Out-Null }

$Scope = $Scope.TrimEnd('/')
$ok = 0; $failed = 0

Get-ChildItem -Path $ViewsPath -Filter *.json | Sort-Object Name | ForEach-Object {
    $viewName = $_.BaseName
    $raw = Get-Content $_.FullName -Raw
    $raw = $raw.Replace("__COSTCENTER_TAG__", $CostCenterTag).
                Replace("__APP_TAG__", $AppTag).
                Replace("__ENV_TAG__", $EnvTag)

    $body = $raw | ConvertFrom-Json -Depth 20

    # Budget KPI: wire it up if a budget was given, otherwise remove it.
    if ($body.properties.kpis) {
        if ($BudgetId) {
            ($body.properties.kpis | Where-Object type -eq "Budget").id = $BudgetId
        } else {
            $body.properties.kpis = @($body.properties.kpis | Where-Object type -ne "Budget")
        }
    }

    $json = $body | ConvertTo-Json -Depth 20
    $path = "$Scope/providers/Microsoft.CostManagement/views/$viewName`?api-version=$ApiVersion"

    if ($PSCmdlet.ShouldProcess("$Scope", "Create/update view '$($body.properties.displayName)'")) {
        $resp = Invoke-AzRestMethod -Method PUT -Path $path -Payload $json
        if ($resp.StatusCode -in 200, 201) {
            Write-Host "  [OK]   $viewName" -ForegroundColor Green; $ok++
        } else {
            Write-Host "  [FAIL] $viewName -> $($resp.StatusCode) $($resp.Content)" -ForegroundColor Red; $failed++
        }
    }
}

Write-Host "`nDone: $ok deployed, $failed failed."
Write-Host "Open: Cost Management > Cost analysis > (scope) > 'All views' > Shared views."
