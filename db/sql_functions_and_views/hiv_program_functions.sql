

/* MySQL function for mainly HIV program */


-- Patient date enrolled
DROP FUNCTION IF EXISTS patient_date_enrolled;

DELIMITER $$
CREATE FUNCTION patient_date_enrolled(my_patient_id INT, my_site_id INT) RETURNS DATE
DETERMINISTIC
BEGIN
DECLARE my_start_date DATE;
DECLARE min_start_date DATETIME;
DECLARE arv_concept_id INT(11);

SET arv_concept_id = (SELECT concept_id FROM concept_name WHERE name ='ANTIRETROVIRAL DRUGS' LIMIT 1);

SET my_start_date = (SELECT DATE(o.start_date) FROM drug_order d 
INNER JOIN orders o ON d.order_id = o.order_id 
AND o.voided = 0 AND o.site_id = my_site_id AND d.site_id = my_site_id
WHERE o.patient_id = my_patient_id AND drug_inventory_id IN(SELECT drug_id FROM drug 
WHERE concept_id IN(SELECT concept_id FROM concept_set WHERE concept_set = arv_concept_id)) 
AND d.quantity > 0 AND o.start_date = (SELECT min(start_date) FROM drug_order d 
INNER JOIN orders o ON d.order_id = o.order_id AND o.voided = 0 
AND d.site_id = my_site_id AND o.site_id = my_site_id
WHERE d.quantity > 0 AND o.patient_id = my_patient_id 
AND drug_inventory_id IN(SELECT drug_id FROM drug 
WHERE concept_id IN(SELECT concept_id FROM concept_set 
WHERE concept_set = arv_concept_id))) LIMIT 1);


RETURN my_start_date;
END$$
DELIMITER ;



-- Patient start date

DROP FUNCTION IF EXISTS patient_start_date;

DELIMITER $$
CREATE FUNCTION patient_start_date(my_patient_id INT, my_site_id INT) RETURNS DATE
DETERMINISTIC
BEGIN
DECLARE start_date VARCHAR(10);
DECLARE dispension_concept_id INT;
DECLARE arv_concept INT;

set dispension_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'AMOUNT DISPENSED');
set arv_concept = (SELECT concept_id FROM concept_name WHERE name = "ANTIRETROVIRAL DRUGS");

set start_date = (SELECT MIN(DATE(obs_datetime)) FROM obs WHERE voided = 0 
AND person_id = my_patient_id AND concept_id = dispension_concept_id 
AND site_id = my_site_id AND value_drug IN (SELECT drug_id FROM drug d 
WHERE d.concept_id IN (SELECT cs.concept_id FROM concept_set cs WHERE cs.concept_set = arv_concept)));

RETURN start_date;
END$$
DELIMITER ;



-- Date antiretrovirals started

DROP FUNCTION IF EXISTS date_antiretrovirals_started;

DELIMITER $$
CREATE FUNCTION date_antiretrovirals_started(set_patient_id INT, min_state_date DATE, my_site_id INT) RETURNS DATE
DETERMINISTIC
BEGIN
DECLARE date_started DATE;
DECLARE estimated_art_date DATE;
DECLARE estimated_art_date_months  VARCHAR(45);


SET date_started = (SELECT LEFT(value_datetime,10) FROM obs WHERE concept_id = 2516 
AND encounter_id > 0 AND person_id = set_patient_id AND voided = 0 AND site_id = my_site_id LIMIT 1);

IF date_started IS NULL then
  SET estimated_art_date_months = (SELECT value_text FROM obs WHERE encounter_id > 0 
  AND concept_id = 2516 AND person_id = set_patient_id AND voided = 0 AND site_id = my_site_id LIMIT 1);
  SET min_state_date = (SELECT obs_datetime FROM obs WHERE encounter_id > 0 AND concept_id = 2516 
  AND person_id = set_patient_id AND voided = 0 AND site_id = my_site_id LIMIT 1);

  IF estimated_art_date_months = "6 months" THEN set date_started = (SELECT DATE_SUB(min_state_date, INTERVAL 6 MONTH));
  ELSEIF estimated_art_date_months = "12 months" THEN set date_started = (SELECT DATE_SUB(min_state_date, INTERVAL 12 MONTH));
  ELSEIF estimated_art_date_months = "18 months" THEN set date_started = (SELECT DATE_SUB(min_state_date, INTERVAL 18 MONTH));
  ELSEIF estimated_art_date_months = "24 months" THEN set date_started = (SELECT DATE_SUB(min_state_date, INTERVAL 24 MONTH));
  ELSEIF estimated_art_date_months = "48 months" THEN set date_started = (SELECT DATE_SUB(min_state_date, INTERVAL 48 MONTH));
  ELSEIF estimated_art_date_months = "Over 2 years" THEN set date_started = (SELECT DATE_SUB(min_state_date, INTERVAL 60 MONTH));
  ELSE
    SET date_started = patient_start_date(set_patient_id, my_site_id);
  END IF;
END IF;

RETURN date_started;
END$$
DELIMITER ;


-- Person age
DROP FUNCTION IF EXISTS age;

DELIMITER $$
CREATE FUNCTION age(birthdate varchar(10), visit_date varchar(10), date_created varchar(10), est int) RETURNS INT(11)
DETERMINISTIC
BEGIN

DECLARE cul_age INT;

DECLARE birth_date DATE;
DECLARE visit_date_parsed DATE;
DECLARE created_date_parsed DATE;

SET birth_date = STR_TO_DATE(birthdate, '%Y-%m-%d');
SET visit_date_parsed = STR_TO_DATE(visit_date, '%Y-%m-%d');
SET created_date_parsed = STR_TO_DATE(date_created, '%Y-%m-%d');

SET cul_age = TIMESTAMPDIFF(YEAR, birth_date, visit_date_parsed);

IF (DATE_FORMAT(visit_date_parsed, '%m-%d') < DATE_FORMAT(birth_date, '%m-%d')) THEN
    SET cul_age = cul_age - 1;
END IF;

RETURN cul_age;

END$$
DELIMITER ;



-- Age group
DROP FUNCTION IF EXISTS age_group;

DELIMITER $$
CREATE FUNCTION age_group(birthdate varchar(10), visit_date varchar(10), date_created varchar(10), est int) RETURNS varchar(25)
DETERMINISTIC
BEGIN
    DECLARE avg VARCHAR(25);
    DECLARE years INT;
    DECLARE months INT;
    
    SET avg = "none";
    SET years = (SELECT age(birthdate, visit_date, date_created, est));
    SET months = (SELECT TIMESTAMPDIFF(MONTH, birthdate, visit_date));
    
    IF years >= 1 THEN
        IF years < 5 THEN SET avg = "1 to < 5";
        ELSEIF years <= 14 THEN SET avg = "5 to 14";
        ELSEIF years < 20 THEN SET avg = "> 14 to < 20";
        ELSEIF years < 30 THEN SET avg = "20 to < 30";
        ELSEIF years < 40 THEN SET avg = "30 to < 40";
        ELSEIF years < 50 THEN SET avg = "40 to < 50";
        ELSE SET avg = "50 and above";
        END IF;
    ELSE
        IF months < 6 THEN SET avg = "< 6 months";
        ELSEIF months < 12 THEN SET avg = "6 months to < 1 yr";
        END IF;
    END IF;
    
    RETURN avg;
END$$
DELIMITER ;


-- ANC age group
DROP FUNCTION IF EXISTS anc_age_group;

