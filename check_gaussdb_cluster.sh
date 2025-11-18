#!/usr/bin/env bash

# 添加 sshpass 路径（Mac Homebrew）
export PATH=/opt/homebrew/bin:$PATH

# 创建报告文件夹
mkdir -p reports

# 清理旧报告文件，只保留最新的3个
if [ -d "reports" ]; then
  # 列出所有 .txt 文件，按修改时间倒序（最新在前），跳过前3个，删除其余
  ls -t reports/*.txt 2>/dev/null | tail -n +4 | xargs rm -f 2>/dev/null || true
fi

########################################
# GaussDB 一主两备集群验证脚本
########################################

# ==== 基本配置（按你提供的环境信息） ====
DB_PORT=5432

PRIMARY_IP="10.211.55.11"
PRIMARY_ROOT_PWD="747599qw@"

STANDBY1_IP="10.211.55.14"
STANDBY1_ROOT_PWD="747599qw@1"

STANDBY2_IP="10.211.55.13"
STANDBY2_ROOT_PWD="747599qw@2"

REPORT_FILE="reports/gaussdb_cluster_report_$(date +%Y%m%d_%H%M%S).txt"
overall_ok=1

# 测试统计
test_total=0
test_passed=0
test_failed=0

# 数据库连接信息
DB_NAME="postgres"
DB_USER="omm"
TEST_TABLE="cluster_test_$(date +%s)"

# ==== 前置检查 ====
echo "前置检查中..."
command -v sshpass >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "ERROR: 未找到 sshpass，请先安装后再运行本脚本。"
  echo "Mac 上安装示例：brew install hudochenkov/sshpass/sshpass"
  echo "openEuler 上示例：yum install -y sshpass"
  exit 1
fi

# 前置 SSH 连接测试
echo "测试 SSH 连接到各节点..."
for ip in "$PRIMARY_IP" "$STANDBY1_IP" "$STANDBY2_IP"; do
  pwd_var="${ip//./_}_PWD"  # 动态变量名
  case "$ip" in
    "$PRIMARY_IP") pwd="$PRIMARY_ROOT_PWD" ;;
    "$STANDBY1_IP") pwd="$STANDBY1_ROOT_PWD" ;;
    "$STANDBY2_IP") pwd="$STANDBY2_ROOT_PWD" ;;
  esac
  echo "测试连接到 $ip..."
  test_out=$(sshpass -p "$pwd" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 root@"$ip" "echo 'SSH OK'" 2>&1)
  if [[ "$test_out" == *"SSH OK"* ]]; then
    echo "  ✓ $ip 连接成功"
  else
    echo "  ✗ $ip 连接失败: $test_out"
    echo "请检查：1. IP/密码正确 2. openEuler 允许 root SSH (修改 /etc/ssh/sshd_config: PermitRootLogin yes && systemctl restart sshd)"
    overall_ok=0
  fi
done
if [ "$overall_ok" -eq 0 ]; then
  echo "SSH 连接测试失败，请修复后再运行。"
  exit 1
fi
echo "SSH 连接测试通过。"
echo ""

# ==== 通用远程执行函数（修复编码问题）====
run_remote() {
  local pwd="$1"
  local host="$2"
  shift 2
  local cmd="$*"

  # 设置 UTF-8 编码
  sshpass -p "$pwd" ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=10 \
    root@"$host" "export LC_ALL=zh_CN.UTF-8; $cmd"
}

# ==== 测试结果记录函数 ====
record_test() {
  local test_name="$1"
  local result="$2"  # "PASS" or "FAIL"
  local details="$3"
  
  test_total=$((test_total + 1))
  
  if [ "$result" = "PASS" ]; then
    test_passed=$((test_passed + 1))
    echo "✓ [PASS] $test_name" >> "$REPORT_FILE"
  else
    test_failed=$((test_failed + 1))
    echo "✗ [FAIL] $test_name" >> "$REPORT_FILE"
    overall_ok=0
  fi
  
  if [ -n "$details" ]; then
    echo "  详情: $details" >> "$REPORT_FILE"
  fi
  echo "" >> "$REPORT_FILE"
}

# ==== 单节点常规检查（进程 / 端口 / 关键目录） ====
collect_node_basic() {
  local role="$1"
  local ip="$2"
  local pwd="$3"

  # 1. 检查 gaussdb 进程
  local ps_status="[异常]"
  local ps_out
  ps_out=$(run_remote "$pwd" "$ip" "ps -ef | grep gaussdb | grep -v grep" 2>/dev/null)
  if [ $? -eq 0 ] && [ -n "$ps_out" ]; then
    ps_status="[正常]"
  else
    overall_ok=0
  fi

  # 2. 检查监听端口
  local port_status="[异常]"
  local port_cmd="netstat -anp 2>/dev/null | grep gaussdb | grep LISTEN | grep ':${DB_PORT}' || ss -lntp 2>/dev/null | grep ':${DB_PORT}' | grep gaussdb"
  local port_out
  port_out=$(run_remote "$pwd" "$ip" "$port_cmd" 2>/dev/null)
  if [ $? -eq 0 ] && [ -n "$port_out" ]; then
    port_status="[正常]"
  else
    overall_ok=0
  fi

  # 3. 数据目录
  local data_dir_status="[异常]"
  local data_dir_res
  data_dir_res=$(run_remote "$pwd" "$ip" "[ -d '/var/lib/opengauss' ] && echo 'EXISTS' || echo 'MISSING'" 2>/dev/null)
  if [ "$data_dir_res" = "EXISTS" ]; then
    data_dir_status="[正常]"
  fi
  # 目录缺失仅记录，不影响总体状态

  # 4. 磁盘使用（简化）
  local disk_usage
  disk_usage=$(run_remote "$pwd" "$ip" "df -h / | tail -1 | awk '{print \$5}'" 2>/dev/null)
  disk_usage="${disk_usage:-N/A}"

  # 5. GaussDB 版本
  local version
  version=$(run_remote "$pwd" "$ip" "su - omm -c 'gsql --version' 2>/dev/null | head -1 | awk '{print \$3}'" 2>/dev/null)
  version="${version:-N/A}"

  # 输出表格行
  echo "| $role | $ps_status | $port_status | $data_dir_status | $disk_usage | $version |" >> "$REPORT_FILE"
}

# ==== 备节点：复制模式检查（pg_is_in_recovery） ====
collect_standby_replication_mode() {
  local ip="$1"
  local pwd="$2"

  # 使用 omm 账户执行：select pg_is_in_recovery();
  local rec_cmd="su - omm -c 'gsql -d postgres -p ${DB_PORT} -t -A -c \"select pg_is_in_recovery();\"' 2>/dev/null"
  local rec_out
  rec_out=$(run_remote "$pwd" "$ip" "$rec_cmd" 2>/dev/null)

  rec_out=$(echo "$rec_out" | tr -d '[:space:]')

  if [ "$rec_out" = "t" ] || [ "$rec_out" = "true" ]; then
    echo "- 复制模式：Standby（pg_is_in_recovery() = true）" >> "$REPORT_FILE"
  elif [ "$rec_out" = "f" ] || [ "$rec_out" = "false" ]; then
    echo "- 复制模式：主库（pg_is_in_recovery() = false）" >> "$REPORT_FILE"
    overall_ok=0
  else
    echo "- 复制模式：未知（pg_is_in_recovery 查询失败或输出异常：$rec_out）" >> "$REPORT_FILE"
    overall_ok=0
  fi

  # 延迟信息从主库 pg_stat_replication 获取
  echo "- 复制延迟：请参考主节点 pg_stat_replication 视图中的相关字段" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
}

# ==== 主节点：集群状态 & 复制视图 ====
collect_primary_cluster_info() {
  local ip="$PRIMARY_IP"
  local pwd="$PRIMARY_ROOT_PWD"

  echo "[主节点 $ip 集群状态（gs_om -t status）]" >> "$REPORT_FILE"

  # 使用 root 切换到 omm 执行 gs_om -t status
  local cluster_cmd="su - omm -c 'gs_om -t status' 2>/dev/null"
  local cluster_out
  cluster_out=$(run_remote "$pwd" "$ip" "$cluster_cmd" 2>/dev/null)

  if [ -n "$cluster_out" ]; then
    echo "$cluster_out" >> "$REPORT_FILE"
    if echo "$cluster_out" | grep -q "Normal"; then
      echo "- 集群状态：Normal（根据 gs_om 输出包含关键字 Normal）" >> "$REPORT_FILE"
    else
      echo "- 集群状态：异常或非 Normal（请仔细检查上方 gs_om 输出）" >> "$REPORT_FILE"
      overall_ok=0
    fi
  else
    echo "- 无法获取 gs_om -t status 输出（请确认 omm 用户及 gs_om 是否可用）" >> "$REPORT_FILE"
    # gs_om 可选，不影响核心功能
  fi

  echo "" >> "$REPORT_FILE"
  echo "[主节点 $ip 复制视图（select * from pg_stat_replication;）]" >> "$REPORT_FILE"

  # 使用 omm 执行 SQL：select * from pg_stat_replication;
  local repl_cmd="su - omm -c 'gsql -x -d postgres -p ${DB_PORT} -c \"select pid, usename, application_name, client_addr, state, sender_sent_location, receiver_write_location, receiver_flush_location, receiver_replay_location, sync_priority, sync_state from pg_stat_replication;\"' 2>/dev/null"
  local repl_out
  repl_out=$(run_remote "$pwd" "$ip" "$repl_cmd" 2>/dev/null)

  if [ -n "$repl_out" ]; then
    echo "$repl_out" >> "$REPORT_FILE"
  else
    echo "- 无法获取 pg_stat_replication 输出（请确认数据库端口/实例状态）" >> "$REPORT_FILE"
    overall_ok=0
  fi

  echo "" >> "$REPORT_FILE"
}

# ==== 报告头 ====
echo "========================================" > "$REPORT_FILE"
echo "  GaussDB 一主两备集群验证报告" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"
echo "生成时间：$(date +"%Y-%m-%d %H:%M:%S")" >> "$REPORT_FILE"
echo "主节点：$PRIMARY_IP" >> "$REPORT_FILE"
echo "备节点1：$STANDBY1_IP" >> "$REPORT_FILE"
echo "备节点2：$STANDBY2_IP" >> "$REPORT_FILE"
echo "数据库端口：$DB_PORT" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# ==== 逐节点检查 ====
echo "节点状态汇总：" >> "$REPORT_FILE"
echo "| 节点 | 进程 | 端口 | 数据目录 | 磁盘使用 | 版本 |" >> "$REPORT_FILE"
echo "|------|------|------|----------|----------|------|" >> "$REPORT_FILE"

collect_node_basic "主"   "$PRIMARY_IP" "$PRIMARY_ROOT_PWD"
collect_node_basic "备1"  "$STANDBY1_IP" "$STANDBY1_ROOT_PWD"
collect_node_basic "备2"  "$STANDBY2_IP" "$STANDBY2_ROOT_PWD"

echo "" >> "$REPORT_FILE"
echo "复制状态：" >> "$REPORT_FILE"
echo "- 具体复制模式、延迟等信息请参见下方备机详情和复制视图输出。" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 备节点复制模式
echo "备机详情：" >> "$REPORT_FILE"
echo "[备节点 $STANDBY1_IP 复制模式检查]" >> "$REPORT_FILE"
collect_standby_replication_mode "$STANDBY1_IP" "$STANDBY1_ROOT_PWD"

echo "[备节点 $STANDBY2_IP 复制模式检查]" >> "$REPORT_FILE"
collect_standby_replication_mode "$STANDBY2_IP" "$STANDBY2_ROOT_PWD"

echo "" >> "$REPORT_FILE"
echo "主节点详情：" >> "$REPORT_FILE"

# 主节点集群与复制视图
collect_primary_cluster_info

# ==== 数据库连接测试 ====
echo "" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"
echo "数据库连接测试" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "测试主节点数据库连接..."
test_db_connection() {
  local role="$1"
  local ip="$2"
  local pwd="$3"
  
  local sql_cmd="su - omm -c 'gsql -d $DB_NAME -p $DB_PORT -c \"SELECT version();\" -t' 2>&1"
  local result
  result=$(run_remote "$pwd" "$ip" "$sql_cmd" 2>&1)
  
  if echo "$result" | grep -q "openGauss\|PostgreSQL"; then
    record_test "${role}节点数据库连接" "PASS" "成功连接到 $ip:$DB_PORT"
  else
    record_test "${role}节点数据库连接" "FAIL" "无法连接到 $ip:$DB_PORT - $result"
  fi
}

test_db_connection "主" "$PRIMARY_IP" "$PRIMARY_ROOT_PWD"
test_db_connection "备1" "$STANDBY1_IP" "$STANDBY1_ROOT_PWD"
test_db_connection "备2" "$STANDBY2_IP" "$STANDBY2_ROOT_PWD"

# ==== 数据写入和复制测试 ====
echo "" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"
echo "数据复制测试" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "执行数据复制测试..."

# 在主节点创建测试表并插入数据
echo "1. 在主节点创建测试表..."
create_table_cmd="su - omm -c 'gsql -d $DB_NAME -p $DB_PORT -c \"CREATE TABLE IF NOT EXISTS $TEST_TABLE (id INT PRIMARY KEY, data VARCHAR(100), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);\"' 2>&1"
create_result=$(run_remote "$PRIMARY_ROOT_PWD" "$PRIMARY_IP" "$create_table_cmd" 2>&1)

if echo "$create_result" | grep -q "CREATE TABLE\|already exists"; then
  record_test "主节点创建测试表" "PASS" "表 $TEST_TABLE 创建成功"
  
  # 插入测试数据
  echo "2. 插入测试数据..."
  test_value="test_data_$(date +%s)"
  insert_cmd="su - omm -c 'gsql -d $DB_NAME -p $DB_PORT -c \"INSERT INTO $TEST_TABLE (id, data) VALUES (1, '\''$test_value'\'');\"' 2>&1"
  insert_result=$(run_remote "$PRIMARY_ROOT_PWD" "$PRIMARY_IP" "$insert_cmd" 2>&1)
  
  if echo "$insert_result" | grep -q "INSERT"; then
    record_test "主节点数据写入" "PASS" "成功写入数据: $test_value"
    
    # 等待复制
    echo "3. 等待数据复制（5秒）..."
    sleep 5
    
    # 在备节点验证数据
    echo "4. 验证备节点数据复制..."
    for standby_info in "备1:$STANDBY1_IP:$STANDBY1_ROOT_PWD" "备2:$STANDBY2_IP:$STANDBY2_ROOT_PWD"; do
      IFS=':' read -r role ip pwd <<< "$standby_info"
      
      select_cmd="su - omm -c 'gsql -d $DB_NAME -p $DB_PORT -t -A -c \"SELECT data FROM $TEST_TABLE WHERE id=1;\"' 2>&1"
      select_result=$(run_remote "$pwd" "$ip" "$select_cmd" 2>&1)
      select_result=$(echo "$select_result" | tr -d '[:space:]')
      
      if [ "$select_result" = "$test_value" ]; then
        record_test "${role}节点数据复制验证" "PASS" "数据已成功复制到 $ip"
      else
        record_test "${role}节点数据复制验证" "FAIL" "数据未复制或不匹配 (期望: $test_value, 实际: $select_result)"
      fi
    done
    
    # 清理测试表
    echo "5. 清理测试数据..."
    drop_cmd="su - omm -c 'gsql -d $DB_NAME -p $DB_PORT -c \"DROP TABLE IF EXISTS $TEST_TABLE;\"' 2>&1"
    run_remote "$PRIMARY_ROOT_PWD" "$PRIMARY_IP" "$drop_cmd" >/dev/null 2>&1
    
  else
    record_test "主节点数据写入" "FAIL" "插入数据失败: $insert_result"
  fi
else
  record_test "主节点创建测试表" "FAIL" "创建表失败: $create_result"
fi

# ==== 复制延迟测试 ====
echo "" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"
echo "复制延迟测试" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "检查复制延迟..."
lag_cmd="su - omm -c 'gsql -d $DB_NAME -p $DB_PORT -t -A -c \"SELECT application_name, client_addr, state, sync_state, pg_size_pretty(pg_wal_lsn_diff(sender_sent_location, receiver_replay_location)) as lag FROM pg_stat_replication;\"' 2>&1"
lag_result=$(run_remote "$PRIMARY_ROOT_PWD" "$PRIMARY_IP" "$lag_cmd" 2>&1)

if [ -n "$lag_result" ] && ! echo "$lag_result" | grep -q "ERROR\|error"; then
  echo "复制延迟信息:" >> "$REPORT_FILE"
  echo "$lag_result" >> "$REPORT_FILE"
  
  # 检查是否有大延迟
  if echo "$lag_result" | grep -q "MB\|GB"; then
    record_test "复制延迟检查" "FAIL" "检测到显著的复制延迟"
  else
    record_test "复制延迟检查" "PASS" "复制延迟在正常范围内"
  fi
else
  record_test "复制延迟检查" "FAIL" "无法获取复制延迟信息"
fi

# ==== 性能测试 ====
echo "" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"
echo "性能测试" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "执行简单查询性能测试..."
perf_test_table="perf_test_$(date +%s)"

# 创建性能测试表
perf_create_cmd="su - omm -c 'gsql -d $DB_NAME -p $DB_PORT -c \"CREATE TABLE $perf_test_table (id SERIAL PRIMARY KEY, data TEXT); INSERT INTO $perf_test_table (data) SELECT md5(random()::text) FROM generate_series(1, 1000);\"' 2>&1"
perf_create_result=$(run_remote "$PRIMARY_ROOT_PWD" "$PRIMARY_IP" "$perf_create_cmd" 2>&1)

if echo "$perf_create_result" | grep -q "INSERT"; then
  # 执行查询并测量时间
  perf_query_cmd="su - omm -c 'gsql -d $DB_NAME -p $DB_PORT -c \"\\timing on\" -c \"SELECT COUNT(*) FROM $perf_test_table;\"' 2>&1"
  perf_result=$(run_remote "$PRIMARY_ROOT_PWD" "$PRIMARY_IP" "$perf_query_cmd" 2>&1)
  
  if echo "$perf_result" | grep -q "Time:"; then
    query_time=$(echo "$perf_result" | grep "Time:" | awk '{print $2}')
    record_test "查询性能测试" "PASS" "查询1000行耗时: ${query_time}ms"
  else
    record_test "查询性能测试" "FAIL" "无法获取查询时间"
  fi
  
  # 清理性能测试表
  perf_drop_cmd="su - omm -c 'gsql -d $DB_NAME -p $DB_PORT -c \"DROP TABLE IF EXISTS $perf_test_table;\"' 2>&1"
  run_remote "$PRIMARY_ROOT_PWD" "$PRIMARY_IP" "$perf_drop_cmd" >/dev/null 2>&1
else
  record_test "查询性能测试" "FAIL" "无法创建性能测试表"
fi

# ==== 连接数测试 ====
echo "" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"
echo "连接数测试" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "检查数据库连接数..."
for node_info in "主:$PRIMARY_IP:$PRIMARY_ROOT_PWD" "备1:$STANDBY1_IP:$STANDBY1_ROOT_PWD" "备2:$STANDBY2_IP:$STANDBY2_ROOT_PWD"; do
  IFS=':' read -r role ip pwd <<< "$node_info"
  
  conn_cmd="su - omm -c 'gsql -d $DB_NAME -p $DB_PORT -t -A -c \"SELECT count(*) FROM pg_stat_activity;\"' 2>&1"
  conn_result=$(run_remote "$pwd" "$ip" "$conn_cmd" 2>&1)
  conn_count=$(echo "$conn_result" | tr -d '[:space:]')
  
  if [[ "$conn_count" =~ ^[0-9]+$ ]]; then
    record_test "${role}节点连接数检查" "PASS" "当前连接数: $conn_count"
  else
    record_test "${role}节点连接数检查" "FAIL" "无法获取连接数"
  fi
done

# ==== 总体结论 ====
echo "" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"
echo "测试总结" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "总测试数: $test_total" >> "$REPORT_FILE"
echo "通过: $test_passed" >> "$REPORT_FILE"
echo "失败: $test_failed" >> "$REPORT_FILE"
echo "通过率: $(awk "BEGIN {printf \"%.1f\", ($test_passed/$test_total)*100}")%" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "验证结论：" >> "$REPORT_FILE"
if [ "$overall_ok" -eq 1 ]; then
  echo "✓ 集群一主两备运行正常" >> "$REPORT_FILE"
  echo "  - 所有节点进程和端口正常" >> "$REPORT_FILE"
  echo "  - 数据库连接正常" >> "$REPORT_FILE"
  echo "  - 数据复制功能正常" >> "$REPORT_FILE"
  echo "  - 复制延迟在正常范围内" >> "$REPORT_FILE"
  echo "  - 性能测试通过" >> "$REPORT_FILE"
else
  echo "✗ 集群存在异常" >> "$REPORT_FILE"
  echo "  请检查上述失败的测试项" >> "$REPORT_FILE"
  echo "  建议查看详细日志进行故障排查" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"


# ==== 输出到终端 ====
echo ""
echo "========================================"
echo "验证已完成"
echo "========================================"
echo "报告文件：$REPORT_FILE"
echo "总测试数：$test_total"
echo "通过：$test_passed"
echo "失败：$test_failed"
if [ "$overall_ok" -eq 1 ]; then
  echo "状态：✓ 全部通过"
else
  echo "状态：✗ 存在失败项"
fi
echo ""
echo "================ 报告内容预览 ================"
cat "$REPORT_FILE"
echo "============================================="
echo ""
echo "提示：完整报告已保存到 $REPORT_FILE"

# 返回适当的退出码
if [ "$overall_ok" -eq 1 ]; then
  exit 0
else
  exit 1
fi