USE `Project 1`;
SELECT
    name_department,
    name_program,
    plan,
    COUNT(enrollee_id) as Количество,
    ROUND(COUNT(enrollee_id) / plan,2) as Конкурс
FROM
    department
    INNER JOIN program ON department.department_id = program.department_id
    INNER JOIN program_enrollee ON program.program_id = program_enrollee.program_id
GROUP BY
    name_department,
    name_program,
    plan
ORDER BY
    Конкурс DESC


