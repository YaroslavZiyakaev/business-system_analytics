SELECT query_in1.name_program, query_in1.name_enrollee   
FROM 
	(
    SELECT DISTINCT name_program, name_subject, name_enrollee, result
    FROM
        enrollee
        INNER JOIN enrollee_subject ON enrollee.enrollee_id = enrollee_subject.enrollee_id
        INNER JOIN subject ON subject.subject_id = enrollee_subject.subject_id
        INNER JOIN program_enrollee ON enrollee.enrollee_id = program_enrollee.enrollee_id
        INNER JOIN program ON program.program_id = program_enrollee.program_id
        INNER JOIN program_subject ON program.program_id = program_subject.program_id       
    WHERE
        result < min_result       
    ORDER BY name_program, name_enrollee
    ) query_in1   
    INNER JOIN
    (
    SELECT name_program, name_subject   
    FROM
        program
        INNER JOIN program_subject USING(program_id)
        INNER JOIN subject USING(subject_id)         
    ) query_in2  
    ON query_in1.name_program = query_in2.name_program AND query_in1.name_subject = query_in2.name_subject

