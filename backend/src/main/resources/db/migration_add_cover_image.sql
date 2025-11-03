-- 数据库迁移脚本：为 users 表添加 cover_image 字段
-- 运行方式：psql -d your_database -f migration_add_cover_image.sql

-- 检查并添加 cover_image 字段（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='users' 
        AND column_name='cover_image'
    ) THEN
        ALTER TABLE users ADD COLUMN cover_image VARCHAR(255);
        RAISE NOTICE 'Column cover_image added to users table';
    ELSE
        RAISE NOTICE 'Column cover_image already exists in users table';
    END IF;
END $$;

