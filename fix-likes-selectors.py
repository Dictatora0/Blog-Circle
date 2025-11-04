#!/usr/bin/env python3
"""
批量修复 likes.spec.ts 中的选择器
"""

import re

def fix_selectors(content):
    # 修复点赞按钮选择器
    content = re.sub(
        r"postCard\.locator\('button:has-text\(\"点赞\"\), button\[class\*=\"like\"\], \[class\*=\"like-btn\"\]'\)\.first\(\)",
        "postCard.locator('button.action-btn').filter({ hasText: '🤍' }).or(postCard.locator('button.action-btn').filter({ hasText: '❤️' })).first()",
        content
    )
    
    content = re.sub(
        r"postCard\.locator\('button:has-text\(\"点赞\"\), button\[class\*=\"like\"\]'\)\.first\(\)",
        "postCard.locator('button.action-btn').filter({ hasText: '🤍' }).or(postCard.locator('button.action-btn').filter({ hasText: '❤️' })).first()",
        content
    )
    
    # 修复点赞数统计选择器
    content = re.sub(
        r"postCard\.locator\('\[class\*=\"like-count\"\], \[class\*=\"likes\"\]'\)\.first\(\)",
        "postCard.locator('.stat-item').filter({ hasText: '❤️' })",
        content
    )
    
    # 修复变量名
    content = re.sub(r'\blikeCount\b(?!Text)', 'likeStat', content)
    
    return content

if __name__ == '__main__':
    file_path = 'frontend/tests/e2e/likes.spec.ts'
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    fixed_content = fix_selectors(content)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(fixed_content)
    
    print('✅ 选择器修复完成')

