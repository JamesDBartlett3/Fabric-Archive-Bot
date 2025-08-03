# Fabric Archive Bot v2.0 - API Rate Limiting Guide

## Overview

Fabric Archive Bot v2.0 includes comprehensive API rate limiting handling to ensure reliable operation with Microsoft Fabric APIs and prevent HTTP 429 (Too Many Requests) errors.

## 🛡️ **Multi-Layer Rate Limiting Protection**

### **Layer 1: FabricTools Built-in Protection**
- **Automatic 429 Handling**: FabricTools automatically detects and handles HTTP 429 responses
- **Retry-After Compliance**: Respects the `Retry-After` header from Fabric APIs
- **Exponential Backoff**: Built-in intelligent retry mechanisms
- **Long-Running Operations**: Handles async operations automatically

### **Layer 2: FAB Enhanced Protection**
- **Custom Retry Logic**: Enhanced retry wrapper with configurable parameters
- **Operation-Specific Handling**: Different retry strategies for different operation types
- **Parallel Processing Coordination**: Rate limiting awareness in multi-threaded operations
- **Comprehensive Logging**: Detailed rate limiting event logging

## 🔧 **Configuration Options**

### **Rate Limiting Settings in Configuration**

```json
{
  "FabricToolsSettings": {
    "ParallelProcessing": true,
    "ThrottleLimit": 4,
    "RateLimitSettings": {
      "EnableRetry": true,
      "MaxRetries": 3,
      "RetryDelaySeconds": 30,
      "BackoffMultiplier": 2
    }
  }
}
```

### **Configuration Parameters:**

| Parameter | Description | Default | Range |
|-----------|-------------|---------|--------|
| `EnableRetry` | Enable automatic retry on rate limits | `true` | true/false |
| `MaxRetries` | Maximum retry attempts per operation | `3` | 1-10 |
| `RetryDelaySeconds` | Base delay between retries (seconds) | `30` | 5-300 |
| `BackoffMultiplier` | Exponential backoff multiplier | `2` | 1.5-5.0 |

## 🚀 **How Rate Limiting Works**

### **Automatic Detection**
The system automatically detects rate limiting scenarios:

```
✅ HTTP 429 - Too Many Requests
✅ Retry-After headers
✅ Rate limit error messages
✅ API throttling responses
```

### **Smart Retry Strategy**

1. **Immediate Retry**: For transient network issues
2. **Linear Backoff**: For moderate rate limiting
3. **Exponential Backoff**: For severe rate limiting
4. **Circuit Breaker**: Temporary halt for severe issues

### **Retry Calculation**
```
Delay = BaseDelay × (BackoffMultiplier ^ (RetryAttempt - 1))

Example with defaults:
- Attempt 1: 30 seconds
- Attempt 2: 60 seconds  
- Attempt 3: 120 seconds
```

## 📊 **Rate Limiting Scenarios**

### **Scenario 1: Light Rate Limiting**
```
User exports 5-10 workspaces
├── Parallel processing: 2-4 threads
├── Expected rate limits: Minimal
└── Retry strategy: Standard delays
```

### **Scenario 2: Heavy Export Workload**
```
User exports 50+ workspaces
├── Parallel processing: 4-8 threads
├── Expected rate limits: Moderate
├── Retry strategy: Exponential backoff
└── Automatic throttle reduction
```

### **Scenario 3: API Maintenance/Issues**
```
Microsoft Fabric API issues
├── HTTP 503/502 responses
├── Extended retry delays
├── Circuit breaker activation
└── Graceful degradation
```

## ⚙️ **Advanced Configuration**

### **Conservative Settings (Slow but Reliable)**
```json
{
  "FabricToolsSettings": {
    "ParallelProcessing": true,
    "ThrottleLimit": 2,
    "RateLimitSettings": {
      "MaxRetries": 5,
      "RetryDelaySeconds": 60,
      "BackoffMultiplier": 3
    }
  }
}
```

### **Aggressive Settings (Fast but Risk-Prone)**
```json
{
  "FabricToolsSettings": {
    "ParallelProcessing": true,
    "ThrottleLimit": 8,
    "RateLimitSettings": {
      "MaxRetries": 2,
      "RetryDelaySeconds": 15,
      "BackoffMultiplier": 1.5
    }
  }
}
```

### **Balanced Settings (Recommended)**
```json
{
  "FabricToolsSettings": {
    "ParallelProcessing": true,
    "ThrottleLimit": 4,
    "RateLimitSettings": {
      "MaxRetries": 3,
      "RetryDelaySeconds": 30,
      "BackoffMultiplier": 2
    }
  }
}
```

## 🔍 **Monitoring Rate Limiting**

