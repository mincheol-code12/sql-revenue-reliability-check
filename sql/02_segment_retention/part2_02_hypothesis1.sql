-- ============================================
-- Part 2. 과금 세그먼트 & 리텐션
-- 가설 1: 누적결제액만으로 세그먼트를 나누면 단발성 고액결제자와 진짜 충성 고과금유저가 섞여서, 리텐션 예측력이 떨어질 것이다
-- ============================================

-- [검증쿼리]
-- 1단계: 결제액 기준 상위 5%("고과금 유저") 모집단 고정
-- 2단계: 그 안에서 결제횟수 기준으로 상/하 절반 재분류
-- 3단계: 가입 후 4주차(21~27일째) 시점 로그인 여부 = 코호트 방식 리텐션
WITH top_spender AS (
    SELECT
        u.user_id,
        u.signup_date,
        COUNT(p.payment_id) AS payment_count,
        NTILE(20) OVER (ORDER BY COALESCE(SUM(p.amount), 0) DESC) AS tier_by_amount
    FROM users u
    LEFT JOIN payments p ON u.user_id = p.user_id
    GROUP BY u.user_id, u.signup_date
),
top_spender_freq AS (
    SELECT
        user_id,
        signup_date,
        NTILE(2) OVER (ORDER BY payment_count DESC) AS freq_half
    FROM top_spender
    WHERE tier_by_amount = 1
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
    t.freq_half,
    COUNT(*) AS user_count,
    ROUND(AVG(CASE WHEN w.active_week4 THEN 1 ELSE 0 END) * 100, 1) AS week4_retention_pct
FROM top_spender_freq t
JOIN week4_activity w ON t.user_id = w.user_id
GROUP BY t.freq_half
ORDER BY t.freq_half;

-- [발견]
-- freq_half=1(빈도상위, 충성형 추정) 250명 → 4주차 잔존율 76.4%
-- freq_half=2(빈도하위, 단발형 추정) 250명 → 4주차 잔존율 38.8%
-- 결제액 상위5%("고과금 유저") 안에서도 반복구매빈도에 따라
-- 잔존율이 거의 2배 차이로 갈린다.

-- [임팩트]
-- 누적결제액 단일 기준으로 "고과금 유저"를 정의하면, 실제로는 이탈 위험이
-- 서로 다른 두 그룹(잔존율 76.4% vs 38.8%)을 하나로 묶어 관리하게 된다.

-- [So What / 액션플랜]
-- 고과금 유저 세그먼트를 결제액 단일 기준이 아니라, 결제액(1차 필터) x
-- 반복구매빈도(2차 세분화) 조합 기준으로 재정의해야 한다. 특히 결제액은
-- 크지만 빈도가 낮은 그룹(잔존율 38.8%)은 이미 이탈 위험이 높으므로,
-- 장기 리텐션 캠페인보다 즉시성 있는 재구매 유도(원포인트 오퍼) 방식으로
-- 접근을 달리해야 한다.

-- 결론: 가설 1 지지됨
