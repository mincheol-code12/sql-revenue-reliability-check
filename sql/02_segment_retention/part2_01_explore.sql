-- ============================================
-- Part 2. 과금 세그먼트 & 리텐션
-- 분석질문: 과금유저를 세그먼트로 나눌 때, 어떤 기준(누적결제액 vs 반복구매빈도)이 더 고객의 리텐션을 잘 설명할 수 있을 것인가?
-- ============================================

-- [탐색 1] 유저별 결제 요약 (결제횟수, 총액, 확률형 비중)
WITH user_payment_summary AS (
    SELECT
        user_id,
        COUNT(*) AS payment_count,
        SUM(amount) AS total_amount,
        ROUND(COUNT(*) FILTER (WHERE product_type = '확률형') * 100.0 / COUNT(*), 1) AS prob_type_ratio
    FROM payments
    GROUP BY user_id
)
SELECT *
FROM user_payment_summary
ORDER BY total_amount DESC;

-- 해석: 상위 결제 유저 10명의 확률형 상품 구매비중이 65~87%로,
-- 결제 규모가 클수록 확률형(가챠) 소비 의존도가 높게 나타난다.


-- [탐색 2] 결제액 5분위 매출 집중도 (파레토 확인)
WITH user_total AS (
    SELECT user_id, SUM(amount) AS total_amount
    FROM payments
    GROUP BY user_id
),
user_tier AS (
    SELECT user_id, total_amount,
           NTILE(5) OVER (ORDER BY total_amount DESC) AS tier
    FROM user_total
)
SELECT
    tier,
    COUNT(*) AS user_count,
    SUM(total_amount) AS tier_revenue,
    ROUND(SUM(total_amount) * 100.0 / SUM(SUM(total_amount)) OVER (), 1) AS revenue_pct
FROM user_tier
GROUP BY tier
ORDER BY tier;

-- 해석: 결제유저 상위 20%(tier 1)가 전체 매출의 82.9%를 차지한다.


-- [탐색 3] 결제유무별 활동일수 비교
WITH login_span AS (
    SELECT user_id, MAX(login_date) - MIN(login_date) AS active_days
    FROM login_sessions
    GROUP BY user_id
),
payment_flag AS (
    SELECT DISTINCT user_id FROM payments
)
SELECT
    CASE WHEN pf.user_id IS NOT NULL THEN '결제유저' ELSE '무과금' END AS payer_type,
    COUNT(*) AS user_count,
    ROUND(AVG(ls.active_days), 1) AS avg_active_days
FROM login_span ls
LEFT JOIN payment_flag pf ON ls.user_id = pf.user_id
GROUP BY payer_type;

-- 해석: 결제유저의 평균 활동일수(88.9일)가 무과금 유저(54.5일)보다 약 1.6배 길다.


-- [탐색 4 = 포착] 매출 상위 20% 유저 내부의 활동일수 편차
WITH user_tier AS (
    SELECT
        user_id,
        SUM(amount) AS total_amount,
        NTILE(5) OVER (ORDER BY SUM(amount) DESC) AS tier
    FROM payments
    GROUP BY user_id
),
login_span AS (
    SELECT user_id, MAX(login_date) - MIN(login_date) AS active_days
    FROM login_sessions
    GROUP BY user_id
)
SELECT
    COUNT(*) AS user_count,
    ROUND(AVG(ls.active_days), 1) AS avg_active_days,
    ROUND(STDDEV(ls.active_days), 1) AS stddev_active_days,
    MIN(ls.active_days) AS min_active_days,
    MAX(ls.active_days) AS max_active_days
FROM user_tier ut
JOIN login_span ls ON ut.user_id = ls.user_id
WHERE ut.tier = 1;

-- 포착: 매출 상위 20% 유저 내부에서도 활동일수 편차가 크게 나타난다
-- (평균 107.2일, 표준편차 45.3일, 0~180일 분포).
