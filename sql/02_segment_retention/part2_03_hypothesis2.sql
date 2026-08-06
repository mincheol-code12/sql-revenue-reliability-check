-- ============================================
-- Part 2. 과금 세그먼트 & 리텐션
-- 가설 2: 확률형 상품 구매비중이 높을수록 월별 결제액 변동성이 크고 , 변동성이 큰 유저일수록 이탈 위험이 높을 것이다
-- (두 단계 주장: ① 확률형비중 → 변동성, ② 변동성 → 이탈위험)
-- ============================================

-- [검증쿼리 ①] 확률형 비중 4분위별 월별 결제액 변동성 비교
WITH monthly_amt AS (
    SELECT
        user_id,
        DATE_TRUNC('month', payment_time) AS pay_month,
        SUM(amount) AS month_amount
    FROM payments
    GROUP BY user_id, DATE_TRUNC('month', payment_time)
),
user_variance AS (
    SELECT user_id, STDDEV(month_amount) AS monthly_std
    FROM monthly_amt
    GROUP BY user_id
),
user_stat AS (
    SELECT
        user_id,
        ROUND(COUNT(*) FILTER (WHERE product_type = '확률형') * 100.0 / COUNT(*), 1) AS prob_ratio
    FROM payments
    GROUP BY user_id
),
user_combined AS (
    SELECT
        s.user_id,
        s.prob_ratio,
        v.monthly_std,
        NTILE(4) OVER (ORDER BY s.prob_ratio) AS prob_ratio_quartile
    FROM user_stat s
    JOIN user_variance v ON s.user_id = v.user_id
)
SELECT
    prob_ratio_quartile,
    COUNT(*) AS user_count,
    ROUND(AVG(prob_ratio), 1) AS avg_prob_ratio,
    ROUND(AVG(monthly_std), 0) AS avg_monthly_std
FROM user_combined
GROUP BY prob_ratio_quartile
ORDER BY prob_ratio_quartile;

-- [발견 ①]
-- quartile 1(비중3.9%)~4(비중67.7%)로 갈수록 avg_monthly_std가
-- 12,609 -> 17,328 -> 50,878 -> 223,832로 뚜렷하게 우상향한다.
-- -> 확률형 구매비중이 높을수록 월별 결제액 변동성이 크다 (① 확인됨)


-- [검증쿼리 ②] 변동성 4분위별 4주차 잔존율 비교
WITH monthly_amt AS (
    SELECT
        user_id,
        DATE_TRUNC('month', payment_time) AS pay_month,
        SUM(amount) AS month_amount
    FROM payments
    GROUP BY user_id, DATE_TRUNC('month', payment_time)
),
user_variance AS (
    SELECT
        user_id,
        STDDEV(month_amount) AS monthly_std,
        NTILE(4) OVER (ORDER BY STDDEV(month_amount)) AS std_quartile
    FROM monthly_amt
    GROUP BY user_id
),
week4_activity AS (
    SELECT
        u.user_id,
        EXISTS (
            SELECT 1 FROM login_sessions ls
            WHERE ls.user_id = u.user_id
              AND ls.login_date BETWEEN u.signup_date + 21 AND u.signup_date + 27
        ) AS active_week4
    FROM users u
)
SELECT
    v.std_quartile,
    COUNT(*) AS user_count,
    ROUND(AVG(v.monthly_std), 0) AS avg_monthly_std,
    ROUND(AVG(CASE WHEN w.active_week4 THEN 1 ELSE 0 END) * 100, 1) AS week4_retention_pct
FROM user_variance v
JOIN week4_activity w ON v.user_id = w.user_id
GROUP BY v.std_quartile
ORDER BY v.std_quartile;

-- [발견 ②]
-- std_quartile 1(변동성 낮음)~4(변동성 높음)로 갈수록 week4_retention_pct가
-- 39.1% -> 42.4% -> 45.4% -> 48.9%로 오히려 완만하게 우상향한다.
-- -> 가설과 반대 방향. 변동성이 클수록 이탈위험이 높다는 주장은 기각됨 (② 기각됨)

-- [임팩트]
-- 변동성은 "불안정성 신호"가 아니라 결제 규모(scale) 자체를 반영하는
-- 지표일 가능성이 높다. 결제 규모가 큰 유저(변동성도 큰)일수록
-- 가설1에서 확인했듯 애초에 잔존율이 높은 편이다.

-- [So What / 액션플랜]
-- 이탈위험 예측에는 월별 결제액 변동성보다, 가설1에서 확인된 반복구매빈도가
-- 더 유효한 지표다. 확률형 구매비중은 변동성과는 연관되지만(①), 이탈위험
-- 예측 변수로 직접 채택하지 않는다.

-- 결론: 가설 2는 절반만 지지됨 (① 확률형비중->변동성: 지지 / ② 변동성->이탈: 기각)
