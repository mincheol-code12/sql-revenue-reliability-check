-- ============================================
-- Part 4. 결제 지표
-- 가설 1: 짧은 시간 내 반복 고액결제 후 환불하는 패턴은
--         특정 계정군(기기)에 집중되어 있을 것이다
-- ============================================

-- [검증쿼리]
WITH device_group AS (
    SELECT device_id, COUNT(DISTINCT user_id) AS linked_user_count
    FROM device_accounts
    GROUP BY device_id
),
user_device_flag AS (
    SELECT
        da.user_id,
        CASE WHEN dg.linked_user_count >= 6 THEN '기기공유(의심)' ELSE '정상(1기기)' END AS device_flag
    FROM device_accounts da
    JOIN device_group dg ON da.device_id = dg.device_id
),
user_refund_stat AS (
    SELECT
        user_id,
        COUNT(*) AS payment_count,
        ROUND(COUNT(*) FILTER (WHERE is_refunded) * 100.0 / COUNT(*), 1) AS refund_rate_pct
    FROM payments
    GROUP BY user_id
)
SELECT
    f.device_flag,
    COUNT(*) AS user_count,
    ROUND(AVG(r.refund_rate_pct), 1) AS avg_refund_rate_pct
FROM user_device_flag f
JOIN user_refund_stat r ON f.user_id = r.user_id
GROUP BY f.device_flag;

-- [발견]
-- 기기공유(의심) 300명: 평균 환불률 49.1%
-- 정상(1기기) 3,529명: 평균 환불률 3.8%
-- 약 13배 차이. 탐색1의 "환불률 상위10%(383명, 46.5%)"와 규모·수치 모두
-- 유사해, 사실상 동일한 계정군을 서로 다른 각도(환불행동 vs 기기연결)에서
-- 포착한 것으로 판단된다.

-- [임팩트]
-- 환불률 이상은 무작위 개별 이상치가 아니라, 소수(50개) 기기에 집중된
-- 300개 계정군에서 조직적으로 발생하고 있다.

-- [So What / 액션플랜]
-- 환불률이 비정상적으로 높은 계정은 소수 기기에 몰려있는 계정군과 사실상
-- 일치한다. 이는 개별 유저의 우발적 환불이 아니라 조직적 계정 운용(도용
-- 또는 작업장) 정황을 시사하며, 해당 기기군에서 발생하는 결제는 매출
-- 집계에서 별도 분리하고 결제수단 검증을 강화해야 한다.

-- 결론: 가설 1 지지됨
