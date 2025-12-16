<template>
  <div class="my-posts-container">
    <el-card>
      <template #header>
        <div class="header-row">
          <span class="title">我的文章</span>
          <el-button type="primary" @click="showCreateDialog"
            >发布新文章</el-button
          >
        </div>
      </template>

      <el-empty v-if="posts.length === 0" description="您还没有发布文章" />

      <el-table v-else :data="posts" style="width: 100%">
        <el-table-column prop="title" label="标题" />
        <el-table-column prop="viewCount" label="浏览量" width="100" />
        <el-table-column prop="createdAt" label="发布时间" width="180">
          <template #default="scope">
            {{ formatDate(scope.row.createdAt) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200">
          <template #default="scope">
            <el-button
              type="text"
              size="small"
              @click="goToDetail(scope.row.id)"
              >查看</el-button
            >
            <el-button
              type="text"
              size="small"
              @click="showEditDialog(scope.row)"
              >编辑</el-button
            >
            <el-button
              type="text"
              size="small"
              @click="handleDelete(scope.row.id)"
              >删除</el-button
            >
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 创建/编辑文章对话框 -->
    <el-dialog
      v-model="dialogVisible"
      :title="isEdit ? '编辑文章' : '发布文章'"
      width="600px"
    >
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
        <el-button type="primary" :loading="loading" @click="handleSubmit">
          {{ isEdit ? "保存" : "发布" }}
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { useRouter } from "vue-router";
import { ElMessage, ElMessageBox } from "element-plus";
import { getMyPosts, createPost, updatePost, deletePost } from "@/api/post";

const router = useRouter();
const posts = ref([]);
const dialogVisible = ref(false);
const postFormRef = ref(null);
const loading = ref(false);
const isEdit = ref(false);
const currentPostId = ref(null);

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
    const res = await getMyPosts();
    posts.value = res.data || [];
  } catch (error) {
    console.error("加载文章列表失败:", error);
  }
};

const showCreateDialog = () => {
  isEdit.value = false;
  postForm.value = { title: "", content: "" };
  dialogVisible.value = true;
};

const showEditDialog = (post) => {
  isEdit.value = true;
  currentPostId.value = post.id;
  postForm.value = {
    title: post.title,
    content: post.content,
  };
  dialogVisible.value = true;
};

const handleSubmit = async () => {
  if (!postFormRef.value) return;

  await postFormRef.value.validate(async (valid) => {
    if (valid) {
      loading.value = true;
      try {
        if (isEdit.value) {
          await updatePost(currentPostId.value, postForm.value);
          ElMessage.success("更新成功");
        } else {
          await createPost(postForm.value);
          ElMessage.success("发布成功");
        }
        dialogVisible.value = false;
        loadPosts();
      } catch (error) {
        console.error("操作失败:", error);
      } finally {
        loading.value = false;
      }
    }
  });
};

const handleDelete = async (id) => {
  try {
    await ElMessageBox.confirm("确定要删除这篇文章吗？", "提示", {
      confirmButtonText: "确定",
      cancelButtonText: "取消",
      type: "warning",
    });

    await deletePost(id);
    ElMessage.success("删除成功");
    loadPosts();
  } catch (error) {
    if (error !== "cancel") {
      console.error("删除失败:", error);
    }
  }
};

const goToDetail = (id) => {
  router.push(`/posts/${id}`);
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
.my-posts-container {
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
</style>

