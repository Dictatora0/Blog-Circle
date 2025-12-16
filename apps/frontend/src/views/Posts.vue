<template>
  <div class="posts-container">
    <el-card>
      <template #header>
        <div class="header-row">
          <span class="title">文章列表</span>
          <el-button
            v-if="userStore.token"
            type="primary"
            @click="showCreateDialog"
          >
            发布文章
          </el-button>
        </div>
      </template>

      <el-empty v-if="posts.length === 0" description="暂无文章" />

      <div v-else class="posts-list">
        <el-card
          v-for="post in posts"
          :key="post.id"
          class="post-item"
          shadow="hover"
          @click="goToDetail(post.id)"
        >
          <h3>{{ post.title }}</h3>
          <div class="post-meta">
            <span>作者：{{ post.authorName }}</span>
            <span>浏览：{{ post.viewCount }}</span>
            <span>评论：{{ post.commentCount }}</span>
            <span>{{ formatDate(post.createdAt) }}</span>
          </div>
          <p class="post-content">{{ truncateContent(post.content) }}</p>
        </el-card>
      </div>
    </el-card>

    <!-- 创建文章对话框 -->
    <el-dialog v-model="dialogVisible" title="发布文章" width="600px">
      <el-form :model="postForm" :rules="rules" ref="postFormRef">
        <el-form-item label="标题" prop="title">
          <el-input v-model="postForm.title" placeholder="请输入文章标题" />
        </el-form-item>
        <el-form-item label="内容" prop="content">
          <el-input
            v-model="postForm.content"
            type="textarea"
            :rows="10"
            placeholder="请输入文章内容"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="loading" @click="handleSubmit"
          >发布</el-button
        >
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { useRouter } from "vue-router";
import { ElMessage } from "element-plus";
import { getPostList, createPost } from "@/api/post";
import { useUserStore } from "@/stores/user";

const router = useRouter();
const userStore = useUserStore();
const posts = ref([]);
const dialogVisible = ref(false);
const postFormRef = ref(null);
const loading = ref(false);

const postForm = ref({
  title: "",
  content: "",
});

const rules = {
  title: [{ required: true, message: "请输入文章标题", trigger: "blur" }],
  content: [{ required: true, message: "请输入文章内容", trigger: "blur" }],
};

const loadPosts = async () => {
  try {
    const res = await getPostList();
    posts.value = res.data || [];
  } catch (error) {
    console.error("加载文章列表失败:", error);
  }
};

const showCreateDialog = () => {
  postForm.value = { title: "", content: "" };
  dialogVisible.value = true;
};

const handleSubmit = async () => {
  if (!postFormRef.value) return;

  await postFormRef.value.validate(async (valid) => {
    if (valid) {
      loading.value = true;
      try {
        await createPost(postForm.value);
        ElMessage.success("发布成功");
        dialogVisible.value = false;
        loadPosts();
      } catch (error) {
        console.error("发布失败:", error);
      } finally {
        loading.value = false;
      }
    }
  });
};

const goToDetail = (id) => {
  router.push(`/posts/${id}`);
};

const truncateContent = (content) => {
  if (!content) return "";
  return content.length > 150 ? content.substring(0, 150) + "..." : content;
};

const formatDate = (dateStr) => {
  if (!dateStr) return "";
  return new Date(dateStr).toLocaleString("zh-CN");
};

onMounted(() => {
  loadPosts();
});
</script>

<style scoped>
.posts-container {
  max-width: 1200px;
  margin: 0 auto;
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

.posts-list {
  display: flex;
  flex-direction: column;
  gap: 15px;
}

.post-item {
  cursor: pointer;
  transition: transform 0.2s;
}

.post-item:hover {
  transform: translateY(-2px);
}

.post-item h3 {
  margin: 0 0 10px 0;
  color: #303133;
}

.post-meta {
  display: flex;
  gap: 20px;
  font-size: 14px;
  color: #909399;
  margin-bottom: 10px;
}

.post-content {
  color: #606266;
  line-height: 1.6;
  margin: 0;
}
</style>

