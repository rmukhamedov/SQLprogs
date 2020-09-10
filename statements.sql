--1
INSERT INTO instructor
  (instructor_id, salutation, first_name, last_name, street_address, zip, created_by, created_date, modified_by, modified_date)
VALUES
  ('815', 'Mr.', 'Hugo', 'Reyes', '2342 Oceanic Way', '07002', USER, SYSDATE, USER, SYSDATE);

--2
INSERT INTO section
  (section_id, course_no, section_no, start_date_time, location, instructor_id, capacity, created_by, created_date, modified_by, modified_date)
VALUES
  ('48', '142', '4', TO_DATE('22-SEP-11 08:15am', 'DD-MON-YY HH:MIam'), 'L211', '815', '15', USER, SYSDATE, USER, SYSDATE);

--3
INSERT INTO enrollment
  (student_id, section_id, enroll_date, created_by, created_date, modified_by, modified_date)
SELECT student_id, '48', SYSDATE, USER, SYSDATE, USER, SYSDATE
FROM student
WHERE student_id = 375 OR student_id = 137 OR student_id = 266 OR student_id = 382;

--4
DELETE FROM grade
WHERE student_id = 147 AND section_id = 120;
DELETE FROM enrollment
WHERE student_id = 147 AND section_id = 120;

--5
DELETE FROM grade
WHERE student_id = 180 AND section_id = 119;
DELETE FROM enrollment
WHERE student_id = 180 AND section_id = 119;

--6
UPDATE instructor
SET phone = '4815162342'
WHERE instructor_id = 815;

--7
UPDATE grade
SET numeric_grade = '100',
    modified_by = USER,
    modified_date = SYSDATE
WHERE grade_type_code = 'HM'
AND grade_code_occurrence = 1
AND section_id = 119;

--8
UPDATE grade
SET numeric_grade = numeric_grade + numeric_grade * .1
WHERE section_id = 119 
AND grade_type_code = 'FI';

--9
SELECT se.section_id, se.location, COUNT(e.student_id) AS enrolled
FROM section se LEFT OUTER JOIN enrollment e
ON se.section_id = e.section_id
WHERE se.course_no = 142
GROUP BY se.section_id, se.location
ORDER BY se.section_id;

--10
SELECT i.first_name, i.last_name, i.street_address, i.phone
FROM instructor i, section se
WHERE i.instructor_id = se.instructor_id
AND se.course_no = 142
ORDER BY i.last_name;

--11
SELECT s.student_id, s.first_name, s.last_name, ROUND(AVG(g.numeric_grade), 2) AS average
FROM student s, grade g
WHERE s.student_id = g.student_id
AND g.section_id = 119
GROUP BY s.student_id, s.first_name, s.last_name
ORDER BY s.student_id;

--12
SELECT COUNT(*) AS number_of_instructors
FROM (SELECT se.instructor_id
      FROM section se, enrollment e
      WHERE se.section_id = e.section_id
      AND se.location = 'L211'
      GROUP BY se.instructor_id
      HAVING COUNT(e.student_id) > 3);

--13
SELECT i.salutation || ' ' || i.first_name || ' ' || i.last_name AS instructor, i.phone
FROM instructor i, section se
WHERE i.instructor_id = se.instructor_id
AND se.course_no = 142
AND i.instructor_id NOT IN
    (SELECT instructor_id
    FROM section
    WHERE course_no != 142);

--14
SELECT s.first_name, s.last_name, se.section_id, se.course_no
FROM student s, (SELECT student_id, section_id
                  FROM enrollment
                  MINUS
                  SELECT student_id, section_id
                  FROM grade) t, section se
WHERE s.student_id = t.student_id
AND se.section_id = t.section_id;

--15
SELECT DISTINCT TO_CHAR(start_date_time, 'HH:MIam') AS starttime, COUNT(DISTINCT course_no)
FROM section
GROUP BY TO_CHAR(start_date_time, 'HH:MIam')
ORDER BY starttime;

--1
SELECT i.first_name, i.last_name, COUNT(s.section_id)
FROM instructor i LEFT OUTER JOIN section s
ON i.instructor_id = s.instructor_id
GROUP BY i.first_name, i.last_name
ORDER BY i.last_name;

