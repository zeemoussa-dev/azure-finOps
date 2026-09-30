# Azure FinOps views pack

12 shared Cost analysis views plus 10 Resource Graph queries, grouped by FinOps area.

| # | View | Metric | Chart | What it answers |
|---|------|--------|-------|-----------------|
| **Showback / chargeback** |||||
| 01 | Showback by cost center (MTD) | Amortized | Stacked column, daily | Who is spending this month? |
| 02 | Cost by application (YTD monthly) | Amortized | Table | Month-by-month cost per workload |
| 03 | Cost by subscription & RG (MTD) | Amortized | Table | Where the spend sits structurally |
| 04 | Cost by environment (MTD) | Amortized | Stacked column | Prod vs non-prod split |
| **Trends & anomalies** |||||
| 05 | Run-rate vs forecast & budget | Actual | Area, cumulative | Will we land on budget this month? |
| 06 | Daily cost by service – spike finder | Actual | Stacked column, daily | Which service jumped, and on which day? |
| 07 | Monthly trend by service (YTD) | Amortized | Stacked column, monthly | Longer-term growth by service |
| **Commitment savings** |||||
| 08 | Cost by pricing model | Amortized | Stacked column | Coverage: on-demand vs reservation vs savings plan vs spot |
| 09 | Unused reservations & savings plans | Amortized | Stacked column | Commitment waste (unused hours) |
| 10 | On-demand compute – commitment candidates | Amortized | Table | Steady on-demand spend worth covering |
| **Waste & optimisation** |||||
| 11 | Tagging gaps | Amortized | Table | Spend with no cost-center tag (the "untagged" row) |
| 12 | Top resources by cost | Amortized | Table | Top resources to right-size first |

`waste-queries.kql` covers what the cost views can't: unattached disks, orphaned public IPs and NICs, deallocated VMs, empty App Service plans and load balancers, old snapshots, untagged resource counts, and Advisor cost recommendations with estimated savings.

## Deploy

Before you start, you need **Cost Management Contributor** (or Contributor) on the target scope.

```powershell
# PowerShell 7+ (Az module)
./Deploy-FinOpsViews.ps1 -Scope "/subscriptions/<subId>" `
    -CostCenterTag "CostCenter" -AppTag "Application" -EnvTag "Environment" `
    -BudgetId "/subscriptions/<subId>/providers/Microsoft.Consumption/budgets/<name>"   # optional
```

```bash
# Azure CLI + jq
./deploy-finops-views.sh /subscriptions/<subId> CostCenter Application Environment [budgetId]
```

Supported scopes:

- `/subscriptions/<id>`
- `/subscriptions/<id>/resourceGroups/<rg>`
- `/providers/Microsoft.Management/managementGroups/<id>`
- `/providers/Microsoft.Billing/billingAccounts/<id>`

The views show up as **shared** views under Cost analysis at that scope. Re-running the script updates them in place, because each view has a fixed name.

## Notes

- **Tag names:** tag keys are placeholders (`__COSTCENTER_TAG__`, `__APP_TAG__`, `__ENV_TAG__`) that the scripts replace. Tag keys are case-sensitive in cost data, so match what your policy enforces.
- **Budget KPI:** if you don't pass `-BudgetId`, the budget KPI is removed and only the forecast KPI stays.
- **Date ranges:** the API supports only WeekToDate, MonthToDate, YearToDate, or Custom with fixed dates. For rolling windows like "last 3 months", change the date picker in the portal and click **Save**.
- **Management-group scope:** views and filters by `PricingModel`, `BenefitName`, and `ChargeType` need an EA or MCA billing relationship. On PAYG or CSP subscriptions, views 08–10 may return less data.
- **Unused commitments:** views 08–10 use the **Amortized** metric on purpose, because unused reservation and savings-plan charges only show up as their own line items under amortized cost. Utilization % itself is on the Reservations and Savings plans blades.
- **Dimension names:** if a dimension is rejected in your tenant (for example `BenefitName` on older agreements), remove it from that view's `pivots` and re-run.
- **API version:** defaults to `2023-11-01`. Override it with `-ApiVersion` or `API_VERSION`. The latest published version is `2026-06-01`.

## Next steps

- **Alerts:** add anomaly alerts per subscription (Cost analysis → Anomaly alert) and budget alerts at 80%, 100%, and 110% forecast.
- **Reporting:** set up a scheduled FOCUS export to storage, which feeds Power BI or FinOps hubs later if you outgrow portal views.
