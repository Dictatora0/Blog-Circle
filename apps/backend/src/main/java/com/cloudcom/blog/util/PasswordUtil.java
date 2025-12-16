package com.cloudcom.blog.util;

import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/**
 * 密码加密工具类（使用BCrypt加密）
 */
public class PasswordUtil {

    // BCryptPasswordEncoder 支持 $2a$ 和 $2b$ 格式
    private static final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

    /**
     * 加密密码
     */
    public static String encode(String password) {
        return encoder.encode(password);
    }

    /**
     * 验证密码
     * 支持 $2a$ 和 $2b$ 格式的 BCrypt 哈希
     */
    public static boolean matches(String rawPassword, String encodedPassword) {
        try {
            return encoder.matches(rawPassword, encodedPassword);
        } catch (Exception e) {
            return false;
        }
    }
}