DELIMITER $$
CREATE FUNCTION anc_age_group(birthdate varchar(10), visit_date varchar(10), date_created varchar(10), est int) RETURNS varchar(25)
DETERMINISTIC
BEGIN
    DECLARE age_in_years INT;
    DECLARE age_group VARCHAR(25);
    
    SET age_in_years = TIMESTAMPDIFF(YEAR, birthdate, visit_date);

    IF age_in_years < 10 THEN SET age_group = "<10 years";
    ELSEIF age_in_years <= 14 THEN SET age_group = "10-14 years";
    ELSEIF age_in_years <= 19 THEN SET age_group = "15-19 years";
    ELSEIF age_in_years <= 24 THEN SET age_group = "20-24 years";
    ELSEIF age_in_years <= 29 THEN SET age_group = "25-29 years";
    ELSEIF age_in_years <= 34 THEN SET age_group = "30-34 years";
    ELSEIF age_in_years <= 39 THEN SET age_group = "35-39 years";
    ELSEIF age_in_years <= 44 THEN SET age_group = "40-44 years";
    ELSEIF age_in_years <= 49 THEN SET age_group = "45-49 years";
    ELSEIF age_in_years <= 54 THEN SET age_group = "50-54 years";
    ELSEIF age_in_years <= 59 THEN SET age_group = "55-59 years";
    ELSEIF age_in_years <= 64 THEN SET age_group = "60-64 years";
    ELSEIF age_in_years <= 69 THEN SET age_group = "65-69 years";
    ELSEIF age_in_years <= 74 THEN SET age_group = "70-74 years";
    ELSEIF age_in_years <= 79 THEN SET age_group = "75-79 years";
    ELSEIF age_in_years <= 84 THEN SET age_group = "80-84 years";
    ELSEIF age_in_years <= 89 THEN SET age_group = "85-89 years";
    ELSE SET age_group = "90 plus years";
    END IF;

    RETURN age_group;
END$$
DELIMITER ;


-- Cohort disaggregated age group

DROP FUNCTION IF EXISTS cohort_disaggregated_age_group;

DELIMITER $$
CREATE FUNCTION cohort_disaggregated_age_group(birthdate varchar(10), visit_date varchar(10), date_created varchar(10), est int) RETURNS varchar(25)
DETERMINISTIC
BEGIN
    DECLARE age_in_months INT;
    DECLARE age_in_years INT;
    DECLARE age_group VARCHAR(25);
    
    SET age_in_months = TIMESTAMPDIFF(MONTH, birthdate, end_date);
    SET age_in_years = TIMESTAMPDIFF(YEAR, birthdate, end_date);
    
    IF age_in_months >= 0 AND age_in_months <= 5 THEN SET age_group = "0-5 months";
    ELSEIF age_in_months <= 11 THEN SET age_group = "6-11 months";
    ELSEIF age_in_months <= 23 THEN SET age_group = "12-23 months";
    ELSEIF age_in_years >= 2 AND age_in_years <= 4 THEN SET age_group = "2-4 years";
    ELSEIF age_in_years <= 9 THEN SET age_group = "5-9 years";
    ELSEIF age_in_years <= 14 THEN SET age_group = "10-14 years";
    ELSEIF age_in_years <= 17 THEN SET age_group = "15-17 years";
    ELSEIF age_in_years <= 19 THEN SET age_group = "18-19 years";
    ELSEIF age_in_years <= 24 THEN SET age_group = "20-24 years";
    ELSEIF age_in_years <= 29 THEN SET age_group = "25-29 years";
    ELSEIF age_in_years <= 34 THEN SET age_group = "30-34 years";
    ELSEIF age_in_years <= 39 THEN SET age_group = "35-39 years";
    ELSEIF age_in_years <= 44 THEN SET age_group = "40-44 years";
    ELSEIF age_in_years <= 49 THEN SET age_group = "45-49 years";
    ELSE SET age_group = "50 plus years";
    END IF;
    
    RETURN age_group;
END$$
DELIMITER ;

-- Current Defaulter
DROP FUNCTION IF EXISTS current_defaulter;
DELIMITER $$
CREATE FUNCTION current_defaulter(my_patient_id INT, my_end_date DATETIME, my_site_id INT) RETURNS int(1)
DETERMINISTIC 
BEGIN
  DECLARE done INT DEFAULT FALSE;
  DECLARE my_start_date, my_expiry_date, my_obs_datetime DATETIME;
  DECLARE my_daily_dose, my_quantity, my_pill_count, my_total_text, my_total_numeric DECIMAL(10, 2);
  DECLARE my_drug_id, flag INT;
 
  DECLARE cur1 CURSOR FOR SELECT d.drug_inventory_id, o.start_date, d.equivalent_daily_dose daily_dose, SUM(d.quantity), o.start_date FROM drug_order d
    INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id AND d.site_id = my_site_id
    INNER JOIN orders o ON d.order_id = o.order_id
      AND d.quantity > 0
      AND o.voided = 0
      AND o.start_date <= my_end_date
      AND o.patient_id = my_patient_id
      AND o.site_id = my_site_id
      GROUP BY drug_inventory_id, DATE(start_date), daily_dose;
 
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
 
  SELECT MAX(o.start_date) INTO @obs_datetime FROM drug_order d
    INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id AND d.site_id = my_site_id
    INNER JOIN orders o ON d.order_id = o.order_id
      AND d.quantity > 0
      AND o.voided = 0
      AND o.start_date <= my_end_date
      AND o.patient_id = my_patient_id
      AND o.site_id = my_site_id
    GROUP BY o.patient_id;
 
  OPEN cur1;
 
  SET flag = 0;
 
  read_loop: LOOP
    FETCH cur1 INTO my_drug_id, my_start_date, my_daily_dose, my_quantity, my_obs_datetime;
 
    IF done THEN
      CLOSE cur1;
      LEAVE read_loop;
    END IF;
 
    IF DATE(my_obs_datetime) = DATE(@obs_datetime) THEN
 
      IF my_daily_dose = 0 OR LENGTH(my_daily_dose) < 1 OR my_daily_dose IS NULL THEN
        SET my_daily_dose = 1;
      END IF;
 
            SET my_pill_count = drug_pill_count(my_patient_id, my_drug_id, my_obs_datetime, my_site_id);
 
            SET @expiry_date = ADDDATE(DATE_SUB(my_start_date, INTERVAL 1 DAY), ((my_quantity + my_pill_count)/my_daily_dose));
 
      IF my_expiry_date IS NULL THEN
        SET my_expiry_date = @expiry_date;
      END IF;
 
      IF @expiry_date < my_expiry_date THEN
        SET my_expiry_date = @expiry_date;
            END IF;
        END IF;
    END LOOP;
 
    IF TIMESTAMPDIFF(day, my_expiry_date, my_end_date) >= 60 THEN
        SET flag = 1;
    END IF;
 
  RETURN flag;
END$$
DELIMITER ;


-- Current defaulter date
DROP FUNCTION IF EXISTS current_defaulter_date;

DELIMITER $$
CREATE FUNCTION current_defaulter_date(my_patient_id INT, my_end_date date, my_site_id INT) RETURNS varchar(15)
DETERMINISTIC 
BEGIN
  DECLARE my_default_date DATE;
  DECLARE done INT DEFAULT FALSE;
  DECLARE my_start_date, my_expiry_date, my_obs_datetime DATETIME;
  DECLARE my_daily_dose, my_quantity, my_pill_count, my_total_text, my_total_numeric DECIMAL(10, 2);
  DECLARE my_drug_id, flag INT;
 
  DECLARE cur1 CURSOR FOR SELECT d.drug_inventory_id, o.start_date, d.equivalent_daily_dose daily_dose, SUM(d.quantity), o.start_date FROM drug_order d
    INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id AND d.site_id = my_site_id
    INNER JOIN orders o ON d.order_id = o.order_id
      AND d.quantity > 0
      AND o.voided = 0
      AND o.start_date <= my_end_date
      AND o.patient_id = my_patient_id
      AND o.site_id = my_site_id
      GROUP BY drug_inventory_id, DATE(start_date), daily_dose;
 
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
 
  SELECT MAX(o.start_date) INTO @obs_datetime FROM drug_order d
    INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id AND d.site_id = my_site_id
    INNER JOIN orders o ON d.order_id = o.order_id
      AND d.quantity > 0
      AND o.voided = 0
      AND o.start_date <= my_end_date
      AND o.patient_id = my_patient_id
      AND o.site_id = my_site_id
    GROUP BY o.patient_id;
 
  OPEN cur1;
 
  SET flag = 0;
 
  read_loop: LOOP
    FETCH cur1 INTO my_drug_id, my_start_date, my_daily_dose, my_quantity, my_obs_datetime;
 
    IF done THEN
      CLOSE cur1;
      LEAVE read_loop;
    END IF;
 
    IF DATE(my_obs_datetime) = DATE(@obs_datetime) THEN
 
      IF my_daily_dose = 0 OR LENGTH(my_daily_dose) < 1 OR my_daily_dose IS NULL THEN
        SET my_daily_dose = 1;
      END IF;
 
            SET my_pill_count = drug_pill_count(my_patient_id, my_drug_id, my_obs_datetime, my_site_id);
 
            SET @expiry_date = ADDDATE(DATE_SUB(my_start_date, INTERVAL 1 DAY), ((my_quantity + my_pill_count)/my_daily_dose));
 
      IF my_expiry_date IS NULL THEN
        SET my_expiry_date = @expiry_date;
      END IF;
 
      IF @expiry_date < my_expiry_date THEN
        SET my_expiry_date = @expiry_date;
            END IF;
        END IF;
    END LOOP;
 
    IF TIMESTAMPDIFF(day, DATE(my_expiry_date), DATE(my_end_date)) >= 60 THEN
        SET my_default_date = ADDDATE(my_expiry_date, 61);
    END IF;

  RETURN my_default_date;
