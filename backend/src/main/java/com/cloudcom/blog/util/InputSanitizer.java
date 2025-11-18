package com.cloudcom.blog.util;

import java.util.regex.Pattern;

/**
 * 输入安全处理工具类
 * 用于防止 XSS、SQL 注入等安全问题
 */
public class InputSanitizer {

    // XSS 危险标签和属性的正则表达式
    private static final Pattern SCRIPT_PATTERN = Pattern.compile("<script[^>]*>.*?</script>", Pattern.CASE_INSENSITIVE | Pattern.DOTALL);
    private static final Pattern IFRAME_PATTERN = Pattern.compile("<iframe[^>]*>.*?</iframe>", Pattern.CASE_INSENSITIVE | Pattern.DOTALL);
    private static final Pattern EVENT_PATTERN = Pattern.compile("\\s*on\\w+\\s*=", Pattern.CASE_INSENSITIVE);
    private static final Pattern DANGEROUS_TAGS = Pattern.compile("<(script|iframe|object|embed|link|meta|style)[^>]*>", Pattern.CASE_INSENSITIVE);

    /**
     * 清理 XSS 攻击
     * 移除危险的 HTML 标签和事件处理器
     */
    public static String sanitizeXSS(String input) {
        if (input == null) {
            return null;
        }

        String sanitized = input;

        // 移除 script 标签
        sanitized = SCRIPT_PATTERN.matcher(sanitized).replaceAll("");

        // 移除 iframe 标签
        sanitized = IFRAME_PATTERN.matcher(sanitized).replaceAll("");

        // 移除事件处理器（如 onclick, onload 等）
        sanitized = EVENT_PATTERN.matcher(sanitized).replaceAll(" ");

        // 移除其他危险标签
        sanitized = DANGEROUS_TAGS.matcher(sanitized).replaceAll("");

        return sanitized;
    }

    /**
     * HTML 转义
     * 将特殊字符转换为 HTML 实体
     */
    public static String escapeHtml(String input) {
        if (input == null) {
            return null;
        }

        return input
                .replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#39;");
    }

    /**
     * HTML 反转义
     * 将 HTML 实体转换回特殊字符
     */
    public static String unescapeHtml(String input) {
        if (input == null) {
            return null;
        }

        return input
                .replace("&lt;", "<")
                .replace("&gt;", ">")
                .replace("&quot;", "\"")
                .replace("&#39;", "'")
                .replace("&amp;", "&");
    }

    /**
     * 验证输入是否包含 SQL 注入特征
     */
    public static boolean containsSQLInjectionPatterns(String input) {
        if (input == null) {
            return false;
        }

        String lowerInput = input.toLowerCase();

        // 检查常见的 SQL 注入模式
        String[] sqlPatterns = {
                "union", "select", "insert", "update", "delete", "drop",
                "create", "alter", "exec", "execute", "script", "javascript",
                "onclick", "onerror", "onload", "onmouseover"
        };

        for (String pattern : sqlPatterns) {
            if (lowerInput.contains(pattern)) {
                // 更精确的检查：确保这些关键字不是在普通文本中
                if (lowerInput.matches(".*\\b" + pattern + "\\b.*")) {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * 安全的字符串处理
     * 结合 XSS 清理和 HTML 转义
     */
    public static String sanitize(String input) {
        if (input == null) {
            return null;
        }

        // 先清理 XSS
        String sanitized = sanitizeXSS(input);

        // 再进行 HTML 转义（保留换行符）
        sanitized = sanitized
                .replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#39;");

        return sanitized;
    }

    /**
     * 验证字符串长度
     */
    public static boolean isValidLength(String input, int maxLength) {
        if (input == null) {
            return true;
        }
        return input.length() <= maxLength;
    }

    /**
     * 验证邮箱格式
     */
    public static boolean isValidEmail(String email) {
        if (email == null || email.isEmpty()) {
            return false;
        }
        String emailPattern = "^[A-Za-z0-9+_.-]+@(.+)$";
        return email.matches(emailPattern);
    }

    /**
     * 验证用户名格式（只允许字母、数字、下划线）
     */
    public static boolean isValidUsername(String username) {
        if (username == null || username.isEmpty()) {
            return false;
        }
        return username.matches("^[a-zA-Z0-9_]{3,20}$");
    }

    /**
     * 验证密码强度
     * 至少 8 个字符，包含大小写字母、数字和特殊字符
     */
    public static boolean isStrongPassword(String password) {
        if (password == null || password.length() < 8) {
            return false;
        }
        return password.matches("^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[@$!%*?&])[A-Za-z\\d@$!%*?&]{8,}$");
    }

    /**
     * 移除潜在的危险字符
     */
    public static String removeSpecialCharacters(String input) {
        if (input == null) {
            return null;
        }
        // 只保留字母、数字、中文、空格和常见标点符号
        return input.replaceAll("[^\\p{L}\\p{N}\\p{P}\\p{Z}]", "");
    }

    /**
     * 截断字符串到指定长度
     */
    public static String truncate(String input, int maxLength) {
        if (input == null) {
            return null;
        }
        if (input.length() > maxLength) {
            return input.substring(0, maxLength);
        }
        return input;
    }

    /**
     * 验证输入是否为空或仅包含空格
     */
    public static boolean isBlankOrEmpty(String input) {
        return input == null || input.trim().isEmpty();
    }

    /**
     * 安全的字符串处理（用于数据库查询）
     * 防止 SQL 注入
     */
    public static String sanitizeForDatabase(String input) {
        if (input == null) {
            return null;
        }

        // 检查 SQL 注入特征
        if (containsSQLInjectionPatterns(input)) {
            throw new IllegalArgumentException("输入包含非法字符");
        }

        // 转义单引号
        return input.replace("'", "''");
    }
}
