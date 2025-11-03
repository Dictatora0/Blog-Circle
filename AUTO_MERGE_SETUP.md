# 自动合并配置说明

## 📋 当前配置

### 自动合并功能

当满足以下条件时，dev分支会自动合并到main分支：

1. ✅ 所有测试通过（后端测试 + 前端测试）
2. ✅ 触发事件是 push 到 dev 分支
3. ✅ 不是 Pull Request 事件

### 工作流程

```
推送代码到 dev
    ↓
运行测试（后端 + 前端）
    ↓
所有测试通过？
    ├─ 是 → 自动合并 dev 到 main
    └─ 否 → 不合并，显示测试失败报告
```

---

## ⚙️ 配置详情

### 触发条件

```yaml
on:
  push:
    branches: [ "main", "dev" ]
  pull_request:
    branches: [ "main", "dev" ]
```

### 自动合并步骤

在 `test-summary` job 中添加了 `Auto merge dev to main` 步骤：

- **条件**: 
  - 当前分支是 `dev`
  - 所有测试通过
  - 事件是 `push`（不是PR）

- **操作**:
  1. Checkout main 分支
  2. Pull 最新代码
  3. Merge dev 到 main（使用 `--no-edit`）
  4. Push 到 main 分支

---

## 🚨 注意事项

### 潜在问题

1. **合并冲突**
   - 如果 dev 和 main 有冲突，自动合并会失败
   - 需要手动解决冲突后再推送

2. **权限要求**
   - 需要 GitHub Actions 有 `contents: write` 权限
   - 当前已配置，但可能需要仓库设置允许

3. **代码审查**
   - 自动合并会跳过代码审查流程
   - 如果需要审查，应该使用 Pull Request 而不是自动合并

### 推荐做法

- ✅ **开发阶段**: 使用自动合并（当前配置）
- ⚠️ **生产阶段**: 建议使用 Pull Request + 代码审查

---

## 🔧 如何禁用自动合并

如果不希望自动合并，可以：

### 方案1：移除自动合并步骤

删除 `.github/workflows/test.yml` 中的以下步骤：

```yaml
- name: Auto merge dev to main (if tests pass)
  ...
```

### 方案2：添加环境变量控制

添加一个环境变量来控制是否自动合并：

```yaml
- name: Auto merge dev to main (if tests pass)
  if: |
    github.ref == 'refs/heads/dev' && 
    steps.test_results.outputs.tests_passed == 'true' &&
    github.event_name == 'push' &&
    env.AUTO_MERGE == 'true'
  env:
    AUTO_MERGE: ${{ secrets.AUTO_MERGE_ENABLED }}
```

然后在仓库设置中添加 Secret: `AUTO_MERGE_ENABLED=true`

---

## 📊 当前状态

- ✅ 自动合并功能已启用
- ✅ 仅在测试全部通过时执行
- ✅ 仅对 push 到 dev 分支生效
- ⚠️ 需要在仓库设置中确认 Actions 权限

---

**最后更新**: 2025-11-03

