#!/bin/bash

###############################################################
# 完整系统验证脚本
# 依次检查：数据库 -> 后端 -> 前端
###############################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

cd "$(dirname "$0")/.."

echo ""
echo -e "${BOLD}${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║                                                            ║${NC}"
echo -e "${BOLD}${MAGENTA}║       系统完整验证                                         ║${NC}"
echo -e "${BOLD}${MAGENTA}║       Full System Verification                             ║${NC}"
echo -e "${BOLD}${MAGENTA}║                                                            ║${NC}"
echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

ERRORS=0

# 1. 数据库检查
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  第 1/3 部分: 数据库集群  ${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

if ./scripts/check_db.sh; then
    echo -e "${GREEN}✓ 数据库检查通过${NC}"
else
    echo -e "${RED}✗ 数据库检查失败${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""
sleep 2

# 2. 后端检查
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  第 2/3 部分: 后端服务  ${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

if ./scripts/check_backend.sh; then
    echo -e "${GREEN}✓ 后端检查通过${NC}"
else
    echo -e "${RED}✗ 后端检查失败${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""
sleep 2

# 3. 前端检查
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  第 3/3 部分: 前端服务  ${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

if ./scripts/check_frontend.sh; then
    echo -e "${GREEN}✓ 前端检查通过${NC}"
else
    echo -e "${RED}✗ 前端检查失败${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# 总结
echo -e "${BOLD}${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║                                                            ║${NC}"

if [ $ERRORS -eq 0 ]; then
    echo -e "${BOLD}${MAGENTA}║              验证完成 - 所有测试通过！                     ║${NC}"
    echo -e "${BOLD}${MAGENTA}║              Verification Complete - All Tests Passed!     ║${NC}"
else
    echo -e "${BOLD}${MAGENTA}║              验证完成 - 发现 ${ERRORS} 个问题                       ║${NC}"
    echo -e "${BOLD}${MAGENTA}║              Verification Complete - ${ERRORS} Issues Found         ║${NC}"
fi

echo -e "${BOLD}${MAGENTA}║                                                            ║${NC}"
echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${BOLD}系统状态: ${GREEN}✓ 健康${NC}"
    echo ""
    echo -e "${BOLD}访问地址:${NC}"
    echo -e "  • 前端: ${CYAN}http://localhost:8080${NC}"
    echo -e "  • 后端: ${CYAN}http://localhost:8081${NC}"
    echo ""
    exit 0
else
    echo -e "${BOLD}系统状态: ${RED}✗ 发现问题${NC}"
    echo ""
    echo -e "${BOLD}故障排查:${NC}"
    echo -e "  • 查看日志: ${CYAN}docker-compose -f docker-compose-gaussdb-cluster.yml logs${NC}"
    echo -e "  • 重启服务: ${CYAN}./scripts/full_restart.sh${NC}"
    echo ""
    exit 1
fi
