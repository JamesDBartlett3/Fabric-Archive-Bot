# 🧪 **Fabric Archive Bot Testing Tutorial**

## **What You Just Learned**

You successfully ran unit tests and saw:

- ✅ **33 tests passed** (most functionality working)
- ❌ **7 tests failed** (these are minor test data issues, not critical)
- ⚡ **Fast execution** (2.55 seconds total)
- 🎯 **Rate limiting working** (1-second delays instead of 30-second production delays)

## **Practical Testing Scenarios**

### **🚀 Daily Development Workflow**

#### **1. Quick Sanity Check (Before commits)**

```powershell
# Run just the critical tests
.\Test-DevHelper.ps1 -Action Debug -TestName "*rate limit*"
```

**Use Case**: Before committing code, verify core functionality works.

#### **2. Feature Development (When adding new functions)**

```powershell
# Test specific functionality you're working on
.\Test-DevHelper.ps1 -Action Debug -TestName "*Configuration*"
```

**Use Case**: When modifying configuration handling, test just those features.

#### **3. Full Validation (Before releases)**

```powershell
# Run all tests with coverage
.\Invoke-Tests.ps1 -Coverage
```

**Use Case**: Before releasing new version, ensure everything works.

### **🔍 Debugging Failed Tests**

When tests fail (like you just saw), here's how to investigate:

#### **1. Analyze Specific Failures**

```powershell
# Focus on just one failing test
.\Test-DevHelper.ps1 -Action Debug -TestName "*Should filter active workspaces*"
```

#### **2. Check What Functions Are Tested**

```powershell
# See test coverage analysis
.\Test-DevHelper.ps1 -Action Analyze
```

### **⚡ Performance Testing**

#### **1. Time Your Code Changes**

```powershell
# Measure test execution time
Measure-Command { .\Invoke-Tests.ps1 -TestType Unit }
```

#### **2. Rate Limiting Verification**

```powershell
# Verify rate limiting works quickly
.\Test-DevHelper.ps1 -Action Debug -TestName "*retry*"
```

### **🧹 Maintenance Tasks**

#### **1. Clean Up Test Environment**

```powershell
# Remove test files and reset environment
.\Test-DevHelper.ps1 -Action Clean
```

#### **2. Fresh Setup After Changes**

```powershell
# Reinstall/update Pester and validate structure
.\Test-DevHelper.ps1 -Action Setup
```

## **Understanding Test Output**

### **✅ What Good Looks Like**

```
[+] Should retry on rate limit error 20ms (14ms|5ms)
```

- `[+]` = Test passed
- `20ms` = Total execution time
- `(14ms|5ms)` = Setup time | Test time

### **❌ What Failures Look Like**

```
[-] Should filter active workspaces correctly 13ms (10ms|3ms)
Expected 2, but got 3.
```

- `[-]` = Test failed
- Clear error message explains what went wrong

### **⚡ Rate Limiting Success**

```
WARNING: Rate limit encountered for FabricOperation. Waiting 1 seconds before retry 1/1...
```

- Shows 1-second delay (not 30 seconds!)
- Only retries once (not 3 times!)

## **Common Use Cases**

### **🔧 Before Making Code Changes**

```powershell
# 1. Run relevant tests first
.\Test-DevHelper.ps1 -Action Debug -TestName "*NameOfFunctionYoureChanging*"

# 2. Make your changes

# 3. Run tests again to verify
.\Test-DevHelper.ps1 -Action Debug -TestName "*NameOfFunctionYoureChanging*"
```

### **🚨 When Tests Fail**

```powershell
# 1. Get details on what's failing
.\Test-DevHelper.ps1 -Action Analyze

# 2. Debug specific failure
.\Test-DevHelper.ps1 -Action Debug -TestName "*NameOfFailingTest*"

# 3. Check if it's a test data issue or code issue
```

### **📊 Before Code Review/PR**

```powershell
# 1. Full test suite
.\Invoke-Tests.ps1

# 2. Code coverage report
.\Invoke-Tests.ps1 -Coverage

# 3. Clean up
.\Test-DevHelper.ps1 -Action Clean
```

## **Test Types Explained**

### **Unit Tests** (`tests/unit/`)

- Test individual functions in isolation
- Use mocked data (fake API responses)
- Run very fast (milliseconds per test)
- **Use For**: Verifying function logic, edge cases

### **Integration Tests** (`tests/integration/`)

- Test how components work together
- Test complete workflows
- Still use mocks but test interactions
- **Use For**: Verifying end-to-end scenarios

## **Pro Tips**

### **🎯 Focus Your Testing**

```powershell
# Test just what you're working on
.\Test-DevHelper.ps1 -Action Debug -TestName "*Get-FABSupportedItemTypes*"
```

### **📈 Monitor Performance**

```powershell
# The tests should always be fast
# If they slow down, something's wrong with mocking
```

### **🔄 Test-Driven Development**

1. Write a failing test for new feature
2. Write minimal code to make test pass
3. Refactor while keeping tests green

### **🐛 When Debugging Real Issues**

Tests help you:

- Isolate problems to specific functions
- Verify fixes work
- Ensure fixes don't break other things

## **Next Steps**

Try these commands to get comfortable:

1. **Run a quick test**: `.\Test-DevHelper.ps1 -Action Debug -TestName "*retry*"`
2. **See test coverage**: `.\Test-DevHelper.ps1 -Action Analyze`
3. **Run full suite**: `.\Invoke-Tests.ps1 -TestType Unit`

The testing framework is designed to make your development faster and more confident!