END$$
DELIMITER ;

-- Current PEPFAR Defaulter
DROP FUNCTION IF EXISTS current_pepfar_defaulter;
DELIMITER $$
CREATE FUNCTION current_pepfar_defaulter(my_patient_id INT, my_end_date DATETIME, my_site_id INT) RETURNS int(1)
DETERMINISTIC 
BEGIN
  DECLARE done INT DEFAULT FALSE;
  DECLARE my_start_date, my_expiry_date, my_obs_datetime DATETIME;
  DECLARE my_daily_dose, my_quantity, my_pill_count, my_total_text, my_total_numeric DECIMAL(10, 2);
  DECLARE my_drug_id, flag INT;
 
  DECLARE cur1 CURSOR FOR SELECT d.drug_inventory_id, o.start_date, d.equivalent_daily_dose daily_dose, SUM(d.quantity), o.start_date FROM drug_order d
    INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id AND d.site_id = my_site_id
    INNER JOIN orders o ON d.order_id = o.order_id
      AND d.quantity > 0
      AND o.voided = 0
      AND o.start_date <= my_end_date
      AND o.patient_id = my_patient_id
      AND o.site_id = my_site_id
      GROUP BY drug_inventory_id, DATE(start_date), daily_dose;
 
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
 
  SELECT MAX(o.start_date) INTO @obs_datetime FROM drug_order d
    INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id AND d.site_id = my_site_id
    INNER JOIN orders o ON d.order_id = o.order_id
      AND d.quantity > 0
      AND o.voided = 0
      AND o.start_date <= my_end_date
      AND o.patient_id = my_patient_id
      AND o.site_id = my_site_id
    GROUP BY o.patient_id;
 
  OPEN cur1;
 
  SET flag = 0;
 
  read_loop: LOOP
    FETCH cur1 INTO my_drug_id, my_start_date, my_daily_dose, my_quantity, my_obs_datetime;
 
    IF done THEN
      CLOSE cur1;
      LEAVE read_loop;
    END IF;
 
    IF DATE(my_obs_datetime) = DATE(@obs_datetime) THEN
 
      IF my_daily_dose = 0 OR LENGTH(my_daily_dose) < 1 OR my_daily_dose IS NULL THEN
        SET my_daily_dose = 1;
      END IF;
 
            SET my_pill_count = drug_pill_count(my_patient_id, my_drug_id, my_obs_datetime, my_site_id);
 
            SET @expiry_date = ADDDATE(DATE_SUB(my_start_date, INTERVAL 1 DAY), ((my_quantity + my_pill_count)/my_daily_dose));
 
      IF my_expiry_date IS NULL THEN
        SET my_expiry_date = @expiry_date;
      END IF;
 
      IF @expiry_date < my_expiry_date THEN
        SET my_expiry_date = @expiry_date;
            END IF;
        END IF;
    END LOOP;
 
    IF TIMESTAMPDIFF(day, my_expiry_date, my_end_date) >= 30 THEN
        SET flag = 1;
    END IF;
 
  RETURN flag;
END$$
DELIMITER ;


-- Current PEPFAR defaulter date
DROP FUNCTION IF EXISTS current_pepfar_defaulter_date;
DELIMITER $$
CREATE FUNCTION current_pepfar_defaulter_date(my_patient_id INT, my_end_date date, my_site_id INT) RETURNS varchar(15)
DETERMINISTIC 
BEGIN
  DECLARE my_default_date DATE;
  DECLARE done INT DEFAULT FALSE;
  DECLARE my_start_date, my_expiry_date, my_obs_datetime DATETIME;
  DECLARE my_daily_dose, my_quantity, my_pill_count, my_total_text, my_total_numeric DECIMAL(10, 2);
  DECLARE my_drug_id, flag INT;
 
  DECLARE cur1 CURSOR FOR SELECT d.drug_inventory_id, o.start_date, d.equivalent_daily_dose daily_dose, SUM(d.quantity), o.start_date FROM drug_order d
    INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id AND d.site_id = my_site_id
    INNER JOIN orders o ON d.order_id = o.order_id
      AND d.quantity > 0
      AND o.voided = 0
      AND o.start_date <= my_end_date
      AND o.patient_id = my_patient_id
      AND o.site_id = my_site_id
      GROUP BY drug_inventory_id, DATE(start_date), daily_dose;
 
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
 
  SELECT MAX(o.start_date) INTO @obs_datetime FROM drug_order d
    INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id AND d.site_id = my_site_id
    INNER JOIN orders o ON d.order_id = o.order_id
      AND d.quantity > 0
      AND o.voided = 0
      AND o.start_date <= my_end_date
      AND o.patient_id = my_patient_id
      AND o.site_id = my_site_id
    GROUP BY o.patient_id;
 
  OPEN cur1;
 
  SET flag = 0;
 
  read_loop: LOOP
    FETCH cur1 INTO my_drug_id, my_start_date, my_daily_dose, my_quantity, my_obs_datetime;
 
    IF done THEN
      CLOSE cur1;
      LEAVE read_loop;
    END IF;
 
    IF DATE(my_obs_datetime) = DATE(@obs_datetime) THEN
 
      IF my_daily_dose = 0 OR LENGTH(my_daily_dose) < 1 OR my_daily_dose IS NULL THEN
        SET my_daily_dose = 1;
      END IF;
 
            SET my_pill_count = drug_pill_count(my_patient_id, my_drug_id, my_obs_datetime, my_site_id);
 
            SET @expiry_date = ADDDATE(DATE_SUB(my_start_date, INTERVAL 1 DAY), ((my_quantity + my_pill_count)/my_daily_dose));
 
      IF my_expiry_date IS NULL THEN
        SET my_expiry_date = @expiry_date;
      END IF;
 
      IF @expiry_date < my_expiry_date THEN
        SET my_expiry_date = @expiry_date;
            END IF;
        END IF;
    END LOOP;
 
    IF TIMESTAMPDIFF(day, DATE(my_expiry_date), DATE(my_end_date)) >= 30 THEN
        SET my_default_date = ADDDATE(my_expiry_date, 31);
    END IF;

  RETURN my_default_date; 
END$$
DELIMITER ;

-- Date antiretrovirals started
DROP FUNCTION IF EXISTS date_antiretrovirals_started;

DELIMITER $$
CREATE FUNCTION date_antiretrovirals_started(set_patient_id INT, min_state_date DATE, my_site_id INT) RETURNS DATE
DETERMINISTIC
BEGIN
DECLARE date_started DATE;
DECLARE estimated_art_date DATE;
DECLARE estimated_art_date_months  VARCHAR(45);


SET date_started = (SELECT LEFT(value_datetime,10) FROM obs WHERE concept_id = 2516 AND encounter_id > 0 
AND person_id = set_patient_id AND voided = 0 AND site_id = my_site_id LIMIT 1);

IF date_started IS NULL then
  SET estimated_art_date_months = (SELECT value_text FROM obs WHERE encounter_id > 0 AND concept_id = 2516 
  AND person_id = set_patient_id AND voided = 0 AND site_id = my_site_id LIMIT 1);
  SET min_state_date = (SELECT obs_datetime FROM obs WHERE encounter_id > 0 AND concept_id = 2516 
  AND person_id = set_patient_id AND voided = 0 AND site_id = my_site_id LIMIT 1);

  IF estimated_art_date_months = "6 months" THEN set date_started = (SELECT DATE_SUB(min_state_date, INTERVAL 6 MONTH));
  ELSEIF estimated_art_date_months = "12 months" THEN set date_started = (SELECT DATE_SUB(min_state_date, INTERVAL 12 MONTH));
  ELSEIF estimated_art_date_months = "18 months" THEN set date_started = (SELECT DATE_SUB(min_state_date, INTERVAL 18 MONTH));
  ELSEIF estimated_art_date_months = "24 months" THEN set date_started = (SELECT DATE_SUB(min_state_date, INTERVAL 24 MONTH));
  ELSEIF estimated_art_date_months = "48 months" THEN set date_started = (SELECT DATE_SUB(min_state_date, INTERVAL 48 MONTH));
  ELSEIF estimated_art_date_months = "Over 2 years" THEN set date_started = (SELECT DATE_SUB(min_state_date, INTERVAL 60 MONTH));
  ELSE
    SET date_started = patient_start_date(set_patient_id, my_site_id);
  END IF;
