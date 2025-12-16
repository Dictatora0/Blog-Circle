<template>
  <div class="post-detail-container">
    <el-card v-if="post">
      <template #header>
        <div class="header-row">
          <h2>{{ post.title }}</h2>
          <div v-if="isAuthor">
            <el-button type="primary" size="small" @click="showEditDialog"
              >编辑</el-button
            >
            <el-button type="danger" size="small" @click="handleDelete"
              >删除</el-button
            >
          </div>
        </div>
        <div class="post-info">
          <span>作者：{{ post.authorName }}</span>
          <span>浏览：{{ post.viewCount }}</span>
          <span>{{ formatDate(post.createdAt) }}</span>
        </div>
      </template>

      <div class="post-content">
        {{ post.content }}
      </div>
    </el-card>

    <!-- 评论区 -->
    <el-card class="comments-section">
      <template #header>
        <span>评论 ({{ comments.length }})</span>
      </template>

      <div v-if="userStore.token" class="comment-input">
        <el-input
          v-model="commentContent"
          type="textarea"
          :rows="3"
          placeholder="写下你的评论..."
        />
        <el-button
          type="primary"
          style="margin-top: 10px"
          :loading="commentLoading"
          @click="handleAddComment"
        >
          发表评论
        </el-button>
      </div>

      <el-empty v-if="comments.length === 0" description="暂无评论" />

      <div v-else class="comments-list">
        <div v-for="comment in comments" :key="comment.id" class="comment-item">
          <div class="comment-header">
            <span class="comment-user">{{
              comment.nickname || comment.username
            }}</span>
            <span class="comment-time">{{
              formatDate(comment.createdAt)
            }}</span>
          </div>
          <div class="comment-content">{{ comment.content }}</div>
          <div
            v-if="comment.userId === userStore.userInfo?.id"
            class="comment-actions"
          >
            <el-button
              type="text"
              size="small"
              @click="showEditCommentDialog(comment)"
              >编辑</el-button
            >
            <el-button
              type="text"
              size="small"
              @click="handleDeleteComment(comment.id)"
              >删除</el-button
            >
          </div>
        </div>
      </div>
    </el-card>

    <!-- 编辑文章对话框 -->
    <el-dialog v-model="editDialogVisible" title="编辑文章" width="600px">
      <el-form :model="editForm" :rules="rules" ref="editFormRef">
        <el-form-item label="标题" prop="title">
          <el-input v-model="editForm.title" />
        </el-form-item>
        <el-form-item label="内容" prop="content">
          <el-input v-model="editForm.content" type="textarea" :rows="10" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="editDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="loading" @click="handleUpdate"
          >保存</el-button
        >
      </template>
    </el-dialog>

    <!-- 编辑评论对话框 -->
    <el-dialog
      v-model="editCommentDialogVisible"
      title="编辑评论"
      width="500px"
    >
      <el-input v-model="editCommentContent" type="textarea" :rows="5" />
      <template #footer>
        <el-button @click="editCommentDialogVisible = false">取消</el-button>
        <el-button
          type="primary"
          :loading="commentLoading"
          @click="handleUpdateComment"
          >保存</el-button
        >
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from "vue";
import { useRouter, useRoute } from "vue-router";
import { ElMessage, ElMessageBox } from "element-plus";
import { getPostDetail, updatePost, deletePost } from "@/api/post";
import {
  getCommentsByPostId,
  createComment,
  updateComment,
  deleteComment,
} from "@/api/comment";
import { useUserStore } from "@/stores/user";

const router = useRouter();
const route = useRoute();
const userStore = useUserStore();

const post = ref(null);
const comments = ref([]);
const commentContent = ref("");
const commentLoading = ref(false);
const editDialogVisible = ref(false);
const editFormRef = ref(null);
const loading = ref(false);
const editCommentDialogVisible = ref(false);
const editCommentContent = ref("");
const currentCommentId = ref(null);

const editForm = ref({
  title: "",
  content: "",
});

const rules = {
  title: [{ required: true, message: "请输入文章标题", trigger: "blur" }],
  content: [{ required: true, message: "请输入文章内容", trigger: "blur" }],
};

const isAuthor = computed(() => {
  return (
    post.value &&
    userStore.userInfo &&
    post.value.authorId === userStore.userInfo.id
  );
});

