BeforeAll {
  $modulePath = Join-Path $PSScriptRoot '..' '..' 'modules' 'FabricArchiveBotCore.psm1'
  Import-Module $modulePath -Force
}

Describe 'Find-FABDefinitionEndpoints' {
  It 'Should find item types from a well-formed TOC node' {
    $tocNode = [PSCustomObject]@{
      toc_title = 'Fabric REST API'
      children  = @(
        [PSCustomObject]@{
          toc_title = 'Report'
          children  = @(
            [PSCustomObject]@{
              toc_title = 'Items'
              children  = @(
                [PSCustomObject]@{ toc_title = 'Get Report Definition' }
                [PSCustomObject]@{ toc_title = 'Update Report Definition' }
              )
            }
          )
        }
        [PSCustomObject]@{
          toc_title = 'SemanticModel'
          children  = @(
            [PSCustomObject]@{
              toc_title = 'Items'
              children  = @(
                [PSCustomObject]@{ toc_title = 'Get SemanticModel Definition' }
              )
            }
          )
        }
      )
    }

    $results = Find-FABDefinitionEndpoints -Node $tocNode -ParentPath @()
    $results | Should -Contain 'Report'
    $results | Should -Contain 'SemanticModel'
  }

  It 'Should skip nodes that do not follow the ItemType -> Items -> Definition pattern' {
    $tocNode = [PSCustomObject]@{
      toc_title = 'Admin'
      children  = @(
        [PSCustomObject]@{
          toc_title = 'Get Admin Definition'
        }
      )
    }

    $results = Find-FABDefinitionEndpoints -Node $tocNode -ParentPath @()
    $results | Should -BeNullOrEmpty
  }

  It 'Should handle empty children gracefully' {
    $tocNode = [PSCustomObject]@{
      toc_title = 'Empty'
      children  = @()
    }

    $results = Find-FABDefinitionEndpoints -Node $tocNode -ParentPath @()
    $results | Should -BeNullOrEmpty
  }
}

Describe 'Get-FABSupportedItemTypes' {
  Context 'With mocked HTTP response' {
    BeforeAll {
      # Build a realistic TOC structure
      $mockTocResponse = [PSCustomObject]@{
        items = @(
          [PSCustomObject]@{
            toc_title = 'Notebook'
            children  = @(
              [PSCustomObject]@{
                toc_title = 'Items'
                children  = @(
                  [PSCustomObject]@{ toc_title = 'Get Notebook Definition' }
                )
              }
            )
          }
          [PSCustomObject]@{
            toc_title = 'Report'
            children  = @(
              [PSCustomObject]@{
                toc_title = 'Items'
                children  = @(
                  [PSCustomObject]@{ toc_title = 'Get Report Definition' }
                )
              }
            )
          }
          [PSCustomObject]@{
            toc_title = 'Environment'
            children  = @(
              [PSCustomObject]@{
                toc_title = 'Items'
                children  = @(
                  [PSCustomObject]@{ toc_title = 'Get Environment Definition' }
                )
              }
            )
          }
        )
      }
    }

    It 'Should parse item types from a mocked TOC response' {
      Mock Invoke-RestMethod { $mockTocResponse }
      $result = Get-FABSupportedItemTypes
      $result | Should -Contain 'Report'
      $result | Should -Contain 'Notebook'
      $result | Should -Contain 'Environment'
    }

    It 'Should filter out non-item types like Core, Admin, Spark' {
      $tocWithNonItems = [PSCustomObject]@{
        items = @(
          [PSCustomObject]@{
            toc_title = 'Core'
            children  = @(
              [PSCustomObject]@{
                toc_title = 'Items'
                children  = @(
                  [PSCustomObject]@{ toc_title = 'Get Core Definition' }
                )
              }
            )
          }
          [PSCustomObject]@{
            toc_title = 'Report'
            children  = @(
              [PSCustomObject]@{
                toc_title = 'Items'
                children  = @(
                  [PSCustomObject]@{ toc_title = 'Get Report Definition' }
                )
              }
            )
          }
        )
      }

      Mock Invoke-RestMethod { $tocWithNonItems }
      $result = Get-FABSupportedItemTypes
      $result | Should -Contain 'Report'
      $result | Should -Not -Contain 'Core'
    }
  }

  Context 'Fallback behavior' {
    It 'Should return fallback types when HTTP request fails' {
      Mock Invoke-RestMethod { throw 'Network error' }
      $result = Get-FABSupportedItemTypes
      $result | Should -Not -BeNullOrEmpty
      $result | Should -Contain 'Report'
      $result | Should -Contain 'SemanticModel'
    }

    It 'Should return fallback types when TOC has no known types' {
      $emptyToc = [PSCustomObject]@{
        items = @(
          [PSCustomObject]@{
            toc_title = 'UnknownThing'
            children  = @(
              [PSCustomObject]@{
                toc_title = 'Items'
                children  = @(
                  [PSCustomObject]@{ toc_title = 'Get UnknownThing Definition' }
                )
              }
            )
          }
        )
      }

      Mock Invoke-RestMethod { $emptyToc }
      $result = Get-FABSupportedItemTypes
      # Should fall back since no known types (Report, SemanticModel, etc.) found
      $result | Should -Contain 'Report'
    }
  }

  Context 'Caching' {
    It 'Should use cache when available and fresh' {
      $cacheFile = Join-Path $env:TEMP 'FABSupportedItemTypes.json'

      # Write a fresh cache file
      @('Report', 'CachedType') | ConvertTo-Json -Compress | Out-File $cacheFile -Encoding UTF8
      # Touch the file to make it fresh
      (Get-Item $cacheFile).LastWriteTime = Get-Date

      $result = Get-FABSupportedItemTypes -UseCache -CacheHours 24
      $result | Should -Contain 'CachedType'

      # Cleanup
      Remove-Item $cacheFile -ErrorAction SilentlyContinue
    }
  }
}