END IF;

RETURN date_started;
END$$
DELIMITER ;



-- Died In
DROP FUNCTION IF EXISTS died_in;
DELIMITER $$
CREATE FUNCTION died_in(set_patient_id INT, set_status VARCHAR(25), date_enrolled DATE, my_site_id INT) RETURNS varchar(25)
DETERMINISTIC
BEGIN
DECLARE set_outcome varchar(25) default 'N/A';
DECLARE date_of_death DATE;
DECLARE num_of_days INT;

IF set_status = 'Patient died' THEN

  SET date_of_death = (
    SELECT COALESCE(death_date, outcome_date)
    FROM temp_patient_outcomes INNER JOIN temp_earliest_start_date USING (patient_id)
    WHERE cum_outcome = 'Patient died' AND patient_id = set_patient_id
    AND temp_patient_outcomes.site_id = my_site_id AND temp_earliest_start_date.site_id = my_site_id
  );

  IF date_of_death IS NULL THEN
    RETURN 'Unknown';
  END IF;


  set num_of_days = (TIMESTAMPDIFF(day, date(date_enrolled), date(date_of_death)));

  IF num_of_days <= 30 THEN set set_outcome ="1st month";
  ELSEIF num_of_days <= 60 THEN set set_outcome ="2nd month";
  ELSEIF num_of_days <= 91 THEN set set_outcome ="3rd month";
  ELSEIF num_of_days > 91 THEN set set_outcome ="4+ months";
  ELSEIF num_of_days IS NULL THEN set set_outcome = "Unknown";
  END IF;


END IF;

RETURN set_outcome;
END$$
DELIMITER ;


-- Disaggregated age group
DROP FUNCTION IF EXISTS disaggregated_age_group;

DELIMITER $$
CREATE FUNCTION disaggregated_age_group(birthdate varchar(30), end_date varchar(30)) RETURNS varchar(25)
DETERMINISTIC
BEGIN
    DECLARE age_in_months INT(11);
    DECLARE age_in_years INT(11);
    DECLARE age_group VARCHAR(15);

    SET age_in_months = (SELECT timestampdiff(month, birthdate, end_date));
    SET age_in_years  = (SELECT timestampdiff(year, birthdate, end_date));
    SET age_group = ('Unknown');

    IF age_in_months >= 0 AND age_in_months <= 11 THEN SET age_group = "<1 year";
    ELSEIF age_in_years >= 1 AND age_in_years <= 4 THEN SET age_group = "1-4 years";
    ELSEIF age_in_years >= 5 AND age_in_years <= 9 THEN SET age_group = "5-9 years";
    ELSEIF age_in_years >= 10 AND age_in_years <= 14 THEN SET age_group = "10-14 years";
    ELSEIF age_in_years >= 15 AND age_in_years <= 19 THEN SET age_group = "15-19 years";
    ELSEIF age_in_years >= 20 AND age_in_years <= 24 THEN SET age_group = "20-24 years";
    ELSEIF age_in_years >= 25 AND age_in_years <= 29 THEN SET age_group = "25-29 years";
    ELSEIF age_in_years >= 30 AND age_in_years <= 34 THEN SET age_group = "30-34 years";
    ELSEIF age_in_years >= 35 AND age_in_years <= 39 THEN SET age_group = "35-39 years";
    ELSEIF age_in_years >= 40 AND age_in_years <= 44 THEN SET age_group = "40-44 years";
    ELSEIF age_in_years >= 45 AND age_in_years <= 49 THEN SET age_group = "45-49 years";
    ELSEIF age_in_years >= 50 AND age_in_years <= 54 THEN SET age_group = "50-54 years";
    ELSEIF age_in_years >= 55 AND age_in_years <= 59 THEN SET age_group = "55-59 years";
    ELSEIF age_in_years >= 60 AND age_in_years <= 64 THEN SET age_group = "60-64 years";
    ELSEIF age_in_years >= 65 AND age_in_years <= 69 THEN SET age_group = "65-69 years";
    ELSEIF age_in_years >= 70 AND age_in_years <= 74 THEN SET age_group = "70-74 years";
    ELSEIF age_in_years >= 75 AND age_in_years <= 79 THEN SET age_group = "75-79 years";
    ELSEIF age_in_years >= 80 AND age_in_years <= 84 THEN SET age_group = "80-84 years";
    ELSEIF age_in_years >= 85 AND age_in_years <= 89 THEN SET age_group = "85-89 years";
    ELSEIF age_in_years >= 90 THEN SET age_group = "90 plus years";
    END IF;

    RETURN age_group;
END$$
DELIMITER ;


-- Drug pill count >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DROP FUNCTION IF EXISTS drug_pill_count;

DELIMITER $$
CREATE FUNCTION drug_pill_count(my_patient_id INT, my_drug_id INT, my_date DATE, my_site_id INT) RETURNS INT
DETERMINISTIC
BEGIN
DECLARE done INT DEFAULT FALSE;
  DECLARE my_pill_count, my_total_numeric, my_total_text, my_total_transfer_in DECIMAL;
 
  DECLARE cur1 CURSOR FOR SELECT SUM(ob.value_numeric), SUM(
	CASE 
		when ob.value_text is null then 0
        when ob.value_text REGEXP '^[0-9]+(\.[0-9]+)?$' then ob.value_text
        ELSE 0
	end 
							) FROM obs ob
                        INNER JOIN drug_order do ON ob.order_id = do.order_id AND do.site_id = my_site_id AND do.drug_inventory_id = my_drug_id -- AND do.quantity > 0
                        INNER JOIN orders o ON do.order_id = o.order_id AND o.site_id = my_site_id AND o.patient_id = my_patient_id AND o.voided = 0
                    WHERE ob.person_id = my_patient_id
                        AND ob.concept_id = 2540
                        AND ob.voided = 0
                        AND DATE(ob.obs_datetime) = my_date
                    GROUP BY ob.person_id;
 
  DECLARE cur2 CURSOR FOR SELECT SUM(ob.value_numeric) FROM obs ob
                    WHERE ob.person_id = my_patient_id
                        AND ob.concept_id = (SELECT concept_id FROM drug WHERE drug_id = my_drug_id)
                        AND ob.voided = 0
                        AND ob.site_id = my_site_id
                        AND DATE(ob.obs_datetime) = my_date
                    GROUP BY ob.person_id;
  DECLARE cur3 CURSOR FOR SELECT SUM(ob.value_numeric)
                    FROM obs ob
                    INNER JOIN encounter e ON e.encounter_id = ob.encounter_id AND e.voided = 0 AND e.program_id = 1 AND e.site_id = my_site_id AND e.patient_id = my_patient_id
                    INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type AND et.retired = 0 AND et.name = 'HIV CLINIC CONSULTATION'
                    WHERE ob.person_id = my_patient_id
                        AND ob.concept_id = 2540
                        AND ob.voided = 0
                        AND ob.site_id = my_site_id
                        AND DATE(ob.obs_datetime) = my_date
                        AND ob.value_drug = my_drug_id
                    GROUP BY ob.person_id;
 
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
 
  OPEN cur1;
 
  SET my_pill_count = 0;
 
  read_loop1: LOOP
    FETCH cur1 INTO my_total_numeric, my_total_text;
 
    IF done THEN
      CLOSE cur1;
      LEAVE read_loop1;
    END IF;
 
    IF my_total_numeric IS NULL THEN
      SET my_total_numeric = 0;
    END IF;
    IF my_total_text IS NULL THEN
      SET my_total_text = 0;
    END IF;
 
    SET my_pill_count = my_total_numeric + my_total_text;
  END LOOP;
 
  SET done = FALSE;
  OPEN cur2;
  read_loop2: LOOP
    FETCH cur2 INTO my_total_numeric;
 
    IF done THEN
      CLOSE cur2;
      LEAVE read_loop2;
    END IF;
 
    IF my_total_numeric IS NULL THEN
      SET my_total_numeric = 0;
    END IF;
 
    SET my_pill_count = my_total_numeric + my_pill_count;
  END LOOP;
 
  SET done = FALSE;
  OPEN cur3;
  read_loop3: LOOP
    FETCH cur3 INTO my_total_transfer_in;
 
    IF done THEN
      CLOSE cur3;
      LEAVE read_loop3;
    END IF;
 
    IF my_total_transfer_in IS NULL THEN
      SET my_total_transfer_in = 0;
    END IF;
 
    SET my_pill_count = my_total_transfer_in + my_pill_count;
  END LOOP;
 
  RETURN my_pill_count;