--2
SELECT s.course_no
FROM grade g, section s
WHERE s.section_id = g.section_id
GROUP BY s.course_no
HAVING COUNT(DISTINCT grade_type_code) =
    (SELECT COUNT(DISTINCT grade_type_code)
    FROM grade_type_weight)
ORDER BY s.course_no;


--3
SELECT s.zip, COUNT(DISTINCT e.student_id)
FROM student s LEFT OUTER JOIN enrollment e
ON s.student_id = e.student_id
WHERE s.zip IN
    (SELECT zip
    FROM zipcode
    WHERE city = 'Flushing'
    AND state = 'NY')
GROUP BY s.zip
ORDER BY s.zip;

--4
SELECT c.course_no, c.description, COUNT(e.student_id)
FROM course c LEFT OUTER JOIN (SELECT en.student_id, en.section_id, course_no
                              FROM enrollment en, section s
                              WHERE en.section_id = s.section_id) e
ON c.course_no = e.course_no
WHERE c.description LIKE '%Java%'
GROUP BY c.course_no, c.description
ORDER BY c.course_no;

--5
SELECT s.student_id, s.first_name, s.last_name, 
        CASE WHEN COUNT(e.section_id) = 0 THEN 'none'
        else TO_CHAR(COUNT(e.section_id)) END "ENROLLMENTS"
FROM student s LEFT OUTER JOIN enrollment e
ON s.student_id = e.student_id
WHERE s.phone LIKE '617%'
GROUP BY s.student_id, s.first_name, s.last_name
ORDER BY s.last_name, s.first_name;

--6
SELECT course_no
FROM (SELECT s.course_no, COUNT(DISTINCT g.grade_type_code)
    FROM section s, grade g
    WHERE s.section_id = g.section_id
    GROUP BY s.course_no
    MINUS
    SELECT si.course_no, COUNT(DISTINCT gi.grade_type_code)
    FROM grade_type_weight gi, section si
    WHERE gi.section_id = si.section_id
    GROUP BY si.course_no)
ORDER BY course_no;

--1
SELECT s.student_id, s.first_name, s.last_name
FROM student s, enrollment e
WHERE e.student_id = s.student_id
GROUP BY s.student_id, s.first_name, s.last_name
HAVING COUNT(*) = 
	(SELECT MAX(COUNT(*)) 
	FROM enrollment 
	GROUP BY student_id)
ORDER BY s.last_name;

--2
SELECT io.zip, io.instructor_id, io.first_name, io.last_name, io.phone
FROM (SELECT i.zip, c.section_id, i.instructor_id
    FROM instructor i, section c
    WHERE i.instructor_id = c.instructor_id
    INTERSECT
    SELECT s.zip, e.section_id, ce.instructor_id
    FROM student s, enrollment e, section ce
    WHERE e.student_id = s.student_id
    AND e.section_id = ce.section_id) v, instructor io
WHERE io.instructor_id = v.instructor_id;

--3
SELECT i.first_name, i.last_name, z.city, 'Instructor' AS role
FROM instructor i, zipcode z
WHERE i.zip = z.zip
AND i.zip = 10025
UNION
SELECT s.first_name, s.last_name, z2.city, 'Student' AS role
FROM student s, zipcode z2
WHERE s.zip = z2.zip
AND s.zip = 10025
ORDER BY 4, 2, 1;

--4
SELECT t1.location, t1.sections, t2.students   
FROM (SELECT location, COUNT(*) AS sections
     FROM section 
     GROUP BY location
     ORDER BY location) t1,

     (SELECT se.location, COUNT(*) AS students
     FROM section se, enrollment e
     WHERE se.section_id = e.section_id
     GROUP BY se.location
     ORDER BY location) t2
WHERE t1.location = t2.location;

--5
SELECT grade_type_code, numeric_grade
FROM grade
WHERE student_id = 127
AND section_id = 95
UNION ALL
SELECT 'Average for student 127' AS grade_type_code, ROUND(AVG(numeric_grade), 2) AS numeric_grade
FROM grade
WHERE student_id = 127
AND section_id = 95
GROUP BY 'Average for student 127';