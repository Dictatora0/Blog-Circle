-- 好友关系表
CREATE TABLE IF NOT EXISTS friendship (
    id BIGSERIAL PRIMARY KEY,
    requester_id BIGINT NOT NULL,
    receiver_id BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_requester FOREIGN KEY (requester_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_receiver FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT unique_friendship UNIQUE (requester_id, receiver_id),
    CONSTRAINT check_status CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED'))
);

-- 创建索引以优化查询性能
CREATE INDEX IF NOT EXISTS idx_friendship_requester ON friendship(requester_id);
CREATE INDEX IF NOT EXISTS idx_friendship_receiver ON friendship(receiver_id);
CREATE INDEX IF NOT EXISTS idx_friendship_status ON friendship(status);
CREATE INDEX IF NOT EXISTS idx_friendship_created_at ON friendship(created_at);

-- 注释
COMMENT ON TABLE friendship IS '好友关系表';
COMMENT ON COLUMN friendship.id IS '主键ID';
COMMENT ON COLUMN friendship.requester_id IS '发起好友请求的用户ID';
COMMENT ON COLUMN friendship.receiver_id IS '接收好友请求的用户ID';
COMMENT ON COLUMN friendship.status IS '好友关系状态：PENDING(待处理)、ACCEPTED(已接受)、REJECTED(已拒绝)';
COMMENT ON COLUMN friendship.created_at IS '创建时间';

