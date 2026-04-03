BeforeAll {
  $modulePath = Join-Path $PSScriptRoot '..' '..' 'modules' 'FabricArchiveBotCore.psm1'
  Import-Module $modulePath -Force
}

Describe 'Invoke-FABRateLimitedOperation - Retry Behavior' {
  BeforeEach {
    Initialize-FABLogging
    Mock Start-Sleep { } -ModuleName FabricArchiveBotCore
  }

  It 'Should retry on 429 rate limit errors and eventually succeed' {
    $counterFile = Join-Path $TestDrive 'retry429.txt'
    '0' | Out-File $counterFile
    # Capture path as a simple string for the closure
    $path = $counterFile

    $result = Invoke-FABRateLimitedOperation -Operation {
      $c = [int](Get-Content $path)
      $c++
      $c.ToString() | Out-File $path
      if ($c -lt 3) { throw '429 Too Many Requests' }
      return 'success'
    } -OperationName 'RetryTest' -MaxRetries 3 -BaseDelaySeconds 1

    $result | Should -Be 'success'
    [int](Get-Content $counterFile) | Should -Be 3
  }

  It 'Should retry on transient 503 errors' {
    $counterFile = Join-Path $TestDrive 'retry503.txt'
    '0' | Out-File $counterFile
    $path = $counterFile

    $result = Invoke-FABRateLimitedOperation -Operation {
      $c = [int](Get-Content $path)
      $c++
      $c.ToString() | Out-File $path
      if ($c -lt 2) { throw '503 Service Unavailable' }
      return 'recovered'
    } -OperationName 'TransientTest' -MaxRetries 3 -BaseDelaySeconds 1

    $result | Should -Be 'recovered'
    [int](Get-Content $counterFile) | Should -Be 2
  }

  It 'Should throw after exhausting retries on rate limit' {
    { Invoke-FABRateLimitedOperation -Operation { throw '429 Too Many Requests' } -OperationName 'ExhaustedTest' -MaxRetries 2 -BaseDelaySeconds 1 } | Should -Throw '*429*'
  }

  It 'Should not retry non-retryable errors' {
    $counterFile = Join-Path $TestDrive 'nonretry.txt'
    '0' | Out-File $counterFile
    $path = $counterFile

    { Invoke-FABRateLimitedOperation -Operation {
      $c = [int](Get-Content $path)
      $c++
      $c.ToString() | Out-File $path
      throw 'Unauthorized: Invalid credentials'
    } -OperationName 'NonRetryTest' -MaxRetries 3 -BaseDelaySeconds 1 } | Should -Throw '*Unauthorized*'

    [int](Get-Content $counterFile) | Should -Be 1
  }

  It 'Should use config-based retry settings when provided' {
    $config = [PSCustomObject]@{
      FabricPSPBIPSettings = [PSCustomObject]@{
        RateLimitSettings = [PSCustomObject]@{
          MaxRetries        = 1
          RetryDelaySeconds = 5
          BackoffMultiplier = 3
        }
      }
    }

    $counterFile = Join-Path $TestDrive 'configretry.txt'
    '0' | Out-File $counterFile
    $path = $counterFile

    { Invoke-FABRateLimitedOperation -Operation {
      $c = [int](Get-Content $path)
      $c++
      $c.ToString() | Out-File $path
      throw '429 Rate Limit'
    } -Config $config -OperationName 'ConfigRetryTest' } | Should -Throw

    # MaxRetries=1: initial call + 1 retry = 2
    [int](Get-Content $counterFile) | Should -Be 2
  }

  It 'Should throw after exhausting retries on transient errors' {
    { Invoke-FABRateLimitedOperation -Operation { throw '503 Service Unavailable' } -OperationName 'TransientExhaust' -MaxRetries 1 -BaseDelaySeconds 1 } | Should -Throw '*503*'
  }
}