const loadPost = async () => {
  try {
    const res = await getPostDetail(route.params.id);
    post.value = res.data;
  } catch (error) {
    console.error("加载文章详情失败:", error);
    router.push("/posts");
  }
};

const loadComments = async () => {
  try {
    const res = await getCommentsByPostId(route.params.id);
    comments.value = res.data || [];
  } catch (error) {
    console.error("加载评论失败:", error);
  }
};

const handleAddComment = async () => {
  if (!commentContent.value.trim()) {
    ElMessage.warning("请输入评论内容");
    return;
  }

  commentLoading.value = true;
  try {
    await createComment({
      postId: route.params.id,
      content: commentContent.value,
    });
    ElMessage.success("评论成功");
    commentContent.value = "";
    loadComments();
  } catch (error) {
    console.error("评论失败:", error);
  } finally {
    commentLoading.value = false;
  }
};

const showEditDialog = () => {
  editForm.value = {
    title: post.value.title,
    content: post.value.content,
  };
  editDialogVisible.value = true;
};

const handleUpdate = async () => {
  if (!editFormRef.value) return;

  await editFormRef.value.validate(async (valid) => {
    if (valid) {
      loading.value = true;
      try {
        await updatePost(route.params.id, editForm.value);
        ElMessage.success("更新成功");
        editDialogVisible.value = false;
        loadPost();
      } catch (error) {
        console.error("更新失败:", error);
      } finally {
        loading.value = false;
      }
    }
  });
};

const handleDelete = async () => {
  try {
    await ElMessageBox.confirm("确定要删除这篇文章吗？", "提示", {
      confirmButtonText: "确定",
      cancelButtonText: "取消",
      type: "warning",
    });

    await deletePost(route.params.id);
    ElMessage.success("删除成功");
    router.push("/posts");
  } catch (error) {
    if (error !== "cancel") {
      console.error("删除失败:", error);
    }
  }
};

const showEditCommentDialog = (comment) => {
  currentCommentId.value = comment.id;
  editCommentContent.value = comment.content;
  editCommentDialogVisible.value = true;
};

const handleUpdateComment = async () => {
  if (!editCommentContent.value.trim()) {
    ElMessage.warning("请输入评论内容");
    return;
  }

  commentLoading.value = true;
  try {
    await updateComment(currentCommentId.value, {
      content: editCommentContent.value,
    });
    ElMessage.success("更新成功");
    editCommentDialogVisible.value = false;
    loadComments();
  } catch (error) {
    console.error("更新失败:", error);
  } finally {
    commentLoading.value = false;
  }
};

const handleDeleteComment = async (id) => {
  try {
    await ElMessageBox.confirm("确定要删除这条评论吗？", "提示", {
      confirmButtonText: "确定",
      cancelButtonText: "取消",
      type: "warning",
    });

    await deleteComment(id);
    ElMessage.success("删除成功");
    loadComments();
  } catch (error) {
    if (error !== "cancel") {
      console.error("删除失败:", error);
    }
  }
};

const formatDate = (dateStr) => {
  if (!dateStr) return "";
  return new Date(dateStr).toLocaleString("zh-CN");
};

onMounted(() => {
  loadPost();
  loadComments();
});
</script>

<style scoped>
.post-detail-container {
  max-width: 900px;
  margin: 0 auto;
}

.header-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.header-row h2 {
  margin: 0;
  color: #303133;
}

.post-info {
  display: flex;
  gap: 20px;
  font-size: 14px;
  color: #909399;
  margin-top: 10px;
}

.post-content {
  line-height: 1.8;
  color: #606266;
  white-space: pre-wrap;
  word-wrap: break-word;
}

.comments-section {
  margin-top: 20px;
}

.comment-input {
  margin-bottom: 20px;
}

.comments-list {
  display: flex;
  flex-direction: column;
  gap: 15px;
}

.comment-item {
  padding: 15px;
  background-color: #f5f7fa;
  border-radius: 4px;
}

.comment-header {
  display: flex;
  justify-content: space-between;
  margin-bottom: 10px;
}

.comment-user {
  font-weight: bold;
  color: #303133;
}

.comment-time {
  font-size: 12px;
  color: #909399;
}

.comment-content {
  color: #606266;
  line-height: 1.6;
  margin-bottom: 10px;
}

.comment-actions {
  display: flex;
  gap: 10px;
}
</style>

