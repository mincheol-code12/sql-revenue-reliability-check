-- =========================================================
-- SQL 기반 게임 BM 신뢰성 검증 프로젝트
-- 과금 세그먼트 · 확률형 아이템 · 결제 데이터 3개 축 분석
-- =========================================================

DROP TABLE IF EXISTS ground_truth_labels CASCADE;
DROP TABLE IF EXISTS login_sessions CASCADE;
DROP TABLE IF EXISTS device_accounts CASCADE;
DROP TABLE IF EXISTS onboarding_events CASCADE;
DROP TABLE IF EXISTS gacha_results CASCADE;
DROP TABLE IF EXISTS probability_disclosure CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- 1) 유저 기본정보
CREATE TABLE users (
    user_id      INT PRIMARY KEY,
    signup_date  DATE NOT NULL,
    country      VARCHAR(10),
    platform     VARCHAR(20)
);

-- 2) 결제 원장
CREATE TABLE payments (
    payment_id      INT PRIMARY KEY,
    user_id         INT NOT NULL REFERENCES users(user_id),
    payment_time    TIMESTAMP NOT NULL,
    amount          NUMERIC(12,0) NOT NULL,
    product_id      VARCHAR(50),
    product_type    VARCHAR(10) CHECK (product_type IN ('확정형','확률형')),
    device_id       VARCHAR(20),
    payment_method  VARCHAR(20),
    is_refunded     BOOLEAN DEFAULT FALSE,
    refund_time     TIMESTAMP
);

-- 3) 확률형 아이템 공시확률 마스터
CREATE TABLE probability_disclosure (
    banner_id               INT PRIMARY KEY,
    item_grade              VARCHAR(10),
    disclosed_probability   NUMERIC(6,4) NOT NULL,
    pity_threshold           INT NOT NULL,
    banner_type              VARCHAR(10) CHECK (banner_type IN ('상시','한정'))
);

-- 4) 뽑기(가챠) 결과
CREATE TABLE gacha_results (
    gacha_id     INT PRIMARY KEY,
    user_id      INT NOT NULL REFERENCES users(user_id),
    banner_id    INT NOT NULL REFERENCES probability_disclosure(banner_id),
    gacha_time   TIMESTAMP NOT NULL,
    item_grade   VARCHAR(10),
    pity_count   INT NOT NULL   -- 해당 배너 내 누적 시행 순번 (천장 카운트)
);

-- 5) 온보딩 마일스톤 이벤트
CREATE TABLE onboarding_events (
    event_id     INT PRIMARY KEY,
    user_id      INT NOT NULL REFERENCES users(user_id),
    event_type   VARCHAR(20),   -- 가입 / 튜토리얼완료 / 첫결제
    event_time   TIMESTAMP NOT NULL
);

-- 6) 기기-계정 연결 정보 (이상결제 탐지용)
CREATE TABLE device_accounts (
    device_id    VARCHAR(20) NOT NULL,
    user_id      INT NOT NULL REFERENCES users(user_id),
    linked_date  DATE
);

-- 7) 일단위 로그인 로그 (리텐션/코호트 계산용 원본)
CREATE TABLE login_sessions (
    session_id             INT PRIMARY KEY,
    user_id                INT NOT NULL REFERENCES users(user_id),
    login_date              DATE NOT NULL,
    session_duration_min    INT
);

-- 8) 검증 전용 정답 라벨 (synthetic 데이터에만 존재, 운영 DB엔 없음)
--    탐지 결과와 JOIN하여 정밀도/재현율 계산에 사용
CREATE TABLE ground_truth_labels (
    user_id                            INT PRIMARY KEY REFERENCES users(user_id),
    is_abnormal_payment                BOOLEAN,
    is_probability_distorted_banner    BOOLEAN
);

-- =========================================================
-- 데이터 적재 예시 (psql \copy 사용, 클라이언트 로컬 파일 기준)
-- =========================================================
-- \copy users FROM 'data/users.csv' WITH (FORMAT csv, HEADER true);
-- \copy payments FROM 'data/payments.csv' WITH (FORMAT csv, HEADER true);
-- \copy probability_disclosure FROM 'data/probability_disclosure.csv' WITH (FORMAT csv, HEADER true);
-- \copy gacha_results FROM 'data/gacha_results.csv' WITH (FORMAT csv, HEADER true);
-- \copy onboarding_events FROM 'data/onboarding_events.csv' WITH (FORMAT csv, HEADER true);
-- \copy device_accounts FROM 'data/device_accounts.csv' WITH (FORMAT csv, HEADER true);
-- \copy login_sessions FROM 'data/login_sessions.csv' WITH (FORMAT csv, HEADER true);
-- \copy ground_truth_labels FROM 'data/ground_truth_labels.csv' WITH (FORMAT csv, HEADER true);

CREATE INDEX idx_payments_user ON payments(user_id);
CREATE INDEX idx_payments_time ON payments(payment_time);
CREATE INDEX idx_gacha_user_banner ON gacha_results(user_id, banner_id);
CREATE INDEX idx_login_user_date ON login_sessions(user_id, login_date);
