
SELECT
    query_in2.name_program,
    query_in2.name_enrollee,
    SUM(result) as itog
FROM
    (
    SELECT
        name_program,
        name_subject
    FROM
        program
        INNER JOIN program_subject ON program.program_id = program_subject.program_id
        INNER JOIN subject ON subject.subject_id = program_subject.subject_id
    ) query_in1
    INNER JOIN
    (
    SELECT
        DISTINCT
        name_enrollee,
        name_program,
        name_subject,
        result
    FROM
        enrollee
        INNER JOIN enrollee_subject ON enrollee.enrollee_id = enrollee_subject.enrollee_id
        INNER JOIN subject ON subject.subject_id = enrollee_subject.subject_id
        INNER JOIN program_enrollee ON enrollee.enrollee_id = program_enrollee.enrollee_id
        INNER JOIN program ON program.program_id = program_enrollee.program_id
        INNER JOIN program_subject ON program.program_id = program_subject.program_id
    WHERE result >= min_result
    ) query_in2
    ON query_in1.name_program = query_in2.name_program AND query_in1.name_subject = query_in2.name_subject
GROUP BY
    query_in2.name_enrollee,
    query_in2.name_program    
ORDER BY
    query_in2.name_program,
    SUM(result) DESC;





