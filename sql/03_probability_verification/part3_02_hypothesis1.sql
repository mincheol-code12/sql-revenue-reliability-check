-- ============================================
-- Part 3. 확률 지표
-- 가설 1: 한정배너의 경우 가챠확률이 공시확률보다 낮을 것이다
-- ============================================

-- [탐색] 천장(pity_threshold) 값 확인 - 구간을 나누기 전에 배너별 천장 횟수부터 파악
SELECT DISTINCT banner_type, pity_threshold
FROM v_gacha_detail
ORDER BY banner_type;
-- 발견: 상시 배너는 천장 100회, 한정 배너는 천장 80회.
-- 천장 도달시점은 100% 확정지급되므로,
-- 이 구간을 분리하지 않으면 확정지급 건이 섞여 평균이 왜곡된다.


-- [검증쿼리] 천장 진행률 3단계(천장 전 / 천장 임박 / 확정지급)로 분리하여 비교
SELECT
    CASE
        WHEN pity_progress_pct < 50 THEN '1. 천장 전 구간 (0~49%)'
        WHEN pity_progress_pct < 100 THEN '2. 천장 임박 구간 (50~99%)'
        ELSE '3. 천장 도달 (100%, 확정지급)'
    END AS pity_stage,
    ROUND(AVG(is_legend) * 100, 2) AS actual_pct,
    ROUND(AVG(disclosed_probability) * 100, 2) AS disclosed_pct,
    COUNT(*) AS draw_count
FROM v_gacha_detail
WHERE banner_type = '한정'
GROUP BY pity_stage
ORDER BY pity_stage;

-- [발견]
-- 1. 천장 전 구간(0~49%): 실제확률 1.61% vs 공시확률 2.0%, 98,602건
-- 2. 천장 임박 구간(50~99%): 실제확률 1.75% vs 공시확률 2.0%, 9,041건
-- 3. 확정지급(100%): 실제확률 100% (설계상 당연), 80건
--
-- 확정지급 구간을 분리해서 보면, 확정지급 전 모든 구간(1+2, 전체 뽑기의
-- 99.93%)에서 실제확률이 공시확률보다 계속 낮게 유지된다. 

-- [배너별 재현성 체크] (확정지급 제외, 6개 배너 개별 확인)
SELECT
    banner_id,
    ROUND(AVG(is_legend) * 100, 2) AS actual_pct,
    ROUND(AVG(disclosed_probability) * 100, 2) AS disclosed_pct,
    COUNT(*) AS draw_count
FROM v_gacha_detail
WHERE banner_type = '한정'
  AND pity_progress_pct < 100
GROUP BY banner_id
ORDER BY banner_id;

-- [임팩트]
-- 유저가 실제로 결제·소비하며 경험하는 뽑기의 99.93%가 확정지급 이전 구간에서
-- 발생하며, 이 구간의 실제확률은 공시확률보다 지속적으로 낮다. 

-- [So What / 액션플랜]
-- 한정 배너는 확정지급(천장 도달) 시점을 제외한 전 구간에서 실제확률이
-- 공시확률보다 지속적으로 낮다. 전체 뽑기의 99.9% 이상이 이 구간에서
-- 발생하므로, 유저가 실제로 경험하는 확률은 광고된 수치보다 명백히 낮다.
-- 확률 공시 로직 전반(특히 확정지급 이전 구간)의 재점검이 필요하다.

-- 결론: 가설 1 지지됨
