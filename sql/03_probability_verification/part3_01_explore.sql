-- ============================================
-- Part 3. 확률 지표
-- 공시된 확률과 실제 가챠 확률이 일치하는가?
-- ============================================

-- [공통 VIEW] 뽑기결과 + 공시확률 + 천장진행률을 합쳐 이후 쿼리를 짧게 유지
CREATE VIEW v_gacha_detail AS
SELECT
    g.gacha_id,
    g.user_id,
    g.banner_id,
    g.pity_count,
    g.item_grade,
    CASE WHEN g.item_grade = '전설' THEN 1 ELSE 0 END AS is_legend,
    p.banner_type,
    p.disclosed_probability,
    p.pity_threshold,
    ROUND(g.pity_count * 100.0 / p.pity_threshold, 1) AS pity_progress_pct
FROM gacha_results g
JOIN probability_disclosure p ON g.banner_id = p.banner_id;


-- [탐색 1] 배너타입별 전체 평균 실제확률 vs 공시확률
SELECT
    banner_type,
    ROUND(AVG(is_legend) * 100, 2) AS actual_pct,
    ROUND(AVG(disclosed_probability) * 100, 2) AS disclosed_pct,
    COUNT(*) AS draw_count
FROM v_gacha_detail
GROUP BY banner_type;

-- 해석: 상시 배너는 실제확률(3.09%)이 공시확률(3.0%)과 거의 일치한다.
-- 반면 한정 배너는 실제확률(1.69%)이 공시확률(2.0%)보다 눈에 띄게 낮다.