END$$
DELIMITER ;


-- Female maternal status
DROP FUNCTION IF EXISTS female_maternal_status;
DELIMITER $$
CREATE FUNCTION female_maternal_status(my_patient_id INT, end_datetime DATETIME, my_site_id INT) RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
DECLARE breastfeeding_date DATETIME;
DECLARE pregnant_date DATETIME;
DECLARE maternal_status VARCHAR(20);
DECLARE obs_value_coded INT(11);


SET @reason_for_starting = (SELECT concept_id FROM concept_name WHERE name = 'Reason for ART eligibility' LIMIT 1);

SET @pregnant_concepts := (SELECT GROUP_CONCAT(concept_id) FROM concept_name WHERE name IN('Is patient pregnant?','Patient pregnant'));
SET @breastfeeding_concept := (SELECT GROUP_CONCAT(concept_id) FROM concept_name WHERE name = 'Breastfeeding');

SET pregnant_date = (SELECT MAX(obs_datetime) FROM obs WHERE concept_id IN(@pregnant_concepts) 
AND voided = 0 AND person_id = my_patient_id AND obs_datetime <= end_datetime AND site_id = my_site_id);
SET breastfeeding_date = (SELECT MAX(obs_datetime) FROM obs WHERE concept_id IN(@breastfeeding_concept) 
AND voided = 0 AND person_id = my_patient_id AND obs_datetime <= end_datetime AND site_id = my_site_id);

IF pregnant_date IS NULL THEN
  SET pregnant_date = (SELECT MAX(obs_datetime) FROM obs WHERE concept_id = @reason_for_starting 
  AND voided = 0 AND person_id = my_patient_id AND obs_datetime <= end_datetime 
  AND site_id = my_site_id AND value_coded IN(1755));
END IF;

IF breastfeeding_date IS NULL THEN
  SET breastfeeding_date = (SELECT MAX(obs_datetime) FROM obs WHERE concept_id = @reason_for_starting 
  AND voided = 0 AND person_id = my_patient_id AND obs_datetime <= end_datetime 
  AND site_id = my_site_id AND value_coded IN(834,5632));
END IF;

IF pregnant_date IS NULL AND breastfeeding_date IS NULL THEN SET maternal_status = "FNP";
ELSEIF pregnant_date IS NOT NULL AND breastfeeding_date IS NOT NULL THEN SET maternal_status = "Unknown";
ELSEIF pregnant_date IS NULL AND breastfeeding_date IS NOT NULL THEN SET maternal_status = "Check BF";
ELSEIF pregnant_date IS NOT NULL AND breastfeeding_date IS NULL THEN SET maternal_status = "Check FP";
END IF;

IF maternal_status = 'Unknown' THEN

  IF breastfeeding_date <= pregnant_date THEN
    SET obs_value_coded = (SELECT value_coded FROM obs WHERE concept_id IN(@pregnant_concepts) AND voided = 0 
    AND person_id = my_patient_id AND site_id = my_site_id AND obs_datetime = pregnant_date LIMIT 1);
    IF obs_value_coded = 1065 THEN SET maternal_status = 'FP';
    ELSEIF obs_value_coded = 1066 THEN SET maternal_status = 'FNP';
    END IF;
  END IF;

  IF breastfeeding_date > pregnant_date THEN
    SET obs_value_coded = (SELECT value_coded FROM obs WHERE concept_id IN(@breastfeeding_concept) 
    AND site_id = my_site_id AND voided = 0 AND person_id = my_patient_id AND obs_datetime = breastfeeding_date LIMIT 1);
    IF obs_value_coded = 1065 THEN SET maternal_status = 'FBf';
    ELSEIF obs_value_coded = 1066 THEN SET maternal_status = 'FNP';
    END IF;
  END IF;

  IF DATE(breastfeeding_date) = DATE(pregnant_date) AND maternal_status = 'FNP' THEN
    SET obs_value_coded = (SELECT value_coded FROM obs WHERE concept_id IN(@breastfeeding_concept) 
    AND voided = 0 AND person_id = my_patient_id 
    AND site_id = my_site_id AND obs_datetime = breastfeeding_date LIMIT 1);
    IF obs_value_coded = 1065 THEN SET maternal_status = 'FBf';
    ELSEIF obs_value_coded = 1066 THEN SET maternal_status = 'FNP';
    END IF;
  END IF;
END IF;


IF maternal_status = 'Check FP' THEN

  SET obs_value_coded = (SELECT value_coded FROM obs WHERE concept_id IN(@pregnant_concepts) 
  AND voided = 0 AND person_id = my_patient_id AND site_id = my_site_id AND obs_datetime = pregnant_date LIMIT 1);
  IF obs_value_coded = 1065 THEN SET maternal_status = 'FP';
  ELSEIF obs_value_coded = 1066 THEN SET maternal_status = 'FNP';
  END IF;

  IF obs_value_coded IS NULL THEN
    SET obs_value_coded = (SELECT GROUP_CONCAT(value_coded) FROM obs WHERE concept_id IN(7563) 
    AND voided = 0 AND person_id = my_patient_id AND site_id = my_site_id AND obs_datetime = pregnant_date);
    IF obs_value_coded IN(1755) THEN SET maternal_status = 'FP';
    END IF;
  END IF;

  IF maternal_status = 'Check FP' THEN SET maternal_status = 'FNP';
  END IF;
END IF;

IF maternal_status = 'Check BF' THEN

  SET obs_value_coded = (SELECT value_coded FROM obs WHERE concept_id IN(@breastfeeding_concept) 
  AND voided = 0 AND person_id = my_patient_id AND site_id = my_site_id AND obs_datetime = breastfeeding_date LIMIT 1);
  IF obs_value_coded = 1065 THEN SET maternal_status = 'FBf';
  ELSEIF obs_value_coded = 1066 THEN SET maternal_status = 'FNP';
  END IF;

  IF obs_value_coded IS NULL THEN
    SET obs_value_coded = (SELECT GROUP_CONCAT(value_coded) FROM obs WHERE concept_id IN(7563) 
    AND voided = 0 AND person_id = my_patient_id AND site_id = my_site_id AND obs_datetime = breastfeeding_date);
    IF obs_value_coded IN(834,5632) THEN SET maternal_status = 'FBf';
    END IF;
  END IF;

  IF maternal_status = 'Check BF' THEN SET maternal_status = 'FNP';
  END IF;
END IF;



RETURN maternal_status;
END$$
DELIMITER ;


-- Patient current regimen
DROP FUNCTION IF EXISTS patient_current_regimen;

