<template>
  <div class="statistics-container">
    <el-card>
      <template #header>
        <div class="header-row">
          <span class="title">数据统计</span>
          <el-button type="primary" :loading="analyzing" @click="handleAnalyze">
            运行数据分析
          </el-button>
        </div>
      </template>

      <el-tabs v-model="activeTab" @tab-change="handleTabChange">
        <el-tab-pane label="用户发文统计" name="USER_POST_COUNT">
          <el-empty v-if="userPostStats.length === 0" description="暂无数据" />
          <el-table v-else :data="userPostStats" style="width: 100%">
            <el-table-column prop="statKey" label="用户" width="200" />
            <el-table-column prop="statValue" label="发文数量" />
            <el-table-column prop="updatedAt" label="更新时间" width="180">
              <template #default="scope">
                {{ formatDate(scope.row.updatedAt) }}
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>

        <el-tab-pane label="文章浏览统计" name="POST_VIEW_COUNT">
          <el-empty v-if="postViewStats.length === 0" description="暂无数据" />
          <el-table v-else :data="postViewStats" style="width: 100%">
            <el-table-column prop="statKey" label="文章" width="200" />
            <el-table-column prop="statValue" label="浏览次数" />
            <el-table-column prop="updatedAt" label="更新时间" width="180">
              <template #default="scope">
                {{ formatDate(scope.row.updatedAt) }}
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>

        <el-tab-pane label="文章评论统计" name="POST_COMMENT_COUNT">
          <el-empty
            v-if="postCommentStats.length === 0"
            description="暂无数据"
          />
          <el-table v-else :data="postCommentStats" style="width: 100%">
            <el-table-column prop="statKey" label="文章" width="200" />
            <el-table-column prop="statValue" label="评论数量" />
            <el-table-column prop="updatedAt" label="更新时间" width="180">
              <template #default="scope">
                {{ formatDate(scope.row.updatedAt) }}
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>

        <el-tab-pane label="全部统计" name="ALL">
          <el-empty v-if="allStats.length === 0" description="暂无数据" />
          <el-table v-else :data="allStats" style="width: 100%">
            <el-table-column prop="statType" label="统计类型" width="200">
              <template #default="scope">
                {{ getStatTypeName(scope.row.statType) }}
              </template>
            </el-table-column>
            <el-table-column prop="statKey" label="统计键" width="200" />
            <el-table-column prop="statValue" label="统计值" />
            <el-table-column prop="updatedAt" label="更新时间" width="180">
              <template #default="scope">
                {{ formatDate(scope.row.updatedAt) }}
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>
      </el-tabs>
    </el-card>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { ElMessage } from "element-plus";
import {
  runAnalytics,
  getStatisticsSummary,
  getAggregatedStatistics,
  getAllStatistics,
  getStatisticsByType,
} from "@/api/statistics";

const activeTab = ref("USER_POST_COUNT");
const analyzing = ref(false);
const userPostStats = ref([]);
const postViewStats = ref([]);
const postCommentStats = ref([]);
const allStats = ref([]);

const handleAnalyze = async () => {
  analyzing.value = true;
  try {
    // 后端返回格式: { code: 200, message: "..." } 或 { code: 500, message: "错误信息" }
    const res = await runAnalytics();

    // 检查响应状态码（axios成功响应时，HTTP状态码是200，但业务code可能在data中）
    const responseData = res.data || {};
    const code = responseData.code;

    if (code === 200) {
      const message = responseData.message || "分析完成";
      ElMessage.success(message);
      await loadStatistics();
    } else {
      // 如果返回码不是200，显示错误消息（红色错误提示）
      const errorMsg = responseData.message || "分析失败，请重试";
      ElMessage.error(errorMsg);
    }
  } catch (error) {
    console.error("分析失败:", error);
    // 从错误响应中获取错误消息
    const errorResponse = error.response?.data || {};
    const errorMsg =
      errorResponse.message || error.message || "分析失败，请重试";
    ElMessage.error(errorMsg);
  } finally {
    analyzing.value = false;
  }
};

const loadStatistics = async () => {
  try {
    // 加载统计汇总（聚合 + 明细）
    // 后端返回格式: { code: 200, message: "...", data: { aggregated: {...}, details: [...] } }
    const res = await getStatisticsSummary();
    const responseData = res.data?.data || res.data || {};

    // 提取明细列表
    const details = responseData.details || [];
    allStats.value = Array.isArray(details) ? details : [];

    // 分类统计数据
    userPostStats.value = allStats.value.filter(
      (s) => s.statType === "USER_POST_COUNT"
    );
    postViewStats.value = allStats.value.filter(
      (s) => s.statType === "POST_VIEW_COUNT"
    );
    postCommentStats.value = allStats.value.filter(
      (s) => s.statType === "POST_COMMENT_COUNT"
    );
  } catch (error) {
    console.error("加载统计数据失败:", error);
    ElMessage.error("加载统计数据失败");
  }
};

const handleTabChange = async (name) => {
  if (name === "ALL") {
    return;
  }

  try {
    // 后端返回格式: { code: 200, message: "...", data: [...] }
    const res = await getStatisticsByType(name);
    const responseData = res.data?.data || res.data || [];
    const data = Array.isArray(responseData) ? responseData : [];

    if (name === "USER_POST_COUNT") {
      userPostStats.value = data;
    } else if (name === "POST_VIEW_COUNT") {
      postViewStats.value = data;
    } else if (name === "POST_COMMENT_COUNT") {
      postCommentStats.value = data;
    }
  } catch (error) {
    console.error("加载统计数据失败:", error);
    ElMessage.error("加载统计数据失败");
  }
};

const getStatTypeName = (type) => {
  const names = {
    USER_POST_COUNT: "用户发文统计",
    POST_VIEW_COUNT: "文章浏览统计",
    POST_COMMENT_COUNT: "文章评论统计",
  };
  return names[type] || type;
};

const formatDate = (dateStr) => {
  if (!dateStr) return "";
  return new Date(dateStr).toLocaleString("zh-CN");
};

onMounted(() => {
  loadStatistics();
});
</script>

<style scoped>
.statistics-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: var(--spacing-lg);
  padding-top: calc(56px + var(--spacing-lg));
}

.header-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.title {
  font-size: 18px;
  font-weight: bold;
}

@media (max-width: 768px) {
  .statistics-container {
    padding: var(--spacing-md);
    padding-top: calc(56px + var(--spacing-md));
  }

  .header-row {
    flex-direction: column;
    align-items: flex-start;
    gap: var(--spacing-md);
  }

  .title {
    font-size: 16px;
  }
}
</style>
