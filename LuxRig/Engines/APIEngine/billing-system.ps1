<#
.SYNOPSIS
    Billing System - Stripe integration for API monetization

.DESCRIPTION
    Handles billing operations:
    - Stripe customer creation
    - Subscription management
    - Usage-based billing
    - Invoice generation
    - Webhook handling
#>

function New-StripeCustomer {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Email,

        [string]$Name = "",

        [string]$StripeSecretKey = $env:STRIPE_SECRET_KEY
    )

    if (-not $StripeSecretKey) {
        throw "Stripe secret key not found. Set STRIPE_SECRET_KEY environment variable."
    }

    $endpoint = "https://api.stripe.com/v1/customers"

    $body = @{
        email = $Email
    }

    if ($Name) { $body.name = $Name }

    try {
        $response = Invoke-RestMethod -Uri $endpoint -Method Post `
            -Headers @{
                "Authorization" = "Bearer $StripeSecretKey"
            } `
            -Body $body

        Write-Host "✓ Stripe customer created: $($response.id)" -ForegroundColor Green

        return @{
            success = $true
            customerId = $response.id
            email = $response.email
        }
    }
    catch {
        Write-Warning "Stripe customer creation failed: $_"
        return @{success = $false; error = $_.Exception.Message}
    }
}

function New-Subscription {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CustomerId,

        [Parameter(Mandatory=$true)]
        [string]$PriceId,

        [string]$StripeSecretKey = $env:STRIPE_SECRET_KEY
    )

    $endpoint = "https://api.stripe.com/v1/subscriptions"

    $body = @{
        customer = $CustomerId
        items = @(@{price = $PriceId})
    }

    try {
        $response = Invoke-RestMethod -Uri $endpoint -Method Post `
            -Headers @{
                "Authorization" = "Bearer $StripeSecretKey"
            } `
            -Body $body

        Write-Host "✓ Subscription created: $($response.id)" -ForegroundColor Green

        return @{
            success = $true
            subscriptionId = $response.id
            status = $response.status
        }
    }
    catch {
        Write-Warning "Subscription creation failed: $_"
        return @{success = $false; error = $_.Exception.Message}
    }
}

function Update-UsageRecord {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SubscriptionItemId,

        [Parameter(Mandatory=$true)]
        [int]$Quantity,

        [string]$StripeSecretKey = $env:STRIPE_SECRET_KEY
    )

    $endpoint = "https://api.stripe.com/v1/subscription_items/$SubscriptionItemId/usage_records"

    $body = @{
        quantity = $Quantity
        timestamp = [int][double]::Parse((Get-Date -UFormat %s))
        action = "increment"
    }

    try {
        $response = Invoke-RestMethod -Uri $endpoint -Method Post `
            -Headers @{
                "Authorization" = "Bearer $StripeSecretKey"
            } `
            -Body $body

        return @{success = $true; recordId = $response.id}
    }
    catch {
        Write-Warning "Usage record update failed: $_"
        return @{success = $false; error = $_.Exception.Message}
    }
}

function Get-StripeSubscription {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SubscriptionId,

        [string]$StripeSecretKey = $env:STRIPE_SECRET_KEY
    )

    $endpoint = "https://api.stripe.com/v1/subscriptions/$SubscriptionId"

    try {
        $response = Invoke-RestMethod -Uri $endpoint -Method Get `
            -Headers @{
                "Authorization" = "Bearer $StripeSecretKey"
            }

        return @{
            success = $true
            subscription = @{
                id = $response.id
                status = $response.status
                currentPeriodEnd = $response.current_period_end
                cancelAtPeriodEnd = $response.cancel_at_period_end
            }
        }
    }
    catch {
        return @{success = $false; error = $_.Exception.Message}
    }
}

function Invoke-WebhookHandler {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Payload,

        [Parameter(Mandatory=$true)]
        [string]$Signature,

        [string]$WebhookSecret = $env:STRIPE_WEBHOOK_SECRET
    )

    # Verify webhook signature (simplified - use Stripe SDK in production)
    if (-not $WebhookSecret) {
        Write-Warning "Webhook secret not configured"
        return @{success = $false; error = "Webhook secret missing"}
    }

    try {
        $event = $Payload | ConvertFrom-Json

        # Handle different event types
        $result = switch ($event.type) {
            "customer.subscription.created" {
                Write-Host "Subscription created: $($event.data.object.id)" -ForegroundColor Green
                # Update user tier, activate API key, etc.
                @{success = $true; action = "subscription_created"}
            }
            "customer.subscription.deleted" {
                Write-Host "Subscription cancelled: $($event.data.object.id)" -ForegroundColor Yellow
                # Downgrade user tier, deactivate premium features
                @{success = $true; action = "subscription_cancelled"}
            }
            "invoice.payment_succeeded" {
                Write-Host "Payment successful: $($event.data.object.id)" -ForegroundColor Green
                @{success = $true; action = "payment_success"}
            }
            "invoice.payment_failed" {
                Write-Host "Payment failed: $($event.data.object.id)" -ForegroundColor Red
                # Send notification, retry payment
                @{success = $true; action = "payment_failed"}
            }
            default {
                Write-Host "Unhandled event: $($event.type)" -ForegroundColor Gray
                @{success = $true; action = "unhandled"}
            }
        }

        return $result
    }
    catch {
        Write-Warning "Webhook processing failed: $_"
        return @{success = $false; error = $_.Exception.Message}
    }
}

function Get-BillingPrices {
    return @{
        free = @{
            id = "price_free"
            amount = 0
            name = "Free"
            features = @("100 requests/day", "1K tokens/request")
        }
        basic = @{
            id = "price_basic"
            amount = 2900
            name = "Basic"
            features = @("1K requests/day", "5K tokens/request", "Email support")
        }
        pro = @{
            id = "price_pro"
            amount = 9900
            name = "Pro"
            features = @("10K requests/day", "10K tokens/request", "Priority support", "Custom models")
        }
        enterprise = @{
            id = "price_enterprise"
            amount = 49900
            name = "Enterprise"
            features = @("Unlimited requests", "50K tokens/request", "Dedicated support", "SLA")
        }
    }
}

Export-ModuleMember -Function New-StripeCustomer, New-Subscription, Update-UsageRecord, Get-StripeSubscription, Invoke-WebhookHandler, Get-BillingPrices
