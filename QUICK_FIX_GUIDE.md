# Blog Circle 快速修复指南

## 问题概述

E2E 测试失败率：70% (99/141 失败)

**根本原因**：CORS 配置问题导致前端无法调用后端 API

---

## 快速修复流程（约 5 分钟）

### 方法 1：自动化脚本（推荐）

```bash
cd /Users/lifulin/Desktop/CloudCom
./fix-cors-and-test.sh
```

脚本执行内容：

1. 备份原始配置
2. 停止当前服务
3. 重新编译后端
4. 启动服务
5. 验证 CORS 配置
6. 运行 E2E 测试
7. 生成测试报告

---

### 方法 2：手动修复

```bash
# 1. 停止后端
kill -9 $(lsof -t -i:8080)

# 2. 重新编译（配置已更新）
cd backend
mvn clean package -DskipTests

# 3. 启动服务
java -jar target/blog-system-1.0.0.jar > ../backend.log 2>&1 &

# 4. 等待服务启动
sleep 15

# 5. 验证CORS
curl -X OPTIONS http://localhost:8080/api/auth/register \
  -H "Origin: http://localhost:5173" \
  -H "Access-Control-Request-Method: POST" \
  -v

# 6. 运行测试
cd ../frontend
TEST_ENV=local npm run test:e2e
```

---

## 修复内容说明

### 已修改的文件

#### 1. `backend/src/main/java/com/cloudcom/blog/config/WebConfig.java`

**修改前**：

```java
.allowedOrigins("http://localhost:5173", "http://localhost:3000", ...)
```

**修改后**：

```java
// 开发环境：允许所有来源（使用 allowedOriginPatterns）
if ("default".equals(activeProfile) || "test".equals(activeProfile)) {
    registry.addMapping("/**")
            .allowedOriginPatterns("*");  // 允许所有来源
}
```

**原因**：

- `allowedOriginPatterns("*")` 更适合多端口的开发环境
- 避免协议与端口匹配导致的阻断
- 兼容动态端口和多种调试场景

#### 2. `backend/src/main/java/com/cloudcom/blog/config/CorsConfig.java` （新建）

添加了**CORS 过滤器**，提供更高优先级的 CORS 处理：

```java
@Bean
public CorsFilter corsFilter() {
    CorsConfiguration config = new CorsConfiguration();
    config.setAllowedOriginPatterns(Collections.singletonList("*")); // 开发环境
    config.setAllowCredentials(true);
    config.setAllowedHeaders(Collections.singletonList("*"));
    // ... 更多配置
}
```

**优势**：

- 过滤器优先级高于 WebMvcConfigurer
- 保证所有请求均经过 CORS 处理
- 可覆盖更复杂的 CORS 场景

---

## 验证修复效果

### 1. 验证后端服务

```bash
# 检查服务是否运行
curl http://localhost:8080/api/auth/test

# 预期输出：401 Unauthorized（正常，因为没有token）
```

### 2. 验证 CORS 配置

```bash
curl -X OPTIONS http://localhost:8080/api/auth/register \
  -H "Origin: http://localhost:5173" \
  -H "Access-Control-Request-Method: POST" \
  -I

# 预期输出应包含：
# Access-Control-Allow-Origin: http://localhost:5173
# Access-Control-Allow-Credentials: true
```

### 3. 测试注册 API

```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Origin: http://localhost:5173" \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser123","email":"test@test.com","password":"123456","confirmPassword":"123456"}'

# 预期输出：{"code":200,"message":"注册成功",...}
```

### 4. 运行 E2E 测试

```bash
cd frontend
TEST_ENV=local npm run test:e2e

# 或只测试认证模块
npx playwright test tests/e2e/auth.spec.ts --reporter=list
```

---

## 预期结果

### 修复前

- ❌ 总测试：141
- ❌ 通过：42 (29.8%)
- ❌ 失败：99 (70.2%)
- ❌ 主要错误：CORS 403, TimeoutError

### 修复后

- 总测试：141
- 通过：120+ (85%+)
- 失败：<20 (主要是业务逻辑相关)
- CORS 问题：已解决

---

## 故障排除

### 问题 1：编译失败

```bash
# 清理Maven缓存
cd backend
rm -rf target/
mvn clean

# 重新下载依赖
mvn dependency:resolve

# 重新编译
mvn package -DskipTests
```

### 问题 2：端口被占用

```bash
# 查找占用8080端口的进程
lsof -i:8080

# 终止进程
kill -9 <PID>
```

### 问题 3：CORS 仍然失败

```bash
# 检查Java进程是否使用了新的配置
ps aux | grep java

# 确保使用的是新编译的jar
ls -lh backend/target/blog-system-1.0.0.jar

# 检查后端日志
tail -f backend.log | grep CORS
```

### 问题 4：测试仍然失败

```bash
# 清理测试缓存
cd frontend
rm -rf node_modules/.cache
rm -rf test-results/*

# 重新安装依赖（如果需要）
npm install

# 使用headless=false运行，观察浏览器行为
npx playwright test tests/e2e/auth.spec.ts --headed --debug
```

---

## 查看日志

```bash
# 后端日志
tail -f backend.log

# 后端重启日志（使用脚本后）
tail -f backend-restart.log

# 前端开发服务器日志
cd frontend
npm run dev

# Playwright测试日志
cd frontend
npx playwright show-report
```

---

## 后续动作

修复完成后，建议：

1. **运行完整测试套件**

   ```bash
   cd frontend
   TEST_ENV=local npm run test:e2e
   ```

2. **查看测试报告**

   ```bash
   npx playwright show-report
   ```

3. **提交代码**（如果测试通过）

   ```bash
   git add .
   git commit -m "fix: 修复CORS配置，解决E2E测试失败问题"
   ```

4. **更新文档**
   - 记录 CORS 配置变更
   - 更新开发环境设置文档

---

## 获取帮助

如果修复后仍有问题：

1. **查看完整诊断报告**：`COMPREHENSIVE_DIAGNOSIS_REPORT.md`
2. **检查后端日志**：`backend.log` 或 `backend-restart.log`
3. **查看测试结果**：`frontend/playwright-report/index.html`
4. **检查配置文件**：确保所有修改都已保存并重新编译

---

**修复脚本位置**：`/Users/lifulin/Desktop/CloudCom/fix-cors-and-test.sh`

**一键修复命令**：

```bash
cd /Users/lifulin/Desktop/CloudCom && ./fix-cors-and-test.sh
```

---

执行上述步骤即可完成修复。
