USE `VTB. Project 2`;  -- Подключитесь к своей БД: USE `name_of_your_database`;

SELECT 
	c.name as "Название компании",
	report_year,
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
ORDER BY
	`Название компании` DESC,
	report_year;