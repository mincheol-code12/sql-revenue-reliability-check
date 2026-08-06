-- ============================================
-- Part 5. 종합 & 액션플랜
-- Part 2~4 결과를 결합해 총매출 vs 순매출 재산정 및 세그먼트 순위 변동 확인
-- ============================================

-- [쿼리 1] 총매출 vs 순매출 재산정
WITH device_group AS (
    SELECT device_id, COUNT(DISTINCT user_id) AS linked_user_count
    FROM device_accounts
    GROUP BY device_id
),
user_device_flag AS (
    SELECT
        da.user_id,
        CASE WHEN dg.linked_user_count >= 6 THEN '이상계정' ELSE '정상계정' END AS device_flag
    FROM device_accounts da
    JOIN device_group dg ON da.device_id = dg.device_id
)
SELECT
    ROUND(SUM(p.amount), 0) AS gross_revenue,
    ROUND(SUM(p.amount) FILTER (WHERE p.is_refunded), 0) AS refunded_amount,
    ROUND(SUM(p.amount) FILTER (WHERE NOT p.is_refunded), 0) AS refund_adjusted_net_revenue,
    ROUND(SUM(p.amount) FILTER (WHERE NOT p.is_refunded AND f.device_flag = '이상계정'), 0) AS abnormal_remaining_revenue,
    ROUND(SUM(p.amount) FILTER (WHERE NOT p.is_refunded AND f.device_flag = '정상계정'), 0) AS final_net_revenue
FROM payments p
JOIN user_device_flag f ON p.user_id = f.user_id;

-- [발견 1]
-- 총매출 21억 3,533만원 -> 최종 순매출 16억 7,704만원 (78.5%)
-- 총매출의 21.5%가 환불(12.5%)과 이상계정 잔여매출(8.9%)로 구성된 왜곡분


-- [쿼리 2] 세그먼트(고과금 유저 상위5%) 순위 변동 - 총매출 기준 vs 순매출 기준
WITH device_group AS (
    SELECT device_id, COUNT(DISTINCT user_id) AS linked_user_count
    FROM device_accounts
    GROUP BY device_id
),
user_device_flag AS (
    SELECT
        da.user_id,
        CASE WHEN dg.linked_user_count >= 6 THEN '이상계정' ELSE '정상계정' END AS device_flag
    FROM device_accounts da
    JOIN device_group dg ON da.device_id = dg.device_id
),
user_revenue AS (
    SELECT
        u.user_id,
        COALESCE(SUM(p.amount), 0) AS gross_amount,
        COALESCE(SUM(p.amount) FILTER (WHERE NOT p.is_refunded AND f.device_flag = '정상계정'), 0) AS net_amount
    FROM users u
    LEFT JOIN payments p ON u.user_id = p.user_id
    LEFT JOIN user_device_flag f ON u.user_id = f.user_id
    GROUP BY u.user_id
),
user_rank AS (
    SELECT
        user_id,
        NTILE(20) OVER (ORDER BY gross_amount DESC) AS gross_tier,
        NTILE(20) OVER (ORDER BY net_amount DESC) AS net_tier
    FROM user_revenue
)
SELECT
    COUNT(*) FILTER (WHERE gross_tier = 1) AS gross_top5_count,
    COUNT(*) FILTER (WHERE gross_tier = 1 AND net_tier = 1) AS overlap_count,
    COUNT(*) FILTER (WHERE gross_tier = 1 AND net_tier != 1) AS dropped_out_count
FROM user_rank;

-- [발견 2]
-- 총매출 기준 고과금 유저(상위5%, 500명) 중 64명(12.8%)이 순매출 기준으로는
-- 상위5%에서 탈락. 세그먼트 정의 자체가 매출 왜곡(환불/이상계정)의 영향을 받고
-- 있었음을 확인 


-- ============================================
-- 최종 액션플랜 (우선순위)
-- ============================================
-- 1순위 (Part4) 조직적 계정군(300명, 새벽 2~5시·기기당 6계정 집중) 매출을
--        집계에서 분리하고, 결제수단 검증 및 새벽 시간대 실시간 모니터링 강화
--        - 근거: 총매출의 8.9%가 이 계정군에서 발생, 두 독립 신호(기기/시간대)로 재확인됨
--
-- 2순위 (Part2) 고과금 유저 세그먼트를 결제액(1차) x 반복구매빈도(2차) 조합
--        기준으로 재정의하고, 반드시 순매출 기준으로 산정
--        - 근거: 세그먼트 내부 리텐션 편차 2배(76.4% vs 38.8%), 이상계정 혼입 12.8%
--
-- 3순위 (Part3) 한정 배너 확정지급 이전 구간의 확률 공시 로직 재점검
--        - 근거: 전체 뽑기의 99.9%가 이 구간에서 발생하며 공시확률보다 지속적으로 낮음
--
-- 종합 결론: 총매출(21.5억)의 21.5%가 신뢰할 수 없는 왜곡분으로 확인되었으며,
-- 이 왜곡은 세그먼트 판단(Part2), 확률 공시(Part3), 결제 이상(Part4) 부분에서 순매출·재현가능 매출 기준으로 핵심 지표를 재구성해야 한다.
