USE `Project 1`;

SELECT 
    name_enrollee
FROM
    enrollee
    INNER JOIN program_enrollee ON enrollee.enrollee_id = program_enrollee.enrollee_id
    INNER JOIN program ON program_enrollee.program_id = program.program_id
WHERE
    name_program = 'Мехатроника и робототехника'
ORDER BY
    name_enrollee 
