-- ============================================
-- Part 4. 결제 지표
-- 가설 2: 이상 결제는 시간대와 무관하거나 새벽에 집중될 것이다
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
)
SELECT
    f.device_flag,
    EXTRACT(HOUR FROM p.payment_time) AS payment_hour,
    COUNT(*) AS payment_count
FROM payments p
JOIN user_device_flag f ON p.user_id = f.user_id
GROUP BY f.device_flag, payment_hour
ORDER BY f.device_flag, payment_hour;

-- [발견]
-- 기기공유(의심) 그룹의 결제는 100%가 새벽 2~5시에만 발생 (다른 시간대는 0건).
-- 정상 그룹은 저녁 19~23시에 몰리되, 하루 전체에 걸쳐 자연스럽게 분포.

-- [임팩트]
-- 가설1(기기 집중)과 가설2(시간대 집중)가 서로 다른 각도에서 동일한
-- 결론(해당 300개 계정이 조직적으로 운용됨)을 뒷받침한다.

-- [So What / 액션플랜]
-- 기기공유 의심 계정군의 결제는 100% 새벽 2~5시에만 발생하며, 이는
-- 정상적인 생활 패턴으로 설명되지 않는 기계적/조직적 패턴이다. 두 가설이
-- 독립적인 신호로 같은 결론에 도달했으므로 신뢰도가 높다. 새벽 2~5시
-- 시간대 결제에 대한 실시간 모니터링 및 결제수단 검증 강화가 필요하다.

-- 결론: 가설 2 지지됨
