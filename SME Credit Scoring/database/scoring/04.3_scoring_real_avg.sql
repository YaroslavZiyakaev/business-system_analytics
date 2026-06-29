USE `VTB. Project 2`;  -- Подключитесь к своей БД: USE `name_of_your_database`;

CREATE TABLE metric_point -- Создаю вспомогательную таблицу, данные в которой можно обновлять, в зависимости от варьирования приоритетов эконом показателей у редактора скрипта
(
	metric_name VARCHAR(50),
	metric_value int
);

-- ==== ТАБЛИЦА КОРРЕКТИРОВКИ ВАЖНОСТИ МЕТРИК ==== ---
INSERT INTO metric_point -- В эту таблицу загружаем вес каждого показателя в числовом эквиваленте
VALUES 
	("ROS, %",18), -- Если хотите сделать ROS  более ценным относительно остальных метрик: делайте вес большИм чем у других метрик
	("ROE, %",5),
	("ROA, %",3),
	("EBITDA_Margin, %",1),
	("Долг/выручка, %",1),
	("Срок погашения долга, лет",5),
	("DSCR (покрытие долга)",6),
	("Финансовый рычаг",4),
	("Текущая ликвидность",4),
	("Доля собственных средств в активах",3),
	("Доля просрочки, %",10),
	("Доля закредитованности у других банков, %",3),
	("Краткосрочные/долгосрочные долги, %",2);


