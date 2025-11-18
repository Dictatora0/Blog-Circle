package com.cloudcom.blog.annotation;

import java.lang.annotation.*;

/**
 * 标记方法使用只读数据源（备库）
 */
@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface ReadOnly {
}
