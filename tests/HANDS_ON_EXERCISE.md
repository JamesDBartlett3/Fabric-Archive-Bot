# 🎯 **Hands-On Testing Exercise**

## **Exercise 1: Understanding Test Output**

Run this command and observe the output:

```powershell
.\Test-DevHelper.ps1 -Action Debug -TestName "*rate limit*"
```

**What to Notice:**

- ⏱️ **Execution time**: Should be under 1 second total
- 🔄 **Retry behavior**: You'll see "Waiting 1 seconds" messages
- ✅ **Success indicators**: `[+]` for passing tests
- 📊 **Performance**: Individual tests run in milliseconds

## **Exercise 2: Testing Specific Functions**

Let's test the workspace filtering function:

```powershell
.\Test-DevHelper.ps1 -Action Debug -TestName "*workspace filter*"
```

**What You'll Learn:**

- How OData filters are tested
- Different filtering scenarios (by name, type, state)
- How test data flows through functions

## **Exercise 3: Understanding Test Structure**

Open this file in VS Code:

```
tests\unit\FabricArchiveBotCore.Tests.ps1
```

**Find These Patterns:**

1. **Describe Blocks**: `Describe "FunctionName"` - Groups tests for one function
2. **Context Blocks**: `Context "When something happens"` - Groups related scenarios
3. **It Blocks**: `It "Should do something"` - Individual test cases
4. **Mocks**: `Mock SomeFunction { return "fake data" }` - Fake external dependencies

## **Exercise 4: Debugging a Failing Test**

One test that's currently failing:

```powershell
.\Test-DevHelper.ps1 -Action Debug -TestName "*Should filter active workspaces correctly*"
```

**Debug Process:**

1. **Read the error message**: What did it expect vs. what it got?
2. **Look at test data**: Check `tests\fixtures\TestData.ps1`
3. **Understand the logic**: The test expects 2 active workspaces but gets 3

**The Issue**: The test data has 3 workspaces but only 2 are marked as "active" in the mock data, but the filtering logic treats all returned workspaces as active (since the API only returns active ones).

## **Exercise 5: Testing Your Own Changes**

If you modify a function, here's the workflow:

### **Before Making Changes:**

```powershell
# Test current behavior
.\Test-DevHelper.ps1 -Action Debug -TestName "*NameOfFunction*"
```

### **After Making Changes:**

```powershell
# Verify your changes work
.\Test-DevHelper.ps1 -Action Debug -TestName "*NameOfFunction*"

# Run broader tests to ensure nothing broke
.\Invoke-Tests.ps1 -TestType Unit
```

## **Exercise 6: Mock Data Understanding**

Look at `tests\fixtures\TestData.ps1`:

**Mock Workspaces:**

- 3 workspaces total
- 2 named "Test Workspace X"
- 1 named "Inactive Workspace"

**Mock Items:**

- Different types: Report, SemanticModel, Notebook
- Some supported, some not (Dashboard is unsupported)

**How Tests Use This:**

- Filtering tests count how many workspaces match filters
- Item type tests verify only supported types are processed

## **Exercise 7: Performance Testing**

Compare execution times:

### **Our Fast Tests:**

```powershell
Measure-Command { .\Test-DevHelper.ps1 -Action Debug -TestName "*retry*" }
```

### **If We Had Slow Tests (Don't run this!):**

```
# This would take 30+ seconds per retry test:
# Start-Sleep -Seconds 30  # Production rate limit delay
# MaxRetries = 3           # Production retry count
```

**Why Our Tests Are Fast:**

- `Start-Sleep` is mocked (no actual waiting)
- Only 1 retry instead of 3
- 1-second delays instead of 30-second delays

## **Exercise 8: Test-Driven Development**

Try adding a new test for a feature that doesn't exist yet:

1. **Add a failing test** (in your head):

```powershell
It "Should validate workspace names contain only valid characters" {
    $result = Test-WorkspaceNameValidity -Name "Invalid/Name"
    $result | Should -Be $false
}
```

2. **Run the test** - it would fail because the function doesn't exist
3. **Write minimal code** to make the test pass
4. **Refactor** while keeping the test green

## **Exercise 9: Real-World Debugging**

When you encounter issues in production:

### **Step 1: Reproduce with Tests**

```powershell
# Create a test that reproduces the issue
# Use real data that caused the problem
```

### **Step 2: Isolate the Problem**

```powershell
# Test individual functions to find where it breaks
.\Test-DevHelper.ps1 -Action Debug -TestName "*SuspectedFunction*"
```

### **Step 3: Verify the Fix**

```powershell
# After fixing, ensure the test passes
# Run full suite to ensure no regressions
.\Invoke-Tests.ps1
```

## **Exercise 10: Continuous Integration**

When you commit code:

### **Pre-Commit Check:**

```powershell
# Quick validation
.\Invoke-Tests.ps1 -TestType Unit
```

### **CI Pipeline** (GitHub Actions runs automatically):

```yaml
- Run all tests with coverage
- Fail the build if tests fail
- Generate coverage reports
```

## **🎓 What You've Learned**

After these exercises, you now know how to:

1. ✅ **Run specific tests** for focused debugging
2. ✅ **Understand test output** and performance metrics
3. ✅ **Debug failing tests** systematically
4. ✅ **Use tests for development workflow**
5. ✅ **Understand mock data and test structure**
6. ✅ **Apply test-driven development principles**

## **🚀 Next Level: Writing Your Own Tests**

When you add new functions to the module:

1. **Start with a test** describing what it should do
2. **Use the existing test patterns** (Describe/Context/It)
3. **Mock external dependencies** (API calls, file system)
4. **Test edge cases** (empty data, errors, boundary conditions)
5. **Verify performance** (tests should run in milliseconds)

The testing framework gives you confidence to make changes without breaking existing functionality!