WITH -- Создаю оконную функцию 
inflation_values AS -- (0 слой)Создаю запрос, в котором определяю измнения уровня цен 2023-2024-2025
(
SELECT
	DISTINCT
	fi.report_year,
	CASE 
		WHEN fi.report_year = 2023 THEN 1.161 -- Посредством домножения сумм на эти числа(в следующем слое), будем приводить показатели к уровню цен 2025 года
		WHEN fi.report_year = 2024 THEN 1.080
		WHEN fi.report_year = 2025 THEN 1
	END as year_inflation_factor
FROM
	financial_indicators fi 
),
financial_indicators_real  AS -- (1слой)Создаю запрос, в котором привожу показатели к уровню цен 2025 года
(
SELECT
	c.name as "name",
	c.inn as "inn",
	fi.report_year as "report_year",
	fi.revenue * iv.year_inflation_factor as "revenue", 
	fi.net_profit * iv.year_inflation_factor as "net_profit",
	fi.equity * iv.year_inflation_factor as "equity",
	fi.short_term_debt * iv.year_inflation_factor as "short_term_debt",
	fi.long_term_debt * iv.year_inflation_factor as "long_term_debt",
	fi.overdue_payments * iv.year_inflation_factor as "overdue_payments",
	er.debt_to_other_banks * iv.year_inflation_factor as "debt_to_other_banks",
	er.arbitration_claims as "arbitration_claims",
	er.tax_arrears * iv.year_inflation_factor as "tax_arrears"
FROM
companies c
	INNER JOIN external_risks er  ON c.inn = er.inn 
	INNER JOIN financial_indicators fi ON c.inn = fi.inn
	INNER JOIN inflation_values iv ON iv.report_year = fi.report_year -- Делаю JOIN по годам, чтобы домножать данные определенного года на определенный коэффициент
),
financial_metrics AS  -- (2 слой)Создвю запрос, в котором посчитаю финансовые показатели для комапний
(
SELECT 
	fir.`name` as "Название компании",
	fir.`report_year`,
	-- Показатели рентабельности -- 
	ROUND((fir.`net_profit` / NULLIF(fir.revenue, 0)) * 100, 2) AS "ROS, %", -- Рентабельность продаж(чп/выручка)
	ROUND((fir.`net_profit` / NULLIF(fir.equity ,0)) * 100, 2) AS "ROE, %", -- Рентабельность капитала(чп/собственный капитал)
	ROUND((fir.`net_profit` / NULLIF(fir.equity + fir.`short_term_debt` + fir.`long_term_debt`,0)) * 100, 2) AS "ROA, %", -- Рентабельность активов(чп/вего активов)
	ROUND((fir.`net_profit` * 1.25 / NULLIF(fir.revenue ,0)) * 100, 2) AS "EBITDA_Margin, %", -- Операционная прибыль до вычета процентов и налогов(ВАЖНО! Умножаем на 1,25, потому что примерно 1/5  часть от прибыль уходит на налоговые и иные издержки)
	-- Показатели долговой нагрузки --
	ROUND(((fir.`long_term_debt`  + fir.`short_term_debt`) / NULLIF(fir.revenue, 0)) * 100,2) AS "Долг/выручка, %", --  показывает сколько % выручки уходит на погашение долгов
	ROUND((fir.`short_term_debt` + fir.`long_term_debt`) / NULLIF(fir.`net_profit` * 1.25, 0), 2) AS "Срок погашения долга, лет", 
	ROUND(fir.`net_profit` / NULLIF((fir.`short_term_debt` + fir.`long_term_debt`) * 0.2, 0), 2) AS "DSCR (покрытие долга)", -- Коэффициент покрытия долга, показывает, хватит ли денег на ежемесячные выплаты по кредиту		
	ROUND((fir.`short_term_debt` + fir.`long_term_debt`) / NULLIF(fir.`equity`, 0), 2) AS "Финансовый рычаг", -- Финансовый рычаг, показывает зависимость от зеамных денег. Чем выше, тем рискованнее
	-- Показатели ликвидности --
	ROUND((fir.`net_profit` + fir.`equity`) / NULLIF(fir.`short_term_debt`, 0),2) AS "Текущая ликвидность", -- (прибыль + капитал) / краткосрочные долги
	-- Покащатели финансовой устойчивости--
	ROUND(fir.`equity` / NULLIF(fir.`equity` + fir.`short_term_debt` + fir.`long_term_debt`, 0), 2) AS "Доля собственных средств в активах", -- Чем выше, тем устойчивее бизнес
	-- Показатели риска --
	ROUND(fir.`overdue_payments` / NULLIF(fir.`short_term_debt` + fir.`long_term_debt`, 0) * 100, 2) AS "Доля просрочки, %",
	ROUND(fir.`debt_to_other_banks` / NULLIF(fir.`short_term_debt` + fir.`long_term_debt`, 0) * 100, 2) AS "Доля закредитованности у других банков, %",
	ROUND(fir.`short_term_debt` / NULLIF(fir.`short_term_debt` + fir.`long_term_debt`, 0) * 100, 2) AS "Краткосрочные/долгосрочные долги, %" 
FROM
	financial_indicators_real fir
ORDER BY
	`ROS, %` DESC
),
scoring_query AS( -- (3 слой)Создаю второй запрос, который будет рассчитывать скоринговую сумму в зависимости от отклонений (!)средних метрик от необходимых значений
SELECT -- Важно! Я ввел систему градации: есть три порога значений, которые отсеивают "неудачные" метрики. Числовые характеристики можно менять по желанию
	financial_metrics.`Название компании`,
	(
	CASE 	
		WHEN AVG(financial_metrics.`ROS, %`) > 5 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "ROS, %")
		WHEN AVG(financial_metrics.`ROS, %`) > 4.5 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "ROS, %") * 0.8
		WHEN AVG(financial_metrics.`ROS, %`) > 4 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "ROS, %") * 0.6
		ELSE 0 
	END + 
	CASE 
		WHEN AVG(financial_metrics.`ROE, %`) > 15 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "ROE, %") 
		WHEN AVG(financial_metrics.`ROE, %`) > 14 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "ROE, %") * 0.8
		WHEN AVG(financial_metrics.`ROE, %`) > 13 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "ROE, %") * 0.6
		ELSE 0 
	END +
	CASE 
		WHEN AVG(financial_metrics.`ROA, %`) > 5 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "ROA, %")
		WHEN AVG(financial_metrics.`ROA, %`) > 4.5 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "ROA, %") * 0.8
		WHEN AVG(financial_metrics.`ROA, %`) > 4 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "ROA, %") * 0.6
		ELSE 0 
	END +
	CASE 
		WHEN AVG(financial_metrics.`EBITDA_Margin, %`) > 10 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "EBITDA_Margin, %")
		WHEN AVG(financial_metrics.`EBITDA_Margin, %`) > 9 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "EBITDA_Margin, %") * 0.8
		WHEN AVG(financial_metrics.`EBITDA_Margin, %`) > 8 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "EBITDA_Margin, %")  * 0.6
		ELSE 0 
	END +
	CASE 
		WHEN AVG(financial_metrics.`Долг/выручка, %`) < 40 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Долг/выручка, %") 
		WHEN AVG(financial_metrics.`Долг/выручка, %`) < 42.5 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Долг/выручка, %") * 0.8
		WHEN AVG(financial_metrics.`Долг/выручка, %`) < 45 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Долг/выручка, %") * 0.6
		ELSE 0 
	END +
	CASE 
		WHEN AVG(financial_metrics.`Срок погашения долга, лет`) < 3 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Срок погашения долга, лет")
		WHEN AVG(financial_metrics.`Срок погашения долга, лет`) < 3.2 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Срок погашения долга, лет")  * 0.8
		WHEN AVG(financial_metrics.`Срок погашения долга, лет`) < 3.5 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Срок погашения долга, лет") * 0.6
		ELSE 0 
	END + 
	CASE 
		WHEN AVG(financial_metrics.`DSCR (покрытие долга)`) > 1.2 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "DSCR (покрытие долга)") 
		WHEN AVG(financial_metrics.`DSCR (покрытие долга)`) > 1.1 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "DSCR (покрытие долга)") * 0.8
		WHEN AVG(financial_metrics.`DSCR (покрытие долга)`) > 1.0 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "DSCR (покрытие долга)") * 0.6
		ELSE 0 
	END + 
	CASE 
		WHEN AVG(financial_metrics.`Финансовый рычаг`) < 1.5 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Финансовый рычаг")
		WHEN AVG(financial_metrics.`Финансовый рычаг`) < 1.6 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Финансовый рычаг") * 0.8
		WHEN AVG(financial_metrics.`Финансовый рычаг`) < 1.7 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Финансовый рычаг") * 0.6
		ELSE 0 
	END +
	CASE 
		WHEN AVG(financial_metrics.`Текущая ликвидность`) > 1.5 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Текущая ликвидность")
		WHEN AVG(financial_metrics.`Текущая ликвидность`) > 1.4 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Текущая ликвидность") * 0.8
		WHEN AVG(financial_metrics.`Текущая ликвидность`) > 1.3 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Текущая ликвидность") * 0.6
		ELSE 0 
	END + 
	CASE 
		WHEN AVG(financial_metrics.`Доля собственных средств в активах`) > 0.3 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Доля собственных средств в активах") 
		WHEN AVG(financial_metrics.`Доля собственных средств в активах`) > 0.25 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Доля собственных средств в активах") * 0.8
		WHEN AVG(financial_metrics.`Доля собственных средств в активах`) > 0.2 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Доля собственных средств в активах") * 0.6
		ELSE 0 
	END + 
	CASE 
		WHEN AVG(financial_metrics.`Доля просрочки, %`) = 0 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Доля просрочки, %") 
		ELSE 0 
	END +
	CASE 
		WHEN AVG(financial_metrics.`Доля закредитованности у других банков, %`) < 30 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Доля закредитованности у других банков, %") 
		WHEN AVG(financial_metrics.`Доля закредитованности у других банков, %`) < 35 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Доля закредитованности у других банков, %") * 0.8
		WHEN AVG(financial_metrics.`Доля закредитованности у других банков, %`) < 40 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Доля закредитованности у других банков, %") * 0.6
		ELSE 0 
	END  +
	CASE 
		WHEN AVG(financial_metrics.`Краткосрочные/долгосрочные долги, %`) < 50 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Краткосрочные/долгосрочные долги, %") 
		WHEN AVG(financial_metrics.`Краткосрочные/долгосрочные долги, %`) < 52.5 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Краткосрочные/долгосрочные долги, %") * 0.8
		WHEN AVG(financial_metrics.`Краткосрочные/долгосрочные долги, %`) < 55 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Краткосрочные/долгосрочные долги, %") * 0.6
		ELSE 0 
	END) / (SELECT SUM(metric_value) FROM metric_point) as Scoring, -- Делим на сумму весов
	AVG(financial_metrics.`ROS, %`) as "ROS, %", -- Финансовые показатели ниже добавляю в SELECT для того, чтобы в итоговой витрине их тоже отобразить
	AVG(financial_metrics.`ROE, %`) as "ROE, %",
	AVG(financial_metrics.`ROA, %`) as "ROA, %",
	AVG(financial_metrics.`EBITDA_Margin, %`) as "EBITDA_Margin, %",
	AVG(financial_metrics.`Долг/выручка, %`) as "Долг/выручка, %",
	AVG(financial_metrics.`Срок погашения долга, лет`) as "Срок погашения долга, лет",
	AVG(financial_metrics.`DSCR (покрытие долга)`) as "DSCR (покрытие долга)",
	AVG(financial_metrics.`Финансовый рычаг`) as "Финансовый рычаг",
	AVG(financial_metrics.`Текущая ликвидность`) as "Текущая ликвидность",
	AVG(financial_metrics.`Доля собственных средств в активах`) as "Доля собственных средств в активах",
	AVG(financial_metrics.`Доля просрочки, %`) as "Доля просрочки, %",
	AVG(financial_metrics.`Доля закредитованности у других банков, %`) as "Доля закредитованности у других банков, %",
	AVG(financial_metrics.`Краткосрочные/долгосрочные долги, %`) as  "Краткосрочные/долгосрочные долги, %"
