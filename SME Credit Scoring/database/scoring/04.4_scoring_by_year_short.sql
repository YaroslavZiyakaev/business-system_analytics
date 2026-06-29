USE `VTB. Project 2`;  -- Подключитесь к своей БД: USE `name_of_your_database`;

CREATE TABLE metric_point -- Создаю вспомогательную таблицу, данные в которой можно обновлять, в зависимости от варьирования приоритетов эконом показателей у редактора скрипта
(
	metric_name VARCHAR(50),
	metric_value int
);

SET @year := 2025;-- ЗДЕСЬ МОЖНО выбрать год

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

WITH  -- Создаю оконную функцию 
financial_metrics AS  -- (1 слой)Создаю запрос, в котором посчитаю финансовые показатели для комапний
(
SELECT 
	c.name as "Название компании",
	-- Показатели рентабельности -- 
	ROUND((fi.net_profit / NULLIF(fi.revenue, 0)) * 100, 2) AS "ROS, %", -- Рентабельность продаж(чп/выручка)
	ROUND((fi.net_profit / NULLIF(fi.equity ,0)) * 100, 2) AS "ROE, %", -- Рентабельность капитала(чп/собственный капитал)
	ROUND((fi.net_profit / NULLIF(fi.equity + fi.short_term_debt + fi.long_term_debt,0)) * 100, 2) AS "ROA, %", -- Рентабельность активов(чп/вего активов)
	ROUND((fi.net_profit * 1.25 / NULLIF(fi.revenue ,0)) * 100, 2) AS "EBITDA_Margin, %", -- Операционная прибыль до вычета процентов и налогов(ВАЖНО! Умножаем на 1,25, потому что примерно 1/5  часть от прибыль уходит на налоговые и иные издержки)
	-- Показатели долговой нагрузки --
	ROUND(((fi.long_term_debt  + fi.short_term_debt) / NULLIF(fi.revenue, 0)) * 100,2) AS "Долг/выручка, %", --  показывает сколько % выручки уходит на погашение долгов
	ROUND((fi.short_term_debt + fi.long_term_debt) / NULLIF(fi.net_profit * 1.25, 0), 2) AS "Срок погашения долга, лет", 
	ROUND(fi.net_profit / NULLIF((fi.short_term_debt + fi.long_term_debt) * 0.2, 0), 2) AS "DSCR (покрытие долга)", -- Коэффициент покрытия долга, показывает, хватит ли денег на ежемесячные выплаты по кредиту		
	ROUND((fi.short_term_debt + fi.long_term_debt) / NULLIF(fi.equity, 0), 2) AS "Финансовый рычаг", -- Финансовый рычаг, показывает зависимость от зеамных денег. Чем выше, тем рискованнее
	-- Показатели ликвидности --
	ROUND((fi.net_profit + fi.equity) / NULLIF(fi.short_term_debt, 0),2) AS "Текущая ликвидность", -- (прибыль + капитал) / краткосрочные долги
	-- Покащатели финансовой устойчивости--
	ROUND(fi.equity / NULLIF(fi.equity + fi.short_term_debt + fi.long_term_debt, 0), 2) AS "Доля собственных средств в активах", -- Чем выше, тем устойчивее бизнес
	-- Показатели риска --
	ROUND(fi.overdue_payments / NULLIF(fi.short_term_debt + fi.long_term_debt, 0) * 100, 2) AS "Доля просрочки, %",
	ROUND(er.debt_to_other_banks / NULLIF(fi.short_term_debt + fi.long_term_debt, 0) * 100, 2) AS "Доля закредитованности у других банков, %",
	ROUND(fi.short_term_debt / NULLIF(fi.short_term_debt + fi.long_term_debt, 0) * 100, 2) AS "Краткосрочные/долгосрочные долги, %" 
FROM
	companies c
	INNER JOIN business_types bt ON c.type_id = bt.type_id 
	INNER JOIN industry i ON c.industry_id  = i.industry_id 
	INNER JOIN region r ON c.region_id  = r.region_id 
	INNER JOIN external_risks er  ON c.inn = er.inn 
	INNER JOIN financial_indicators fi ON c.inn = fi.inn
WHERE
	fi.report_year = @year
ORDER BY
	`ROS, %` DESC
),
scoring_query AS( -- (2 слой)Создаю второй запрос, который будет рассчитывать скоринговую сумму в зависимости от отклонений средних метрик от необходимых значений
SELECT -- Важно! Я ввел систему градации: есть три порога значений, которые отсеивают "неудачные" метрики. Числовые характеристики можно менять по желанию
	financial_metrics.`Название компании`,
	(
	CASE 	
		WHEN financial_metrics.`ROS, %` > 5 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "ROS, %")
		WHEN financial_metrics.`ROS, %` > 4.5 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "ROS, %") * 0.8
		WHEN financial_metrics.`ROS, %` > 4 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "ROS, %") * 0.6
		ELSE 0 
	END + 
	CASE 
		WHEN financial_metrics.`ROE, %` > 15 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "ROE, %") 
		WHEN financial_metrics.`ROE, %` > 14 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "ROE, %") * 0.8
		WHEN financial_metrics.`ROE, %` > 13 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "ROE, %") * 0.6
		ELSE 0 
	END +
	CASE 
		WHEN financial_metrics.`ROA, %` > 5 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "ROA, %")
		WHEN financial_metrics.`ROA, %` > 4.5 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "ROA, %") * 0.8
		WHEN financial_metrics.`ROA, %` > 4 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "ROA, %") * 0.6
		ELSE 0 
	END +
	CASE 
		WHEN financial_metrics.`EBITDA_Margin, %` > 10 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "EBITDA_Margin, %")
		WHEN financial_metrics.`EBITDA_Margin, %` > 9 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "EBITDA_Margin, %") * 0.8
		WHEN financial_metrics.`EBITDA_Margin, %` > 8 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "EBITDA_Margin, %")  * 0.6
		ELSE 0 
	END +
	CASE 
		WHEN financial_metrics.`Долг/выручка, %` < 40 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Долг/выручка, %") 
		WHEN financial_metrics.`Долг/выручка, %` < 42.5 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Долг/выручка, %") * 0.8
		WHEN financial_metrics.`Долг/выручка, %` < 45 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Долг/выручка, %") * 0.6
		ELSE 0 
	END +
	CASE 
		WHEN financial_metrics.`Срок погашения долга, лет` < 3 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Срок погашения долга, лет")
		WHEN financial_metrics.`Срок погашения долга, лет` < 3.2 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Срок погашения долга, лет")  * 0.8
		WHEN financial_metrics.`Срок погашения долга, лет` < 3.5 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Срок погашения долга, лет") * 0.6
		ELSE 0 
	END + 
	CASE 
		WHEN financial_metrics.`DSCR (покрытие долга)` > 1.2 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "DSCR (покрытие долга)") 
		WHEN financial_metrics.`DSCR (покрытие долга)` > 1.1 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "DSCR (покрытие долга)") * 0.8
		WHEN financial_metrics.`DSCR (покрытие долга)` > 1.0 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "DSCR (покрытие долга)") * 0.6
		ELSE 0 
	END + 
	CASE 
		WHEN financial_metrics.`Финансовый рычаг` < 1.5 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Финансовый рычаг")
		WHEN financial_metrics.`Финансовый рычаг` < 1.6 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Финансовый рычаг") * 0.8
		WHEN financial_metrics.`Финансовый рычаг` < 1.7 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Финансовый рычаг") * 0.6
		ELSE 0 
	END +
	CASE 
		WHEN financial_metrics.`Текущая ликвидность` > 1.5 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Текущая ликвидность")
		WHEN financial_metrics.`Текущая ликвидность` > 1.4 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Текущая ликвидность") * 0.8
		WHEN financial_metrics.`Текущая ликвидность` > 1.3 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Текущая ликвидность") * 0.6
		ELSE 0 
	END + 
	CASE 
		WHEN financial_metrics.`Доля собственных средств в активах` > 0.3 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Доля собственных средств в активах") 
		WHEN financial_metrics.`Доля собственных средств в активах` > 0.25 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Доля собственных средств в активах") * 0.8
		WHEN financial_metrics.`Доля собственных средств в активах` > 0.2 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Доля собственных средств в активах") * 0.6
		ELSE 0 
	END + 
	CASE 
		WHEN financial_metrics.`Доля просрочки, %` = 0 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Доля просрочки, %") 
		ELSE 0 
	END +
	CASE 
		WHEN financial_metrics.`Доля закредитованности у других банков, %` < 30 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Доля закредитованности у других банков, %") 
		WHEN financial_metrics.`Доля закредитованности у других банков, %` < 35 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Доля закредитованности у других банков, %") * 0.8
		WHEN financial_metrics.`Доля закредитованности у других банков, %` < 40 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Доля закредитованности у других банков, %") * 0.6
		ELSE 0 
	END  +
	CASE 
		WHEN financial_metrics.`Краткосрочные/долгосрочные долги, %` < 50 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Краткосрочные/долгосрочные долги, %") 
		WHEN financial_metrics.`Краткосрочные/долгосрочные долги, %` < 52.5 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Краткосрочные/долгосрочные долги, %") * 0.8
		WHEN financial_metrics.`Краткосрочные/долгосрочные долги, %` < 55 THEN (SELECT metric_point.metric_value FROM metric_point WHERE metric_name = "Краткосрочные/долгосрочные долги, %") * 0.6
		ELSE 0 
	END
	) / (SELECT SUM(metric_value) FROM metric_point) as Scoring -- Делим на сумму весов
FROM 
	financial_metrics
),
final_scoring AS( -- (3 слой)Создаю запрос, который будет выносить вердикт по компании в зависимости от скорингого бала, полученного в предыдущем запросе
SELECT
	scoring_query.`Название компании`,
	ROUND(scoring_query.`Scoring`,3) * 100 as "Скоринг(0-100)",
	CASE 
		WHEN ROUND(scoring_query.`Scoring`,2) * 100 > 70 THEN "Рекомендуется к оказанию услуг" 
		WHEN ROUND(scoring_query.`Scoring`,2) * 100 > 50 THEN "Не рекомендуется к оказанию услуг"
		ELSE "Отказ"
	END as "Решение "
FROM
	scoring_query
) -- Делаю итоговый SELECT  после оконной функции
SELECT 
	*
FROM
	final_scoring
ORDER BY
	final_scoring.`Скоринг(0-100)` DESC;

DROP TABLE metric_point
