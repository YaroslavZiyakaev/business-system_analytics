USE `VTB. Project 2`;  -- Подключитесь к своей БД: USE `name_of_your_database`;


/*Создаю таблицу с классификацией бизнеса по масштабу, max_revenue - максимальный доход, для данного вида бизнеса*/

CREATE TABLE business_types
(
type_id INT PRIMARY KEY AUTO_INCREMENT,
type_name VARCHAR(20),
max_revenue DECIMAL(12,2) 
);

/*Создаю таблицу с классификацией бизнеса по индустриям оказания услуг, каждой индустрии соответствует определенный риск просрочки в задолженности по кредитам*/

CREATE TABLE industry
(
industry_id INT PRIMARY KEY AUTO_INCREMENT,
industry_risk DECIMAL(8,2), /*Информация взята с открытых источников, но все еще довольно примерная, т к проект является учебным*/
industry_description VARCHAR(255)
);

CREATE TABLE region
(
region_id INT PRIMARY KEY AUTO_INCREMENT,
region_name VARCHAR(100)
);

/*Создаю таблицу c компаниями*/

CREATE TABLE companies
(
inn VARCHAR(20) PRIMARY KEY,
name VARCHAR(100),
type_id INT,
industry_id INT,
region_id INT,
FOREIGN KEY (type_id) REFERENCES business_types(type_id),
FOREIGN KEY (industry_id) REFERENCES industry(industry_id),
FOREIGN KEY (region_id) REFERENCES region(region_id)
);

/*Создаем таблицу с финансовыми показателями компании, все эти показатели можно узнать из открытых источников*/

CREATE TABLE financial_indicators
(
financial_indicators_id INT PRIMARY KEY AUTO_INCREMENT,
inn VARCHAR(20),
report_year YEAR, /*Интересующий нас год*/
revenue DECIMAL(15,2),
net_profit DECIMAL(15,2),
equity DECIMAL(15,2), /*Собственный капитал*/
short_term_debt DECIMAL(15,2),/*Краткосрочные обязательства перед всеми контрагентами(до 1 года)*/
long_term_debt DECIMAL (15,2),/*Долгосрочные обязательтсва перед всеми контрагентами(больше 1 года)*/
overdue_payments DECIMAL(15,2), /*Просрочка*/
FOREIGN KEY (inn) REFERENCES companies(inn)
);

CREATE TABLE external_risks
(
external_risks_id  INT PRIMARY KEY AUTO_INCREMENT,
inn VARCHAR(20),
debt_to_other_banks DECIMAL(15,2),/*Часть из общих долговых обязательств, которые МСБ несет перед банками конкурентами*/
arbitration_claims INT, /*Количество арбитражных рисков, ввожу этот показатель, т к отражает кредитную политику МСБ*/
tax_arrears DECIMAL(15,2), /*Это уже ПРОСРОЧЕННАЯ задолженность перед ФНС*/
FOREIGN KEY (inn) REFERENCES companies(inn)
);
