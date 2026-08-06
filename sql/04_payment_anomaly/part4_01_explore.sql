-- ============================================
-- Part 4. 결제 지표
-- 집계되는 매출에 비정상 결제가 섞여 있지 않은가?
-- ============================================

-- [탐색 1] 유저별 환불률 분포 (10등분하여 훑어보기)
WITH user_refund_stat AS (
    SELECT
        user_id,
        COUNT(*) AS payment_count,
        ROUND(COUNT(*) FILTER (WHERE is_refunded) * 100.0 / COUNT(*), 1) AS refund_rate_pct
    FROM payments
    GROUP BY user_id
),
user_decile AS (
    SELECT
        user_id,
        refund_rate_pct,
        NTILE(10) OVER (ORDER BY refund_rate_pct DESC) AS refund_decile
    FROM user_refund_stat
)
SELECT
    refund_decile,
    COUNT(*) AS user_count,
    ROUND(AVG(refund_rate_pct), 1) AS avg_refund_rate_pct
FROM user_decile
GROUP BY refund_decile
ORDER BY refund_decile;

-- 해석: decile 1(환불률 상위10%, 383명)만 평균 46.5%로 압도적으로 높고,
-- decile 5부터는 0%. 환불이 소수 계정에 극단적으로 집중된 구조.


-- [탐색 2 = 포착] 기기당 연결 계정 수 분포
WITH device_user_count AS (
    SELECT device_id, COUNT(DISTINCT user_id) AS linked_user_count
    FROM device_accounts
    GROUP BY device_id
)
SELECT
    linked_user_count,
    COUNT(*) AS device_count
FROM device_user_count
GROUP BY linked_user_count
ORDER BY linked_user_count DESC;

-- 포착: 전체 기기의 대다수(9,700개)는 1기기=1계정으로 정상이지만,
-- 50개 기기만 계정이 정확히 6개씩 몰려있다 (중간값 없이 1 아니면 6로 이분화).
-- 50개 x 6명 = 300명 — 탐색1에서 본 "환불률 상위10%(383명)"와 규모가 유사해
-- 서로 같은 계정군을 가리키는지 확인이 필요하다 
