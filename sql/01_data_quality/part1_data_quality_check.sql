--결측치 확인
SELECT
    'users' AS table_name,
    COUNT(*) FILTER (WHERE signup_date IS NULL) AS null_signup_date,
    COUNT(*) FILTER (WHERE country IS NULL) AS null_country,
    COUNT(*) FILTER (WHERE platform IS NULL) AS null_platform
FROM users
UNION ALL
SELECT
    'payments',
    COUNT(*) FILTER (WHERE payment_time IS NULL),
    COUNT(*) FILTER (WHERE amount IS NULL),
    COUNT(*) FILTER (WHERE product_type IS NULL)
FROM payments
UNION ALL
SELECT
    'gacha_results',
    COUNT(*) FILTER (WHERE gacha_time IS NULL),
    COUNT(*) FILTER (WHERE item_grade IS NULL),
    COUNT(*) FILTER (WHERE pity_count IS NULL)
FROM gacha_results;

--참조무결성
-- payments 중 users에 없는 user_id를 참조하는 행 (정상이면 0)
SELECT COUNT(*) AS orphan_payments
FROM payments p
LEFT JOIN users u ON p.user_id = u.user_id
WHERE u.user_id IS NULL;

SELECT COUNT(*) AS orphan_gacha
FROM gacha_results g
LEFT JOIN users u ON g.user_id = u.user_id
WHERE u.user_id IS NULL;

--범위 이상치
-- 결제금액 음수/0 여부
SELECT COUNT(*) AS invalid_amount
FROM payments
WHERE amount <= 0;

-- pity_count가 해당 배너의 pity_threshold를 초과하는 비정상 케이스
SELECT COUNT(*) AS pity_overflow
FROM gacha_results g
JOIN probability_disclosure p ON g.banner_id = p.banner_id
WHERE g.pity_count > p.pity_threshold;

-- 세션 시간 음수/비정상적으로 긴 경우 (예: 24시간=1440분 초과)
SELECT COUNT(*) AS invalid_session
FROM login_sessions
WHERE session_duration_min <= 0 OR session_duration_min > 1440;

--중복(pk)
SELECT payment_id, COUNT(*)
FROM payments
GROUP BY payment_id
HAVING COUNT(*) > 1;

SELECT gacha_id, COUNT(*)
FROM gacha_results
GROUP BY gacha_id
HAVING COUNT(*) > 1;

--날짜범위
SELECT COUNT(*) AS out_of_range_payments
FROM payments
WHERE payment_time < '2025-01-01' OR payment_time >= '2025-07-01';

SELECT COUNT(*) AS out_of_range_gacha
FROM gacha_results
WHERE gacha_time < '2025-01-01' OR gacha_time >= '2025-07-01';

SELECT COUNT(*) AS out_of_range_login
FROM login_sessions
WHERE login_date < '2025-01-01' OR login_date >= '2025-07-01';

--환불이 결제보다 먼저 발생한 경우
SELECT COUNT(*) AS invalid_refund_order
FROM payments
WHERE is_refunded = TRUE
  AND refund_time < payment_time;

-- 환불 표시(is_refunded=TRUE)인데 refund_time이 NULL인 경우도 체크
SELECT COUNT(*) AS refund_missing_time
FROM payments
WHERE is_refunded = TRUE AND refund_time IS NULL;
