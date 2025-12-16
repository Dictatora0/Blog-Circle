<template>
  <div class="my-comments-container">
    <el-card>
      <template #header>
        <span class="title">我的评论</span>
      </template>

      <el-empty v-if="comments.length === 0" description="您还没有发表评论" />

      <el-table v-else :data="comments" style="width: 100%">
        <el-table-column prop="content" label="评论内容" />
        <el-table-column prop="createdAt" label="评论时间" width="180">
          <template #default="scope">
            {{ formatDate(scope.row.createdAt) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150">
          <template #default="scope">
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

    <!-- 编辑评论对话框 -->
    <el-dialog v-model="dialogVisible" title="编辑评论" width="500px">
      <el-input
        v-model="commentContent"
        type="textarea"
        :rows="5"
        placeholder="请输入评论内容"
      />
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="loading" @click="handleUpdate"
          >保存</el-button
        >
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import { getMyComments, updateComment, deleteComment } from "@/api/comment";

const comments = ref([]);
const dialogVisible = ref(false);
const loading = ref(false);
const currentCommentId = ref(null);
const commentContent = ref("");

const loadComments = async () => {
  try {
    const res = await getMyComments();
    comments.value = res.data || [];
  } catch (error) {
    console.error("加载评论列表失败:", error);
  }
};

const showEditDialog = (comment) => {
  currentCommentId.value = comment.id;
  commentContent.value = comment.content;
  dialogVisible.value = true;
};

const handleUpdate = async () => {
  if (!commentContent.value.trim()) {
    ElMessage.warning("请输入评论内容");
    return;
  }

  loading.value = true;
  try {
    await updateComment(currentCommentId.value, {
      content: commentContent.value,
    });
    ElMessage.success("更新成功");
    dialogVisible.value = false;
    loadComments();
  } catch (error) {
    console.error("更新失败:", error);
  } finally {
    loading.value = false;
  }
};

const handleDelete = async (id) => {
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
  loadComments();
});
</script>

<style scoped>
.my-comments-container {
  max-width: 1200px;
  margin: 0 auto;
}

.title {
  font-size: 18px;
  font-weight: bold;
}
</style>