DELIMITER $$
CREATE FUNCTION patient_current_regimen(my_patient_id INT, my_date DATE, my_site_id INT) RETURNS VARCHAR(255)
DETERMINISTIC
BEGIN
DECLARE max_obs_datetime DATETIME;
DECLARE regimen VARCHAR(10) DEFAULT 'N/A';

  SET max_obs_datetime = (
    SELECT MAX(start_date)
    FROM orders
      INNER JOIN drug_order
        ON drug_order.order_id = orders.order_id
        AND drug_order.drug_inventory_id IN (SELECT * FROM arv_drug)
        AND orders.voided = 0
        AND DATE(orders.start_date) <= DATE(my_date)
        AND orders.site_id = my_site_id
        AND drug_order.site_id = my_site_id
    WHERE orders.patient_id = my_patient_id AND drug_order.quantity > 0
  );

  SET @drug_ids := (
    SELECT GROUP_CONCAT(DISTINCT(drug_order.drug_inventory_id) ORDER BY drug_order.drug_inventory_id ASC)
    FROM drug_order
      INNER JOIN arv_drug ON drug_order.drug_inventory_id = arv_drug.drug_id
      INNER JOIN orders ON drug_order.order_id = orders.order_id AND drug_order.quantity > 0
      AND orders.site_id = my_site_id AND drug_order.site_id = my_site_id AND orders.voided = 0
      INNER JOIN encounter
        ON encounter.encounter_id = orders.encounter_id
        AND encounter.voided = 0
        AND encounter.encounter_type = 25
    WHERE date(orders.start_date) = DATE(max_obs_datetime)
      AND encounter.patient_id = my_patient_id
    ORDER BY arv_drug.drug_id ASC
  );

  SET regimen = (
    SELECT DISTINCT name FROM (
      SELECT GROUP_CONCAT(drug.drug_id ORDER BY drug.drug_id ASC) AS drugs,
             regimen_name.name AS name
      FROM moh_regimen_combination AS combo
        INNER JOIN moh_regimen_combination_drug AS drug USING (regimen_combination_id)
        INNER JOIN moh_regimen_name AS regimen_name USING (regimen_name_id)
      GROUP BY combo.regimen_combination_id
    ) AS regimens
    WHERE drugs = @drug_ids
    LIMIT 1
  );

  IF regimen IS NULL THEN
    SET regimen = 'N/A';
  END IF;

  RETURN regimen;
END$$
DELIMITER ;


-- Patient given IPT
DROP FUNCTION IF EXISTS patient_given_ipt;

DELIMITER $$
CREATE FUNCTION patient_given_ipt(my_patient_id INT, my_start_date DATE, my_end_date DATE, my_site_id INT) RETURNS INT(11)
DETERMINISTIC
BEGIN
DECLARE given INT DEFAULT FALSE;
DECLARE record_value INT;

  SET record_value = (SELECT o.patient_id FROM drug_order d
      INNER JOIN orders o ON o.order_id = d.order_id
      AND o.site_id = my_site_id AND d.site_id = my_site_id
      WHERE d.drug_inventory_id IN(
        SELECT GROUP_CONCAT(DISTINCT(drug_id)
        ORDER BY drug_id ASC) FROM drug WHERE
        concept_id IN(SELECT concept_id FROM concept_name WHERE name IN('Isoniazid'))
      ) AND d.quantity > 0
      AND o.start_date = (SELECT MAX(start_date) FROM orders t WHERE t.patient_id = o.patient_id
      AND t.start_date BETWEEN DATE_FORMAT(DATE(my_start_date), '%Y-%m-%d 00:00:00')
      AND DATE_FORMAT(DATE(my_end_date), '%Y-%m-%d 23:59:59')
      AND t.patient_id = my_patient_id AND t.site_id = my_site_id
      ) GROUP BY o.patient_id);

  IF record_value IS NOT NULL THEN
    SET given = TRUE;
  END IF;


	RETURN given;
END$$
DELIMITER ;

-- Patient has side effects
DROP FUNCTION IF EXISTS patient_has_side_effects;

DELIMITER $$
CREATE FUNCTION patient_has_side_effects(my_patient_id INT, my_end_date DATE, my_site_id INT) RETURNS VARCHAR(7)
DETERMINISTIC
BEGIN
DECLARE mw_side_effects_concept_id INT;
DECLARE yes_concept_id INT;
DECLARE no_concept_id INT;
DECLARE side_effect INT;
DECLARE latest_obs_date DATE;

  SET mw_side_effects_concept_id = (SELECT concept_id FROM concept_name
    WHERE name IN('Malawi ART Side Effects') AND voided = 0 LIMIT 1);

  SET yes_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'YES' LIMIT 1);
  SET no_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'NO' LIMIT 1);

  SET latest_obs_date = (SELECT DATE(MAX(t.obs_datetime)) FROM obs t
        WHERE t.site_id = my_site_id AND t.obs_datetime <= DATE_FORMAT(DATE(my_end_date), '%Y-%m-%d 23:59:59')
        AND t.concept_id = mw_side_effects_concept_id AND t.voided = 0
        AND t.person_id = my_patient_id);

  IF latest_obs_date IS NULL THEN
    return 'Unknown';
  END IF;



  SET side_effect = (SELECT value_coded FROM obs
      INNER JOIN temp_earliest_start_date e ON e.patient_id = obs.person_id
      AND obs.site_id = my_site_id AND e.site_id = my_site_id
      WHERE obs_group_id IN (
      SELECT obs_id FROM obs
      WHERE site_id = my_site_id 
        AND concept_id = mw_side_effects_concept_id
        AND person_id = my_patient_id
        AND obs.obs_datetime BETWEEN DATE_FORMAT(DATE(latest_obs_date), '%Y-%m-%d 00:00:00')
        AND DATE_FORMAT(DATE(latest_obs_date), '%Y-%m-%d 23:59:59')
        AND DATE(obs_datetime) != DATE(e.date_enrolled)
      )GROUP BY concept_id HAVING value_coded = yes_concept_id LIMIT 1);

  IF side_effect IS NOT NULL THEN
    return 'Yes';
  END IF;


	RETURN 'No';
END$$
DELIMITER ;

-- Patient outcome
DROP FUNCTION IF EXISTS patient_outcome;

DELIMITER $$
CREATE FUNCTION patient_outcome(my_patient_id INT, visit_date DATE, my_site_id INT) RETURNS VARCHAR(45)
DETERMINISTIC
BEGIN
DECLARE set_program_id INT;
DECLARE set_patient_state INT;
DECLARE set_outcome varchar(25);
DECLARE set_date_started date;
DECLARE set_patient_state_died INT;
DECLARE set_died_concept_id INT;
DECLARE set_timestamp DATETIME;
DECLARE dispensed_quantity INT;
 
SET set_timestamp = TIMESTAMP(CONCAT(DATE(visit_date), ' ', '23:59:59'));
SET set_program_id = (SELECT program_id FROM program WHERE name ="HIV PROGRAM" LIMIT 1);
 
SET set_patient_state = (
	SELECT state
	FROM `patient_state`
	INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id AND p.program_id = set_program_id 
		AND p.site_id = my_site_id AND patient_state.site_id = my_site_id AND p.voided = 0  AND p.patient_id = my_patient_id
	WHERE patient_state.voided = 0 AND DATE(patient_state.start_date) <= visit_date AND patient_state.site_id = my_site_id
	ORDER BY start_date DESC, patient_state.patient_state_id DESC, patient_state.date_created DESC
    LIMIT 1
);
 
IF set_patient_state = 1 THEN
  SET set_patient_state = current_defaulter(my_patient_id, set_timestamp, my_site_id);
 
  IF set_patient_state = 1 THEN
    SET set_outcome = 'Defaulted';
  ELSE
    SET set_outcome = 'Pre-ART (Continue)';
  END IF;
END IF;
 
IF set_patient_state = 2   THEN
  SET set_outcome = 'Patient transferred out';
END IF;
 
IF set_patient_state = 3 OR set_patient_state = 127 THEN
  SET set_outcome = 'Patient died';
END IF;
 
 
IF set_patient_state != 3 AND set_patient_state != 127 THEN
  SET set_patient_state_died = (
	SELECT state
	FROM `patient_state`
	INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id AND p.patient_id = my_patient_id AND p.program_id = set_program_id AND p.voided = 0 AND p.patient_id = my_patient_id AND p.site_id = my_site_id
	WHERE patient_state.voided = 0 AND DATE(patient_state.start_date) <= visit_date AND state = 3 AND patient_state.site_id = my_site_id
	ORDER BY patient_state.patient_state_id DESC, patient_state.date_created DESC, start_date DESC 
	LIMIT 1
  );
 
  SET set_died_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Patient died' LIMIT 1);
 
  IF set_patient_state_died IN(SELECT program_workflow_state_id FROM program_workflow_state WHERE concept_id = set_died_concept_id AND retired = 0) THEN
    SET set_outcome = 'Patient died';
    SET set_patient_state = 3;
  END IF;
END IF;
 
 
IF set_patient_state = 6 THEN
  SET set_outcome = 'Treatment stopped';
END IF;
 