FROM 
	financial_metrics
WHERE 
	financial_metrics.report_year IN (2023, 2024, 2025)
GROUP BY
	financial_metrics.`Название компании`
),
final_scoring AS( -- (4 слой)Создаю запрос, который будет выносить вердикт по компании в зависимости от скорингого бала, полученного в предыдущем запросе
SELECT
	scoring_query.`Название компании`,
	ROUND(scoring_query.`Scoring`,3) * 100 as "AVG Скоринг(0-100)",
	CASE 
		WHEN ROUND(scoring_query.`Scoring`,2) * 100 > 70 THEN "Рекомендуется к оказанию услуг" 
		WHEN ROUND(scoring_query.`Scoring`,2) * 100 > 50 THEN "На рассмотрение"
		ELSE "Отказ"
	END as "Решение ",
	COALESCE(ROUND((scoring_query.`ROS, %`),2),0) as "Среднее реальное ROS, %",
	COALESCE(ROUND((scoring_query.`ROE, %`),2),0) as "Среднее реальное ROE, %",
	COALESCE(ROUND((scoring_query.`ROA, %`),2),0) as "Среднее реальное ROA, %",
	COALESCE(ROUND((scoring_query.`EBITDA_Margin, %`),2),0) as "Среднее реальное EBITDA_Margin, %",
	COALESCE(ROUND((scoring_query.`Долг/выручка, %`),2),0) as "Среднее реальное Долг/выручка, %",
	COALESCE(ROUND((scoring_query.`Срок погашения долга, лет`),2),0) as "Среднее реальное Срок погашения долга, лет",
	COALESCE(ROUND((scoring_query.`DSCR (покрытие долга)`),2),0) as "Среднее реальное DSCR (покрытие долга)",
	COALESCE(ROUND((scoring_query.`Финансовый рычаг`),2),0) as "Средний реальный Финансовый рычаг",
	COALESCE(ROUND((scoring_query.`Текущая ликвидность`),2),0) as "Средняя реальная Текущая ликвидность",
	COALESCE(ROUND((scoring_query.`Доля собственных средств в активах`),2),0) as "Средняя реальная Доля собственных средств в активах",
	COALESCE(ROUND((scoring_query.`Доля просрочки, %`),2),0) as "Средняя реальная Доля просрочки, %",
	COALESCE(ROUND((scoring_query.`Доля закредитованности у других банков, %`),2),0) as "Средняя реальная Доля закредитованности у других банков, %",
	COALESCE(ROUND((scoring_query.`Краткосрочные/долгосрочные долги, %`),2),0) as  "Средние реальные Краткосрочные/долгосрочные долги, %"
FROM
	scoring_query
) -- Делаю итоговый SELECT  после оконной функции
SELECT 
	*
FROM
	final_scoring
ORDER BY
	final_scoring.`AVG Скоринг(0-100)` DESC;
/*Реальные показатели пересчитаны к ценам 2025 года. 
 * Поскольку ROS, ROE, ROA и другие относительные показатели являются отношениями, их значения не изменились. 
 * Изменения видны только в абсолютных значениях (выручка, прибыль, долг и т.д.)*/
DROP TABLE metric_point; -- Удаляю из БД вспомогательную таблицу, чтобы при повторном запуске скрипта не выдавало ошибку об уже сущесвтующей таблице
