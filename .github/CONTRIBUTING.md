# 贡献指南

感谢您考虑为 Blog Circle 项目做出贡献！我们欢迎各种形式的贡献。

## 如何贡献

### 报告 Bug

如果您发现了一个 bug，请通过 [Issue](../../issues) 报告。在提交之前，请确保：

1. 检查是否已经有相关的 Issue
2. 使用 bug 报告模板
3. 提供清晰的步骤来重现问题
4. 包含环境信息和错误日志

### 建议新功能

我们欢迎新功能的建议！请：

1. 检查是否已经有相关的 Issue 或 PR
2. 使用功能请求模板
3. 详细描述功能的使用场景和预期效果

### 提交代码

1. **Fork 仓库**

2. **创建分支**
   ```bash
   git checkout -b feature/your-feature-name
   # 或
   git checkout -b fix/your-bug-fix
   ```

3. **进行更改**
   - 遵循项目的代码风格
   - 添加必要的测试
   - 更新相关文档

4. **提交更改**
   ```bash
   git add .
   git commit -m "描述你的更改"
   ```
   提交信息应清晰简洁，遵循约定：
   - `feat: 新功能`
   - `fix: 修复 bug`
   - `docs: 文档更新`
   - `refactor: 重构`
   - `test: 测试相关`

5. **推送并创建 Pull Request**
   ```bash
   git push origin feature/your-feature-name
   ```
   然后前往 GitHub 创建 Pull Request。

## 开发环境设置

### 后端开发

```bash
cd backend
mvn clean install
mvn spring-boot:run
```

### 前端开发

```bash
cd frontend
npm install
npm run dev
```

### 运行测试

**后端测试：**
```bash
cd backend
mvn test
```

**前端测试：**
```bash
cd frontend
npm run test        # 单元测试
npm run test:e2e    # E2E 测试
```

## 代码规范

### 后端（Java）

- 遵循 Java 编码规范
- 使用 4 个空格缩进
- 类名使用大驼峰命名（PascalCase）
- 方法和变量使用小驼峰命名（camelCase）
- 常量大写字母加下划线（UPPER_SNAKE_CASE）

### 前端（Vue/JavaScript）

- 遵循 Vue 3 组合式 API 规范
- 使用 2 个空格缩进
- 组件名使用大驼峰命名
- 使用 ESLint 和 Prettier 进行代码格式化

## Pull Request 流程

1. 确保您的代码通过了所有测试
2. 更新相关文档（如 README.md）
3. 创建 Pull Request，使用提供的模板
4. 等待代码审查
5. 根据反馈进行修改

## 行为准则

- 尊重其他贡献者
- 建设性地提供反馈
- 保持专业和友善的态度

再次感谢您的贡献！