IF set_patient_state = 7 OR set_outcome = 'Pre-ART (Continue)' OR set_outcome IS NULL THEN
  SET set_patient_state = current_defaulter(my_patient_id, set_timestamp, my_site_id);
 
  IF set_patient_state = 1 THEN
    SET set_outcome = 'Defaulted';
  END IF;
 
  IF set_patient_state = 0 OR set_outcome IS NULL THEN
 
    SET dispensed_quantity = (SELECT d.quantity
      FROM orders o
      INNER JOIN drug_order d ON d.order_id = o.order_id
		AND o.site_id = my_site_id AND d.site_id = my_site_id AND d.quantity > 0
		AND d.drug_inventory_id IN(SELECT DISTINCT(drug_id) FROM drug WHERE concept_id IN(SELECT concept_id FROM concept_set WHERE concept_set = 1085)) 
      INNER JOIN drug ON drug.drug_id = d.drug_inventory_id
      WHERE o.patient_id = my_patient_id AND o.voided = 0 AND o.site_id = my_site_id
      AND DATE(o.start_date) <= visit_date AND d.quantity > 0 ORDER BY start_date DESC LIMIT 1);
 
    IF dispensed_quantity > 0 THEN
      SET set_outcome = 'On antiretrovirals';
    END IF;
  END IF;
END IF;
 
IF set_outcome IS NULL THEN
  SET set_patient_state = current_defaulter(my_patient_id, set_timestamp, my_site_id);
 
  IF set_patient_state = 1 THEN
    SET set_outcome = 'Defaulted';
  END IF;
 
  IF set_outcome IS NULL THEN
    SET set_outcome = 'Unknown';
  END IF;
 
END IF;
 
RETURN set_outcome;
END$$
DELIMITER ;



-- patient reason for starting ART
DROP FUNCTION IF EXISTS patient_reason_for_starting_art;

DELIMITER $$
CREATE FUNCTION patient_reason_for_starting_art(my_patient_id INT, my_site_id INT) RETURNS INT(11)
DETERMINISTIC
BEGIN
    
  DECLARE reason_for_art_eligibility INT DEFAULT 0;
  DECLARE reason_concept_id INT;
  DECLARE coded_concept_id INT;
  DECLARE max_obs_datetime DATETIME;

  SET reason_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Reason for ART eligibility' AND voided = 0 LIMIT 1);
  SET max_obs_datetime = (SELECT MAX(obs_datetime) FROM obs WHERE person_id = my_patient_id AND concept_id = reason_concept_id AND voided = 0 AND site_id = my_site_id);
  SET coded_concept_id = (SELECT value_coded FROM obs WHERE person_id = my_patient_id AND concept_id = reason_concept_id AND voided = 0 AND obs_datetime = max_obs_datetime AND site_id = my_site_id LIMIT 1);
  SET reason_for_art_eligibility = (coded_concept_id);


  RETURN reason_for_art_eligibility;

END$$
DELIMITER ;


-- patient reason for starting ART text
DROP FUNCTION IF EXISTS patient_reason_for_starting_art_text;

DELIMITER $$
CREATE FUNCTION patient_reason_for_starting_art_text(my_patient_id INT, my_site_id INT) RETURNS VARCHAR(255)
DETERMINISTIC
BEGIN
  DECLARE reason_for_art_eligibility VARCHAR(255);
  DECLARE reason_concept_id INT;
  DECLARE coded_concept_id INT;
  DECLARE max_obs_datetime DATETIME;

  SET reason_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Reason for ART eligibility' AND voided = 0 LIMIT 1);
  SET max_obs_datetime = (SELECT MAX(obs_datetime) FROM obs WHERE person_id = my_patient_id AND concept_id = reason_concept_id AND voided = 0 AND site_id = my_site_id);
  SET coded_concept_id = (SELECT value_coded FROM obs WHERE person_id = my_patient_id AND concept_id = reason_concept_id AND voided = 0 AND obs_datetime = max_obs_datetime AND site_id = my_site_id LIMIT 1);
  SET reason_for_art_eligibility = (SELECT name FROM concept_name WHERE concept_id = coded_concept_id AND LENGTH(name) > 0 LIMIT 1);

  RETURN reason_for_art_eligibility;
END$$
DELIMITER ;

-- Patient screened for TB
DROP FUNCTION IF EXISTS patient_screened_for_tb;

DELIMITER $$
CREATE FUNCTION patient_screened_for_tb(my_patient_id INT, my_start_date DATE, my_end_date DATE, my_site_id INT) RETURNS int(11)
DETERMINISTIC
BEGIN
    DECLARE screened INT DEFAULT FALSE;
	DECLARE record_value INT;

  SET record_value = (SELECT ob.person_id FROM obs ob
    INNER JOIN temp_earliest_start_date e
    ON e.patient_id = ob.person_id
    AND e.site_id = my_site_id AND ob.site_id = my_site_id
    WHERE ob.concept_id IN(
      SELECT GROUP_CONCAT(DISTINCT(concept_id)
      ORDER BY concept_id ASC) FROM concept_name
      WHERE name IN('TB treatment','TB status') AND voided = 0
    ) AND ob.voided = 0
    AND ob.obs_datetime = (
    SELECT MAX(t.obs_datetime) FROM obs t WHERE
    t.obs_datetime BETWEEN DATE_FORMAT(DATE(my_start_date), '%Y-%m-%d 00:00:00')
    AND DATE_FORMAT(DATE(my_end_date), '%Y-%m-%d 23:59:59')
    AND t.site_id = my_site_id AND t.person_id = ob.person_id AND t.concept_id IN(
      SELECT GROUP_CONCAT(DISTINCT(concept_id)
      ORDER BY concept_id ASC) FROM concept_name
      WHERE name IN('TB treatment','TB status') AND voided = 0))
    AND ob.person_id = my_patient_id
    GROUP BY ob.person_id);

  IF record_value IS NOT NULL THEN
    SET screened = TRUE;
  END IF;

	RETURN screened;
END$$

DELIMITER ;


-- Patient start date
DROP FUNCTION IF EXISTS patient_start_date;

DELIMITER $$
CREATE FUNCTION patient_start_date(patient_id INT, my_site_id INT) RETURNS DATE
DETERMINISTIC
BEGIN
DECLARE start_date VARCHAR(10);
DECLARE dispension_concept_id INT;
DECLARE arv_concept INT;

set dispension_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'AMOUNT DISPENSED');
set arv_concept = (SELECT concept_id FROM concept_name WHERE name = "ANTIRETROVIRAL DRUGS");

set start_date = (SELECT MIN(DATE(obs_datetime)) FROM obs WHERE voided = 0 
AND person_id = patient_id AND concept_id = dispension_concept_id 
AND site_id = my_site_id AND value_drug IN (SELECT drug_id FROM drug d 
WHERE d.concept_id IN (SELECT cs.concept_id FROM concept_set cs WHERE cs.concept_set = arv_concept)));

RETURN start_date;
END$$

DELIMITER ;


-- Patient TB status
DROP FUNCTION IF EXISTS patient_tb_status;

DELIMITER $$
CREATE FUNCTION patient_tb_status(my_patient_id INT, my_end_date DATE, my_site_id INT) RETURNS INT(11)
DETERMINISTIC
BEGIN
    DECLARE screened INT DEFAULT FALSE;
    DECLARE tb_status INT;
    DECLARE tb_status_concept_id INT;

    SET tb_status_concept_id = (SELECT concept_id FROM concept_name
    WHERE name IN('TB status') AND voided = 0 LIMIT 1);

    SET tb_status = (SELECT ob.value_coded FROM obs ob
    INNER JOIN concept_name cn
    ON ob.value_coded = cn.concept_id AND ob.site_id = my_site_id 
    WHERE ob.concept_id = tb_status_concept_id AND ob.voided = 0
    AND ob.obs_datetime = (
    SELECT MAX(t.obs_datetime) FROM obs t WHERE
    t.obs_datetime <= DATE_FORMAT(DATE(my_end_date), '%Y-%m-%d 23:59:59')
    AND t.voided = 0 AND t.person_id = ob.person_id AND t.concept_id = tb_status_concept_id AND t.site_id = my_site_id)
    AND ob.person_id = my_patient_id
    GROUP BY ob.person_id);

	RETURN tb_status;
END$$

DELIMITER ;

-- Patient WHO stage
DROP FUNCTION IF EXISTS patient_who_stage;