### **Console Output Examples**

**Normal Operation:**
```
Executing Get-FabricWorkspace
Executing Get-FabricItem-workspace-123
Processing workspace: MyWorkspace (Thread: 5)
```

**Rate Limiting Detected:**
```
⚠️ Rate limit encountered for Get-FabricItem-workspace-123. 
   Waiting 30 seconds before retry 1/3...
⚠️ Rate limit encountered for Export-FabricItem-item-456. 
   Waiting 60 seconds before retry 2/3...
```

**Successful Recovery:**
```
✅ Executing Get-FabricItem-workspace-123 (Retry 2/3)
✅ Operation completed successfully after retry
```

**Max Retries Exceeded:**
```
❌ Rate limit exceeded for Export-FabricItem-item-789 after 3 retries. 
   Operation failed.
```

## 🎯 **Best Practices**

### **1. Monitor and Adjust**
- Start with conservative settings
- Monitor retry patterns in logs
- Adjust throttle limits based on performance

### **2. Time-Based Considerations**
- **Peak Hours** (9 AM - 5 PM): Reduce parallel processing
- **Off-Hours** (Evening/Weekend): Increase parallel processing
- **Maintenance Windows**: Use conservative settings

### **3. Workspace Size Considerations**
```
Small Workspaces (<10 items): Higher concurrency OK
Medium Workspaces (10-100 items): Moderate concurrency
Large Workspaces (100+ items): Lower concurrency
```

### **4. Network Considerations**
- **Fast Connection**: Higher throttle limits
- **Slow Connection**: Lower throttle limits
- **VPN/Proxy**: Conservative settings

## 🚨 **Troubleshooting Rate Limiting**

### **Common Issues**

**Issue**: "Rate limit exceeded after max retries"
**Solution**: 
- Reduce `ThrottleLimit`
- Increase `RetryDelaySeconds`
- Increase `MaxRetries`

**Issue**: "Operations taking too long"
**Solution**: 
- Reduce `RetryDelaySeconds`
- Reduce `BackoffMultiplier`
- Check network connectivity

**Issue**: "Intermittent failures"
**Solution**: 
- Increase `MaxRetries`
- Check Microsoft Fabric service status
- Review API usage patterns

### **Diagnostic Commands**

**Test Rate Limiting Settings:**
```powershell
.\Start-FabricArchiveBot.ps1 -WhatIf -WorkspaceFilter "(contains(name,'Test'))"
```

**Monitor Network Issues:**
```powershell
Test-NetConnection -ComputerName api.fabric.microsoft.com -Port 443
```

**Check Service Status:**
```powershell
# Visit: https://admin.powerplatform.microsoft.com/support/status
```

## 📈 **Performance Impact**

### **Rate Limiting vs. Performance Trade-offs**

| Setting Level | Speed | Reliability | API Courtesy |
|---------------|-------|-------------|---------------|
| Aggressive | ⚡⚡⚡ | ⚠️ | ❌ |
| Balanced | ⚡⚡ | ✅ | ✅ |
| Conservative | ⚡ | ✅✅ | ✅✅ |

### **Expected Processing Times**

**Small Environment** (5-10 workspaces):
- Conservative: 15-30 minutes
- Balanced: 10-20 minutes  
- Aggressive: 5-15 minutes

**Medium Environment** (25-50 workspaces):
- Conservative: 45-90 minutes
- Balanced: 30-60 minutes
- Aggressive: 20-45 minutes

**Large Environment** (100+ workspaces):
- Conservative: 2-4 hours
- Balanced: 1.5-3 hours
- Aggressive: 1-2 hours (higher failure risk)

## 🔧 **Migration from v1.0**

The migration helper automatically configures optimal rate limiting settings:

```powershell
.\helpers\Migrate-ToV2.ps1
```

**Automatic Settings Applied:**
- Rate limiting enabled by default
- Conservative retry settings
- Balanced throttle limits
- Comprehensive error handling

This ensures a smooth transition while maintaining reliability and API courtesy.

## 📚 **Technical Details**

### **FabricTools Integration**
Fabric Archive Bot v2.0 leverages FabricTools' built-in rate limiting:
- `Invoke-FabricRestMethod` with `HandleResponse` parameter
- Automatic HTTP 429 detection and retry
- Retry-After header compliance
- Long-running operation support

### **Error Types Handled**
- `HTTP 429` - Too Many Requests
- `HTTP 503` - Service Unavailable  
- `HTTP 502` - Bad Gateway
- Network timeouts and connection issues
- Transient authentication issues

This comprehensive rate limiting system ensures Fabric Archive Bot v2.0 operates reliably even under heavy API usage scenarios.
