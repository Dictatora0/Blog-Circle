# 测试修复说明

## 🔧 已修复的问题

### 1. Java 23 兼容性问题

**问题**: Mockito 使用的 Byte Buddy 版本不支持 Java 23
```
Java 23 (67) is not supported by the current version of Byte Buddy which officially supports Java 22 (66)
```

**解决方案**: 
- 在 `pom.xml` 中添加了 `maven-surefire-plugin` 配置
- 添加 JVM 参数 `-Dnet.bytebuddy.experimental=true` 启用 Byte Buddy 实验性支持

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <version>3.0.0</version>
    <configuration>
        <argLine>-Dnet.bytebuddy.experimental=true</argLine>
    </configuration>
</plugin>
```

### 2. UserServiceTest.testLoginSuccess 密码验证失败

**问题**: 测试使用的密码哈希与测试密码不匹配

**解决方案**: 
- 使用 `PasswordUtil.encode()` 动态生成正确的 BCrypt 哈希
- 确保测试密码与哈希匹配

### 3. UserServiceTest.testUpdateUser Mockito 错误

**问题**: `doNothing()` 只能用于 void 方法，但 `update()` 方法返回 `int`

**解决方案**: 
- 将 `doNothing().when(userMapper).update()` 改为 `when(userMapper.update()).thenReturn(1)`

### 4. Spring Boot Test 配置优化

**优化**: 
- 为 Controller 测试添加 `webEnvironment = SpringBootTest.WebEnvironment.MOCK`
- 为 Util 测试添加 `webEnvironment = SpringBootTest.WebEnvironment.NONE` 减少启动时间

## ✅ 验证结果

运行以下命令验证修复：

```bash
# 运行所有测试
cd backend
mvn clean test

# 或运行特定测试类
mvn test -Dtest=UserServiceTest
mvn test -Dtest=JwtUtilTest
mvn test -Dtest=AuthControllerTest
mvn test -Dtest=PostControllerTest
```

## 📝 注意事项

1. **Java 版本**: 如果使用 Java 23，确保添加了 Byte Buddy 实验性支持参数
2. **密码测试**: 使用 `PasswordUtil.encode()` 确保密码哈希正确
3. **Mock 方法**: 注意方法返回类型，`int` 返回类型使用 `when().thenReturn()`，`void` 使用 `doNothing()`

## 🚀 下一步

所有测试应该能够正常运行。如果还有问题，请检查：
- Java 版本（建议使用 Java 17 或更高版本）
- Maven 配置是否正确
- 测试数据是否正确

