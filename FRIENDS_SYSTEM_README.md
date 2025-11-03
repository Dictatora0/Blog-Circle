# 好友系统功能说明

## 📋 功能概述

Blog Circle 现已支持完整的好友系统，用户可以添加好友、管理好友关系，并查看好友的动态时间线。

## ✨ 核心功能

### 1. 好友管理 (`/friends`)

- **搜索用户**：通过用户名、邮箱或昵称搜索其他用户
- **发送好友请求**：向搜索到的用户发送好友请求
- **处理好友请求**：接受或拒绝收到的好友请求
- **查看好友列表**：查看所有已添加的好友
- **删除好友**：移除不再需要的好友关系

### 2. 好友动态时间线 (`/timeline`)

- **查看动态**：显示自己和所有好友的最新动态
- **时间排序**：动态按发布时间倒序排列（最新在前）
- **互动功能**：点赞和评论好友的动态
- **实时更新**：支持下拉刷新获取最新内容

## 🏗️ 技术架构

### 后端实现

#### 数据库表结构

```sql
CREATE TABLE friendship (
    id BIGSERIAL PRIMARY KEY,
    requester_id BIGINT NOT NULL,
    receiver_id BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL,  -- PENDING / ACCEPTED / REJECTED
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 核心类

- **实体类**：`Friendship.java`
- **Mapper接口**：`FriendshipMapper.java` + `FriendshipMapper.xml`
- **服务类**：`FriendshipService.java`
- **控制器**：`FriendshipController.java`

#### API 接口

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/friends/request/{receiverId}` | 发送好友请求 |
| POST | `/api/friends/accept/{requestId}` | 接受好友请求 |
| POST | `/api/friends/reject/{requestId}` | 拒绝好友请求 |
| DELETE | `/api/friends/{friendshipId}` | 删除好友 |
| GET | `/api/friends/list` | 获取好友列表 |
| GET | `/api/friends/requests` | 获取待处理请求 |
| GET | `/api/friends/search?keyword=xxx` | 搜索用户 |
| GET | `/api/posts/timeline` | 获取好友时间线 |

### 前端实现

#### 页面组件

- **Friends.vue**：好友管理主页面
- **Timeline.vue**：好友动态时间线页面
- **FriendCard.vue**：好友卡片组件（复用于多处）

#### API 封装

- `src/api/friends.js`：封装所有好友相关的API调用

#### 路由配置

```javascript
{
  path: '/friends',
  name: 'Friends',
  component: () => import('@/views/Friends.vue'),
  meta: { requiresAuth: true }
},
{
  path: '/timeline',
  name: 'Timeline',
  component: () => import('@/views/Timeline.vue'),
  meta: { requiresAuth: true }
}
```

## 🧪 测试覆盖

### 后端单元测试

- **FriendshipServiceTest.java**：16个测试场景
  - 发送好友请求（成功/失败各种情况）
  - 接受/拒绝好友请求
  - 删除好友
  - 查询好友列表和请求
  - 搜索用户
  - 好友关系检查

### 前端E2E测试

- **friends.spec.ts**：10个测试场景
  - 访问好友管理页面
  - 搜索用户
  - 发送好友请求
  - 查看好友列表
  - 管理好友请求
  - 删除好友
  - 响应式布局测试

- **timeline.spec.ts**：12个测试场景
  - 访问时间线页面
  - 查看好友动态
  - 动态信息显示（作者、时间）
  - 点赞和评论
  - 动态排序验证
  - 响应式布局测试

## 🚀 使用指南

### 1. 数据库初始化

```bash
# 执行好友关系表创建脚本
psql -U your_user -d blog_db -f backend/src/main/resources/db/friendship.sql
```

### 2. 启动服务

```bash
# 使用启动脚本（自动启动前后端）
./start.sh

# 或手动启动
cd backend && mvn spring-boot:run
cd frontend && npm run dev
```

### 3. 访问功能

1. 登录系统
2. 点击顶部导航栏的「好友」按钮访问好友管理
3. 点击「好友动态」按钮查看好友时间线

## 🎨 界面设计

### 设计风格

- **简洁卡片**：好友和动态均采用卡片式布局
- **渐变背景**：时间线页面使用紫色渐变背景
- **响应式**：完美适配桌面和移动设备
- **动画效果**：平滑的过渡和悬停效果

### 主题色

- 主色调：`#409eff`（Element Plus蓝）
- 渐变色：`#667eea` → `#764ba2`
- 成功色：`#67c23a`
- 危险色：`#f56c6c`

## 📝 注意事项

1. **好友关系是双向的**：A和B成为好友后，双方都能看到对方的动态
2. **请求状态**：
   - PENDING：待处理
   - ACCEPTED：已接受
   - REJECTED：已拒绝
3. **搜索限制**：每次搜索最多返回20个用户
4. **权限验证**：所有好友相关操作都需要登录并携带JWT Token

## 🔄 CI/CD

好友系统的测试已集成到 GitHub Actions 工作流中：

- 自动运行后端单元测试
- 自动运行前端E2E测试
- 测试通过后自动合并dev到main分支

## 📦 相关文件

### 后端

- `backend/src/main/java/com/cloudcom/blog/entity/Friendship.java`
- `backend/src/main/java/com/cloudcom/blog/mapper/FriendshipMapper.java`
- `backend/src/main/java/com/cloudcom/blog/service/FriendshipService.java`
- `backend/src/main/java/com/cloudcom/blog/controller/FriendshipController.java`
- `backend/src/main/resources/mapper/FriendshipMapper.xml`
- `backend/src/main/resources/db/friendship.sql`
- `backend/src/test/java/com/cloudcom/blog/service/FriendshipServiceTest.java`

### 前端

- `frontend/src/views/Friends.vue`
- `frontend/src/views/Timeline.vue`
- `frontend/src/components/FriendCard.vue`
- `frontend/src/api/friends.js`
- `frontend/tests/e2e/friends.spec.ts`
- `frontend/tests/e2e/timeline.spec.ts`

### 配置

- `.github/workflows/test.yml`（已更新测试流程）

## 🎉 总结

好友系统为 Blog Circle 增添了社交属性，让用户能够：

- 🤝 建立好友关系
- 📰 查看好友动态
- 💬 互动交流
- 🎯 个性化内容推荐

这使 Blog Circle 更像一个真实的社交平台，提升了用户参与度和平台活跃度！

