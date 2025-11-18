package com.cloudcom.blog.aspect;

import com.cloudcom.blog.annotation.ReadOnly;
import com.cloudcom.blog.config.DataSourceConfig;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.reflect.MethodSignature;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.lang.reflect.Method;

/**
 * 数据源切换切面
 * 根据 @ReadOnly 注解自动切换到备库
 */
@Aspect
@Component
@Order(1)
public class DataSourceAspect {
    
    private static final Logger logger = LoggerFactory.getLogger(DataSourceAspect.class);

    @Around("@annotation(com.cloudcom.blog.annotation.ReadOnly) || @within(com.cloudcom.blog.annotation.ReadOnly)")
    public Object around(ProceedingJoinPoint point) throws Throwable {
        MethodSignature signature = (MethodSignature) point.getSignature();
        Method method = signature.getMethod();
        
        ReadOnly readOnly = method.getAnnotation(ReadOnly.class);
        if (readOnly == null) {
            readOnly = method.getDeclaringClass().getAnnotation(ReadOnly.class);
        }
        
        if (readOnly != null) {
            DataSourceConfig.DataSourceContextHolder.setDataSourceType(DataSourceConfig.DataSourceType.REPLICA);
            logger.debug("切换到备库（只读）: {}.{}", 
                method.getDeclaringClass().getSimpleName(), 
                method.getName());
        }
        
        try {
            return point.proceed();
        } finally {
            DataSourceConfig.DataSourceContextHolder.clearDataSourceType();
        }
    }
}