DELIMITER $$
CREATE FUNCTION patient_who_stage(my_patient_id INT, my_site_id INT) RETURNS VARCHAR(50)
DETERMINISTIC
BEGIN
  DECLARE who_stage VARCHAR(255);
  DECLARE reason_concept_id INT;
  DECLARE coded_concept_id INT;
  DECLARE max_obs_datetime DATETIME;

  SET reason_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'WHO stage' AND voided = 0 LIMIT 1);
  SET max_obs_datetime = (SELECT MAX(obs_datetime) FROM obs WHERE person_id = my_patient_id AND site_id = my_site_id AND concept_id = reason_concept_id AND voided = 0);
  SET coded_concept_id = (SELECT value_coded FROM obs WHERE person_id = my_patient_id AND site_id = my_site_id AND concept_id = reason_concept_id AND voided = 0 AND obs_datetime = max_obs_datetime  LIMIT 1);
  SET who_stage = (SELECT name FROM concept_name WHERE concept_id = coded_concept_id AND LENGTH(name) > 0 LIMIT 1);

  RETURN who_stage;
END$$

DELIMITER ;


-- PEPFAR patient outcome
DROP FUNCTION IF EXISTS pepfar_patient_outcome;

DELIMITER $$
CREATE FUNCTION pepfar_patient_outcome(my_patient_id INT, visit_date DATE, my_site_id INT) RETURNS VARCHAR(45)
DETERMINISTIC
BEGIN
DECLARE set_program_id INT;
DECLARE set_patient_state INT;
DECLARE set_outcome varchar(25);
DECLARE set_date_started date;
DECLARE set_patient_state_died INT;
DECLARE set_died_concept_id INT;
DECLARE set_timestamp DATETIME;
DECLARE dispensed_quantity INT;
 
SET set_timestamp = TIMESTAMP(CONCAT(DATE(visit_date), ' ', '23:59:59'));
SET set_program_id = (SELECT program_id FROM program WHERE name ="HIV PROGRAM" LIMIT 1);
 
SET set_patient_state = (
	SELECT state
	FROM `patient_state`
	INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id AND p.program_id = set_program_id 
		AND p.site_id = my_site_id AND patient_state.site_id = my_site_id AND p.voided = 0  AND p.patient_id = my_patient_id
	WHERE patient_state.voided = 0 AND DATE(patient_state.start_date) <= visit_date AND patient_state.site_id = my_site_id
	ORDER BY start_date DESC, patient_state.patient_state_id DESC, patient_state.date_created DESC
    LIMIT 1
);
 
IF set_patient_state = 1 THEN
  SET set_patient_state = current_pepfar_defaulter(my_patient_id, set_timestamp, my_site_id);
 
  IF set_patient_state = 1 THEN
    SET set_outcome = 'Defaulted';
  ELSE
    SET set_outcome = 'Pre-ART (Continue)';
  END IF;
END IF;
 
IF set_patient_state = 2   THEN
  SET set_outcome = 'Patient transferred out';
END IF;
 
IF set_patient_state = 3 OR set_patient_state = 127 THEN
  SET set_outcome = 'Patient died';
END IF;
 
 
IF set_patient_state != 3 AND set_patient_state != 127 THEN
  SET set_patient_state_died = (
	SELECT state
	FROM `patient_state`
	INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id AND p.patient_id = my_patient_id AND p.program_id = set_program_id AND p.voided = 0 AND p.patient_id = my_patient_id AND p.site_id = my_site_id
	WHERE patient_state.voided = 0 AND DATE(patient_state.start_date) <= visit_date AND state = 3 AND patient_state.site_id = my_site_id
	ORDER BY patient_state.patient_state_id DESC, patient_state.date_created DESC, start_date DESC 
	LIMIT 1
  );
 
  SET set_died_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Patient died' LIMIT 1);
 
  IF set_patient_state_died IN(SELECT program_workflow_state_id FROM program_workflow_state WHERE concept_id = set_died_concept_id AND retired = 0) THEN
    SET set_outcome = 'Patient died';
    SET set_patient_state = 3;
  END IF;
END IF;
 
 
IF set_patient_state = 6 THEN
  SET set_outcome = 'Treatment stopped';
END IF;
 
IF set_patient_state = 7 OR set_outcome = 'Pre-ART (Continue)' OR set_outcome IS NULL THEN
  SET set_patient_state = current_pepfar_defaulter(my_patient_id, set_timestamp, my_site_id);
 
  IF set_patient_state = 1 THEN
    SET set_outcome = 'Defaulted';
  END IF;
 
  IF set_patient_state = 0 OR set_outcome IS NULL THEN
 
    SET dispensed_quantity = (SELECT d.quantity
      FROM orders o
      INNER JOIN drug_order d ON d.order_id = o.order_id
		AND o.site_id = my_site_id AND d.site_id = my_site_id AND d.quantity > 0
		AND d.drug_inventory_id IN(SELECT DISTINCT(drug_id) FROM drug WHERE concept_id IN(SELECT concept_id FROM concept_set WHERE concept_set = 1085)) 
      INNER JOIN drug ON drug.drug_id = d.drug_inventory_id
      WHERE o.patient_id = my_patient_id AND o.voided = 0 AND o.site_id = my_site_id
      AND DATE(o.start_date) <= visit_date AND d.quantity > 0 ORDER BY start_date DESC LIMIT 1);
 
    IF dispensed_quantity > 0 THEN
      SET set_outcome = 'On antiretrovirals';
    END IF;
  END IF;
END IF;
 
IF set_outcome IS NULL THEN
  SET set_patient_state = current_pepfar_defaulter(my_patient_id, set_timestamp, my_site_id);
 
  IF set_patient_state = 1 THEN
    SET set_outcome = 'Defaulted';
  END IF;
 
  IF set_outcome IS NULL THEN
    SET set_outcome = 'Unknown';
  END IF;
 
END IF;
 
RETURN set_outcome;
END$$
DELIMITER ;

  

-- Re-initiated check
DROP FUNCTION IF EXISTS re_initiated_check;

DELIMITER $$
CREATE FUNCTION re_initiated_check(set_patient_id INT, set_date_enrolled DATE, my_site_id INT) RETURNS varchar(15) 
DETERMINISTIC
BEGIN
DECLARE re_initiated VARCHAR(15) DEFAULT 'N/A';
DECLARE check_one INT DEFAULT 0;
DECLARE check_two INT DEFAULT 0;

DECLARE yes_concept INT;
DECLARE no_concept INT;
DECLARE date_art_last_taken_concept INT;
DECLARE taken_arvs_concept INT;

set yes_concept = (SELECT concept_id FROM concept_name WHERE name ='YES' LIMIT 1);
set no_concept = (SELECT concept_id FROM concept_name WHERE name ='NO' LIMIT 1);
set date_art_last_taken_concept = (SELECT concept_id FROM concept_name WHERE name ='DATE ART LAST TAKEN' LIMIT 1);

set check_one = (SELECT e.patient_id FROM clinic_registration_encounter e 
INNER JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id 
AND e.site_id = my_site_id AND ero.site_id = my_site_id
INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.concept_id = date_art_last_taken_concept 
AND o.voided = 0 AND o.site_id = my_site_id
WHERE ((o.concept_id = date_art_last_taken_concept 
AND (TIMESTAMPDIFF(day, o.value_datetime, o.obs_datetime)) > 14)) 
AND patient_date_enrolled(e.patient_id, my_site_id) = set_date_enrolled AND e.patient_id = set_patient_id GROUP BY e.patient_id);

if check_one >= 1 then set re_initiated ="Re-initiated";
elseif check_two >= 1 then set re_initiated ="Re-initiated";
end if;

if check_one = 'N/A' then
    set taken_arvs_concept = (SELECT concept_id FROM concept_name WHERE name ='HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS' LIMIT 1);
    set check_two = (SELECT e.patient_id FROM clinic_registration_encounter e 
    INNER JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id
    AND e.site_id = my_site_id AND ero.site_id = my_site_id
    INNER JOIN obs o ON o.encounter_id = e.encounter_id 
    AND o.concept_id = taken_arvs_concept AND o.voided = 0 AND o.site_id = my_site_id
    WHERE  ((o.concept_id = taken_arvs_concept AND o.value_coded = no_concept)) 
    AND patient_date_enrolled(e.patient_id, my_site_id) = set_date_enrolled AND e.patient_id = set_patient_id GROUP BY e.patient_id);

    if check_two >= 1 then set re_initiated ="Re-initiated";
    end if;
end if;

RETURN re_initiated;
END$$

DELIMITER ;
