import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/vue";
import { createRouter, createMemoryHistory } from "vue-router";
import { createPinia, setActivePinia } from "pinia";
import TopNavbar from "@/components/TopNavbar.vue";
import { useUserStore } from "@/stores/user";

/**
 * TopNavbar 组件测试
 *
 * 测试场景：
 * 1. 未登录状态显示登录按钮
 * 2. 登录状态显示用户信息和发表动态按钮
 * 3. 点击发表动态按钮跳转
 * 4. 点击Logo跳转首页
 */
describe("TopNavbar", () => {
  let router;
  let pinia;

  beforeEach(() => {
    router = createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: "/", redirect: "/home" },
        { path: "/home", component: { template: "<div>Home</div>" } },
        { path: "/publish", component: { template: "<div>Publish</div>" } },
        { path: "/login", component: { template: "<div>Login</div>" } },
      ],
    });

    pinia = createPinia();
    setActivePinia(pinia);
  });

  it("场景1: 未登录状态显示登录按钮", () => {
    // Given: 用户未登录
    const userStore = useUserStore();
    userStore.token = null;

    // When: 渲染组件
    render(TopNavbar, {
      global: {
        plugins: [router, pinia],
      },
    });

    // Then: 应该显示登录按钮
    expect(screen.getByText("登录")).toBeInTheDocument();
    expect(screen.queryByText("发表动态")).not.toBeInTheDocument();
  });

  it("场景2: 登录状态显示用户信息和发表动态按钮", () => {
    // Given: 用户已登录
    const userStore = useUserStore();
    userStore.token = "mock-token";
    userStore.userInfo = {
      id: 1,
      username: "testuser",
      nickname: "测试用户",
    };

    // When: 渲染组件
    render(TopNavbar, {
      global: {
        plugins: [router, pinia],
      },
    });

    // Then: 应该显示发表动态按钮和用户信息
    expect(screen.getByText("发表动态")).toBeInTheDocument();
    expect(screen.getByText("测试用户")).toBeInTheDocument();
  });

  it("场景3: 点击Logo跳转首页", async () => {
    // Given: 渲染组件并设置路由到 /publish
    await router.push("/publish");
    await router.isReady();

    render(TopNavbar, {
      global: {
        plugins: [router, pinia],
      },
    });

    // 验证当前在 /publish 路径
    expect(router.currentRoute.value.path).toBe("/publish");

    // When: 点击Logo
    const logo = screen.getByText("Blog Circle");
    await logo.click();

    // Then: 应该跳转到首页 (/home，因为 / 会重定向到 /home)
    await router.isReady();
    // 等待路由导航完成
    await new Promise((resolve) => setTimeout(resolve, 100));
    expect(router.currentRoute.value.path).toBe("/home");
  });

  it("场景4: 显示Blog Circle Logo", () => {
    // Given & When: 渲染组件
    render(TopNavbar, {
      global: {
        plugins: [router, pinia],
      },
    });

    // Then: 应该显示Logo文字
    expect(screen.getByText("Blog Circle")).toBeInTheDocument();
  });
});
