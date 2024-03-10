






-- Non-voided HIV Clinic Registration encounters
DROP TABLE IF EXISTS `clinic_registration_encounter`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
	VIEW `clinic_registration_encounter` AS
	SELECT `encounter`.`encounter_id` AS `encounter_id`,
         `encounter`.`encounter_type` AS `encounter_type`,
         `encounter`.`patient_id` AS `patient_id`,
         `encounter`.`provider_id` AS `provider_id`,
         `encounter`.`location_id` AS `location_id`,
         `encounter`.`form_id` AS `form_id`,
         `encounter`.`encounter_datetime` AS `encounter_datetime`,
         `encounter`.`creator` AS `creator`,
         `encounter`.`date_created` AS `date_created`,
         `encounter`.`voided` AS `voided`,
         `encounter`.`voided_by` AS `voided_by`,
         `encounter`.`date_voided` AS `date_voided`,
         `encounter`.`void_reason` AS `void_reason`,
         `encounter`.`uuid` AS `uuid`,
         `encounter`.`changed_by` AS `changed_by`,
         `encounter`.`date_changed` AS `date_changed`
	FROM `encounter`
	WHERE (`encounter`.`encounter_type` = 9 AND `encounter`.`voided` = 0);


-- 7937 = Ever registered at ART clinic
DROP TABLE IF EXISTS `ever_registered_obs`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `ever_registered_obs` AS
  SELECT `obs`.`obs_id` AS `obs_id`,
         `obs`.`person_id` AS `person_id`,
         `obs`.`concept_id` AS `concept_id`,
         `obs`.`encounter_id` AS `encounter_id`,
         `obs`.`order_id` AS `order_id`,
         `obs`.`obs_datetime` AS `obs_datetime`,
         `obs`.`location_id` AS `location_id`,
         `obs`.`obs_group_id` AS `obs_group_id`,
         `obs`.`accession_number` AS `accession_number`,
         `obs`.`value_group_id` AS `value_group_id`,
         `obs`.`value_boolean` AS `value_boolean`,
         `obs`.`value_coded` AS `value_coded`,
         `obs`.`value_coded_name_id` AS `value_coded_name_id`,
         `obs`.`value_drug` AS `value_drug`,
         `obs`.`value_datetime` AS `value_datetime`,
         `obs`.`value_numeric` AS `value_numeric`,
         `obs`.`value_modifier` AS `value_modifier`,
         `obs`.`value_text` AS `value_text`,
         `obs`.`date_started` AS `date_started`,
         `obs`.`date_stopped` AS `date_stopped`,
         `obs`.`comments` 
	FROM `obs`
  WHERE ((`obs`.`concept_id` = 7937) AND (`obs`.`voided` = 0))
  AND (`obs`.`value_coded` = 1065);








/* MySQL function for mainly HIV program */


-- Patient date enrolled
DROP FUNCTION IF EXISTS patient_date_enrolled;

DELIMITER $$
CREATE FUNCTION patient_date_enrolled(my_patient_id INT, my_site_id INT) RETURNS DATE
DETERMINISTIC
BEGIN
    DECLARE my_start_date DATE;
    DECLARE arv_concept_id INT;

    -- Get the concept ID for 'ANTIRETROVIRAL DRUGS'
    SELECT concept_id INTO arv_concept_id 
    FROM concept_name 
    WHERE name = 'ANTIRETROVIRAL DRUGS' 
    LIMIT 1;

    -- Get the minimum start date directly
    SELECT DATE(o.start_date) INTO my_start_date 
    FROM drug_order d 
    INNER JOIN orders o ON d.order_id = o.order_id 
    WHERE o.voided = 0 
    AND d.site_id = o.site_id 
    AND o.site_id = my_site_id 
    AND o.patient_id = my_patient_id 
    AND d.quantity > 0 
    AND drug_inventory_id IN (
        SELECT drug_id 
        FROM drug 
        WHERE concept_id IN (
            SELECT concept_id 
            FROM concept_set 
            WHERE concept_set = arv_concept_id
        )
    ) 
    ORDER BY o.start_date 
    LIMIT 1;

    RETURN my_start_date;
END$$
DELIMITER ;




-- Patient start date

DROP FUNCTION IF EXISTS patient_start_date;

DELIMITER $$
CREATE FUNCTION patient_start_date(set_patient_id INT, my_site_id INT) RETURNS DATE
DETERMINISTIC
BEGIN

DECLARE start_date DATE;

-- Get the concept IDs for 'AMOUNT DISPENSED' and 'ANTIRETROVIRAL DRUGS' only once
DECLARE dispension_concept_id INT;
DECLARE arv_concept INT;

SELECT concept_id INTO dispension_concept_id FROM concept_name WHERE name = 'AMOUNT DISPENSED' LIMIT 1;
SELECT concept_id INTO arv_concept FROM concept_name WHERE name = 'ANTIRETROVIRAL DRUGS' LIMIT 1;

-- Use a single query to get the start date directly
SELECT MIN(DATE(obs.obs_datetime)) INTO start_date
FROM obs
JOIN drug d ON obs.value_drug = d.drug_id
JOIN concept_set cs ON d.concept_id = cs.concept_id
WHERE obs.voided = 0
AND obs.person_id = set_patient_id 
AND obs.concept_id = dispension_concept_id 
AND obs.site_id = my_site_id 
AND cs.concept_set = arv_concept;

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
DECLARE estimated_art_date_months  VARCHAR(45);

-- Get the initial date_started if available
SELECT LEFT(value_datetime, 10) INTO date_started
FROM obs 
WHERE concept_id = 2516 
AND encounter_id > 0 
AND person_id = set_patient_id 
AND site_id = my_site_id 
AND voided = 0 
LIMIT 1;

IF date_started IS NULL THEN
    -- Get the estimated ART start date months
    SELECT value_text INTO estimated_art_date_months
    FROM obs 
    WHERE encounter_id > 0 
    AND concept_id = 2516 
    AND person_id = set_patient_id 
    AND site_id =  my_site_id 
    AND voided = 0 
    LIMIT 1;

    -- Get the min_state_date if available
    SELECT obs_datetime INTO min_state_date
    FROM obs 
    WHERE encounter_id > 0 
    AND concept_id = 2516 
    AND person_id = set_patient_id 
    AND site_id = my_site_id 
    AND voided = 0 
    LIMIT 1;

    -- Calculate date_started based on estimated ART start date months
    CASE estimated_art_date_months
        WHEN '6 months' THEN SET date_started = DATE_SUB(min_state_date, INTERVAL 6 MONTH);
        WHEN '12 months' THEN SET date_started = DATE_SUB(min_state_date, INTERVAL 12 MONTH);
        WHEN '18 months' THEN SET date_started = DATE_SUB(min_state_date, INTERVAL 18 MONTH);
        WHEN '24 months' THEN SET date_started = DATE_SUB(min_state_date, INTERVAL 24 MONTH);
        WHEN '48 months' THEN SET date_started = DATE_SUB(min_state_date, INTERVAL 48 MONTH);
        WHEN 'Over 2 years' THEN SET date_started = DATE_SUB(min_state_date, INTERVAL 60 MONTH);
        ELSE SET date_started = patient_start_date(set_patient_id, my_site_id);
    END CASE;
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
CREATE FUNCTION current_defaulter(my_patient_id INT, my_end_date DATE, my_site_id INT) RETURNS VARCHAR(45)
DETERMINISTIC
BEGIN
    DECLARE flag INT DEFAULT 0;

    DECLARE my_obs_datetime DATETIME;
    DECLARE my_expiry_date DATETIME;
    DECLARE my_start_date DATETIME;
    DECLARE my_drug_id INT;
    DECLARE my_daily_dose DECIMAL(6, 2);
    DECLARE my_quantity INT;
    DECLARE my_pill_count INT;

    DECLARE done INT DEFAULT FALSE;

    DECLARE cur1 CURSOR FOR
        SELECT
            d.drug_inventory_id,
            o.start_date,
            d.equivalent_daily_dose AS daily_dose,
            SUM(d.quantity) AS total_quantity,
            DATE(o.start_date) AS obs_date
        FROM
            drug_order d
            INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id AND d.site_id = my_site_id
            INNER JOIN orders o ON d.order_id = o.order_id AND d.quantity > 0 AND o.voided = 0 AND o.start_date <= my_end_date AND o.patient_id = my_patient_id AND o.site_id = d.site_id AND o.site_id = my_site_id
        GROUP BY
            d.drug_inventory_id,
            DATE(o.start_date),
            daily_dose;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    SELECT
        MAX(o.start_date)
    INTO
        my_obs_datetime
    FROM
        drug_order d
        INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id AND d.site_id = my_site_id
        INNER JOIN orders o ON d.order_id = o.order_id AND d.quantity > 0 AND o.voided = 0 AND o.start_date <= my_end_date AND o.patient_id = my_patient_id AND o.site_id = d.site_id AND o.site_id = my_site_id
    GROUP BY
        o.patient_id;

    OPEN cur1;

    read_loop: LOOP
        FETCH cur1 INTO my_drug_id, my_start_date, my_daily_dose, my_quantity, my_obs_datetime;

        IF done THEN
            CLOSE cur1;
            LEAVE read_loop;
        END IF;

        IF DATE(my_obs_datetime) = DATE(my_end_date) THEN
            IF my_daily_dose = 0 OR LENGTH(my_daily_dose) < 1 OR my_daily_dose IS NULL THEN
                SET my_daily_dose = 1;
            END IF;

            SET my_pill_count = drug_pill_count(my_patient_id, my_drug_id, my_obs_datetime);

            SET my_expiry_date = ADDDATE(DATE_SUB(my_start_date, INTERVAL 1 DAY), ((my_quantity + my_pill_count) / my_daily_dose));

            IF my_expiry_date IS NULL OR @expiry_date < my_expiry_date THEN
                SET my_expiry_date = @expiry_date;
            END IF;
        END IF;
    END LOOP;

    IF TIMESTAMPDIFF(DAY, my_expiry_date, my_end_date) >= 60 THEN
        SET flag = 1;
    END IF;

    RETURN flag;
END$$
DELIMITER ;


-- Current defaulter date
DROP FUNCTION IF EXISTS current_defaulter_date;

DELIMITER $$
CREATE FUNCTION current_defaulter_date(patient_id INT, site_id INT, visit_date DATE, my_site_id INT) RETURNS DATE
DETERMINISTIC
BEGIN
    DECLARE my_default_date DATE;

    DECLARE my_obs_datetime DATETIME;
    DECLARE my_expiry_date DATETIME;
    DECLARE my_start_date DATETIME;
    DECLARE my_drug_id INT;
    DECLARE my_daily_dose DECIMAL(6, 2);
    DECLARE my_quantity INT;
    DECLARE my_pill_count INT;

    DECLARE done INT DEFAULT FALSE;

    DECLARE cur1 CURSOR FOR
        SELECT
            d.drug_inventory_id,
            o.start_date,
            d.equivalent_daily_dose AS daily_dose,
            SUM(d.quantity) AS total_quantity,
            DATE(o.start_date) AS obs_date
        FROM
            drug_order d
            INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id AND d.site_id = my_site_id
            INNER JOIN orders o ON d.order_id = o.order_id AND d.quantity > 0 AND o.voided = 0 AND o.start_date <= my_end_date AND o.patient_id = my_patient_id AND o.site_id = d.site_id AND o.site_id = my_site_id
        GROUP BY
            d.drug_inventory_id,
            DATE(o.start_date),
            daily_dose;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    SELECT
        MAX(o.start_date)
    INTO
        my_obs_datetime
    FROM
        drug_order d
        INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id AND d.site_id = my_site_id
        INNER JOIN orders o ON d.order_id = o.order_id AND d.quantity > 0 AND o.voided = 0 AND o.start_date <= my_end_date AND o.patient_id = my_patient_id AND o.site_id = d.site_id AND o.site_id = my_site_id
    GROUP BY
        o.patient_id;

    OPEN cur1;

    read_loop: LOOP
        FETCH cur1 INTO my_drug_id, my_start_date, my_daily_dose, my_quantity, my_obs_datetime;

        IF done THEN
            CLOSE cur1;
            LEAVE read_loop;
        END IF;

        IF DATE(my_obs_datetime) = DATE(my_end_date) THEN
            IF my_daily_dose = 0 OR LENGTH(my_daily_dose) < 1 OR my_daily_dose IS NULL THEN
                SET my_daily_dose = 1;
            END IF;

            SET my_pill_count = drug_pill_count(my_patient_id, my_drug_id, my_obs_datetime);

            SET my_expiry_date = ADDDATE(DATE_SUB(my_start_date, INTERVAL 1 DAY), ((my_quantity + my_pill_count) / my_daily_dose));

            IF my_expiry_date IS NULL OR my_expiry_date < my_end_date THEN
                SET my_expiry_date = my_end_date;
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
CREATE FUNCTION current_pepfar_defaulter(my_patient_id INT, site_id INT, my_end_date DATE, my_site_id INT) RETURNS VARCHAR(45)
DETERMINISTIC
BEGIN
    DECLARE flag INT DEFAULT 0;

    DECLARE my_obs_datetime DATETIME;
    DECLARE my_expiry_date DATETIME;
    DECLARE my_start_date DATETIME;
    DECLARE my_drug_id INT;
    DECLARE my_daily_dose DECIMAL(6, 2);
    DECLARE my_quantity INT;
    DECLARE my_pill_count INT;

    DECLARE done INT DEFAULT FALSE;

    DECLARE cur1 CURSOR FOR
        SELECT
            d.drug_inventory_id,
            o.start_date,
            d.equivalent_daily_dose AS daily_dose,
            SUM(d.quantity) AS total_quantity,
            DATE(o.start_date) AS obs_date
        FROM
            drug_order d
            INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id AND d.site_id = my_site_id
            INNER JOIN orders o ON d.order_id = o.order_id AND d.quantity > 0 AND o.voided = 0 AND o.start_date <= my_end_date AND o.patient_id = my_patient_id AND o.site_id = d.site_id AND o.site_id = my_site_id
        GROUP BY
            d.drug_inventory_id,
            DATE(o.start_date),
            daily_dose;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    SELECT
        MAX(o.start_date)
    INTO
        my_obs_datetime
    FROM
        drug_order d
        INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id AND d.site_id = my_site_id
        INNER JOIN orders o ON d.order_id = o.order_id AND d.quantity > 0 AND o.voided = 0 AND o.start_date <= my_end_date AND o.patient_id = my_patient_id AND o.site_id = d.site_id AND o.site_id = my_site_id
    GROUP BY
        o.patient_id;

    OPEN cur1;

    read_loop: LOOP
        FETCH cur1 INTO my_drug_id, my_start_date, my_daily_dose, my_quantity, my_obs_datetime;

        IF done THEN
            CLOSE cur1;
            LEAVE read_loop;
        END IF;

        IF DATE(my_obs_datetime) = DATE(my_end_date) THEN
            IF my_daily_dose = 0 OR LENGTH(my_daily_dose) < 1 OR my_daily_dose IS NULL THEN
                SET my_daily_dose = 1;
            END IF;

            SET my_pill_count = drug_pill_count(my_patient_id, my_drug_id, my_obs_datetime);

            SET my_expiry_date = ADDDATE(DATE_SUB(my_start_date, INTERVAL 1 DAY), ((my_quantity + my_pill_count) / my_daily_dose));

            IF my_expiry_date IS NULL OR @expiry_date < my_expiry_date THEN
                SET my_expiry_date = @expiry_date;
            END IF;
        END IF;
    END LOOP;

    IF TIMESTAMPDIFF(DAY, my_expiry_date, my_end_date) >= 30 THEN
        SET flag = 1;
    END IF;

    RETURN flag;
END$$
DELIMITER ;


-- Current defaulter date
DROP FUNCTION IF EXISTS current_pepfar_defaulter_date;

DELIMITER $$
CREATE FUNCTION current_pepfar_defaulter_date(patient_id INT, site_id INT, visit_date DATE, my_site_id INT) RETURNS DATE
DETERMINISTIC
BEGIN
    DECLARE my_default_date DATE;

    DECLARE my_obs_datetime DATETIME;
    DECLARE my_expiry_date DATETIME;
    DECLARE my_start_date DATETIME;
    DECLARE my_drug_id INT;
    DECLARE my_daily_dose DECIMAL(6, 2);
    DECLARE my_quantity INT;
    DECLARE my_pill_count INT;

    DECLARE done INT DEFAULT FALSE;

    DECLARE cur1 CURSOR FOR
        SELECT
            d.drug_inventory_id,
            o.start_date,
            d.equivalent_daily_dose AS daily_dose,
            SUM(d.quantity) AS total_quantity,
            DATE(o.start_date) AS obs_date
        FROM
            drug_order d
            INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id AND d.site_id = my_site_id
            INNER JOIN orders o ON d.order_id = o.order_id AND d.quantity > 0 AND o.voided = 0 AND o.start_date <= my_end_date AND o.patient_id = my_patient_id AND o.site_id = d.site_id AND o.site_id = my_site_id
        GROUP BY
            d.drug_inventory_id,
            DATE(o.start_date),
            daily_dose;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    SELECT
        MAX(o.start_date)
    INTO
        my_obs_datetime
    FROM
        drug_order d
        INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id AND d.site_id = my_site_id
        INNER JOIN orders o ON d.order_id = o.order_id AND d.quantity > 0 AND o.voided = 0 AND o.start_date <= my_end_date AND o.patient_id = my_patient_id AND o.site_id = d.site_id AND o.site_id = my_site_id
    GROUP BY
        o.patient_id;

    OPEN cur1;

    read_loop: LOOP
        FETCH cur1 INTO my_drug_id, my_start_date, my_daily_dose, my_quantity, my_obs_datetime;

        IF done THEN
            CLOSE cur1;
            LEAVE read_loop;
        END IF;

        IF DATE(my_obs_datetime) = DATE(my_end_date) THEN
            IF my_daily_dose = 0 OR LENGTH(my_daily_dose) < 1 OR my_daily_dose IS NULL THEN
                SET my_daily_dose = 1;
            END IF;

            SET my_pill_count = drug_pill_count(my_patient_id, my_drug_id, my_obs_datetime);

            SET my_expiry_date = ADDDATE(DATE_SUB(my_start_date, INTERVAL 1 DAY), ((my_quantity + my_pill_count) / my_daily_dose));

            IF my_expiry_date IS NULL OR my_expiry_date < my_end_date THEN
                SET my_expiry_date = my_end_date;
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
    DECLARE estimated_art_date_months VARCHAR(45);

    -- Get the initial start date from observations
    SET date_started = (SELECT LEFT(value_datetime, 10) 
                        FROM obs 
                        WHERE concept_id = 2516 
                            AND encounter_id > 0 
                            AND person_id = set_patient_id 
                            AND voided = 0 
														AND site_id = my_site_id
                        LIMIT 1);

    -- If initial start date is null, calculate based on estimated ART duration
    IF date_started IS NULL THEN
        SET estimated_art_date_months = (SELECT value_text 
                                         FROM obs 
                                         WHERE encounter_id > 0 
                                             AND concept_id = 2516 
                                             AND person_id = set_patient_id 
                                             AND voided = 0 
																						 AND site_id = my_site_id
                                         LIMIT 1);
        SET min_state_date = (SELECT obs_datetime 
                              FROM obs 
                              WHERE encounter_id > 0 
                                  AND concept_id = 2516 
                                  AND person_id = set_patient_id 
                                  AND voided = 0 
																	AND site_id = my_site_id
                              LIMIT 1);

        -- Calculate start date based on estimated ART duration
        CASE estimated_art_date_months
            WHEN "6 months" THEN SET date_started = DATE_SUB(min_state_date, INTERVAL 6 MONTH);
            WHEN "12 months" THEN SET date_started = DATE_SUB(min_state_date, INTERVAL 12 MONTH);
            WHEN "18 months" THEN SET date_started = DATE_SUB(min_state_date, INTERVAL 18 MONTH);
            WHEN "24 months" THEN SET date_started = DATE_SUB(min_state_date, INTERVAL 24 MONTH);
            WHEN "48 months" THEN SET date_started = DATE_SUB(min_state_date, INTERVAL 48 MONTH);
            WHEN "Over 2 years" THEN SET date_started = DATE_SUB(min_state_date, INTERVAL 60 MONTH);
            ELSE SET date_started = patient_start_date(set_patient_id);
        END CASE;
    END IF;

    RETURN date_started;
END$$
DELIMITER ;



-- Died In
DROP FUNCTION IF EXISTS died_in;

DELIMITER $$
CREATE FUNCTION died_in(set_patient_id INT, my_end_date DATE, my_site_id INT) RETURNS VARCHAR(45)
DETERMINISTIC
BEGIN
    DECLARE set_outcome VARCHAR(25) DEFAULT 'N/A';
    DECLARE date_of_death DATE;
    DECLARE num_of_days INT;

    IF set_status = 'Patient died' THEN
        SELECT COALESCE(death_date, outcome_date) INTO date_of_death
        FROM temp_patient_outcomes
        INNER JOIN temp_earliest_start_date USING (patient_id, site_id)
        WHERE cum_outcome = 'Patient died' AND patient_id = set_patient_id AND site_id = my_site_id;

        IF date_of_death IS NULL THEN
            RETURN 'Unknown';
        END IF;

        SET num_of_days = TIMESTAMPDIFF(day, date(date_enrolled), date(date_of_death));

        CASE 
            WHEN num_of_days <= 30 THEN SET set_outcome = '1st month';
            WHEN num_of_days <= 60 THEN SET set_outcome = '2nd month';
            WHEN num_of_days <= 91 THEN SET set_outcome = '3rd month';
            WHEN num_of_days > 91 THEN SET set_outcome = '4+ months';
            ELSE SET set_outcome = 'Unknown';
        END CASE;
    END IF;

    RETURN set_outcome;
END$$
DELIMITER ;


-- Disaggregated age group
DROP FUNCTION IF EXISTS disaggregated_age_group;

DELIMITER $$
CREATE FUNCTION disaggregated_age_group(birthdate DATE, end_date DATE) RETURNS VARCHAR(15)
DETERMINISTIC
BEGIN
    DECLARE age_in_months INT;
    DECLARE age_group VARCHAR(15);

    SET age_in_months = TIMESTAMPDIFF(MONTH, birthdate, end_date);
    SET age_group = 'Unknown';

    IF age_in_months < 12 THEN
        SET age_group = '<1 year';
    ELSE
        SET age_group = CONCAT(
            FLOOR(age_in_months / 12), '-',
            FLOOR((age_in_months - 12) / 5) * 5 + 1, '-', 
            FLOOR((age_in_months - 12) / 5) * 5 + 5, ' years'
        );
    END IF;

    RETURN age_group;
END$$
DELIMITER ;


-- Drug pill count
DROP FUNCTION IF EXISTS drug_pill_count;

DELIMITER $$
CREATE FUNCTION drug_pill_count(set_patient_id INT, set_drug_id INT, set_obs_datetime DATETIME, my_site_id INT) RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE my_pill_count INT DEFAULT 0;

    SELECT
        COALESCE(SUM(CASE
                WHEN ob.value_text IS NOT NULL THEN CAST(ob.value_text AS DECIMAL)
                ELSE 0
            END) + SUM(COALESCE(ob.value_numeric, 0)), 0)
    INTO
        my_pill_count
    FROM
        obs ob
        INNER JOIN drug_order do ON ob.order_id = do.order_id AND ob.site_id = my_site_id
        INNER JOIN orders o ON do.order_id = o.order_id AND o.site_id = my_site_id
    WHERE
        ob.person_id = set_patient_id
        AND ob.concept_id = 2540
        AND ob.voided = 0
        AND o.voided = 0
        AND do.drug_inventory_id = set_drug_id
        AND DATE(ob.obs_datetime) = DATE(set_obs_datetime);

    RETURN my_pill_count;
END$$
DELIMITER ;


-- Female maternal status
DROP FUNCTION IF EXISTS female_maternal_status;
DELIMITER $$
CREATE FUNCTION female_maternal_status(my_patient_id INT, end_datetime DATETIME, my_site_id INT) RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE maternal_status VARCHAR(20);

    SET maternal_status = (
        SELECT
            CASE
                WHEN pregnant_date IS NULL AND breastfeeding_date IS NULL THEN 'FNP'
                WHEN pregnant_date IS NOT NULL AND breastfeeding_date IS NOT NULL THEN 'Unknown'
                WHEN pregnant_date IS NULL AND breastfeeding_date IS NOT NULL THEN 'Check BF'
                WHEN pregnant_date IS NOT NULL AND breastfeeding_date IS NULL THEN 'Check FP'
            END
        FROM (
            SELECT
                (
                    SELECT MAX(COALESCE(obs_datetime, '0000-00-00'))
                    FROM obs
                    WHERE concept_id IN (
                            SELECT GROUP_CONCAT(concept_id)
                            FROM concept_name
                            WHERE name IN ('Is patient pregnant?', 'Patient pregnant')
                        )
                        AND voided = 0
                        AND person_id = my_patient_id
                        AND obs_datetime <= end_datetime
												AND site_id = my_site_id
                ) AS pregnant_date,
                (
                    SELECT MAX(COALESCE(obs_datetime, '0000-00-00'))
                    FROM obs
                    WHERE concept_id = (
                            SELECT concept_id
                            FROM concept_name
                            WHERE name = 'Breastfeeding'
                        )
                        AND voided = 0
                        AND person_id = my_patient_id
                        AND obs_datetime <= end_datetime
												AND site_id = my_site_id
                ) AS breastfeeding_date
        ) AS dates
    );

    IF maternal_status = 'Unknown' THEN
        IF breastfeeding_date <= pregnant_date THEN
            SET maternal_status = (
                SELECT
                    CASE
                        WHEN value_coded = 1065 THEN 'FP'
                        ELSE 'FNP'
                    END
                FROM obs
                WHERE concept_id IN (
                        SELECT GROUP_CONCAT(concept_id)
                        FROM concept_name
                        WHERE name IN ('Is patient pregnant?', 'Patient pregnant')
                    )
                    AND voided = 0
                    AND person_id = my_patient_id
                    AND obs_datetime = pregnant_date
										AND site_id = my_site_id
                LIMIT 1
            );
        ELSE
            SET maternal_status = (
                SELECT
                    CASE
                        WHEN value_coded = 1065 THEN 'FBf'
                        ELSE 'FNP'
                    END
                FROM obs
                WHERE concept_id = (
                        SELECT concept_id
                        FROM concept_name
                        WHERE name = 'Breastfeeding'
                    )
                    AND voided = 0
                    AND person_id = my_patient_id
                    AND obs_datetime = breastfeeding_date
										AND site_id = my_site_id
                LIMIT 1
            );
        END IF;

        IF DATE(breastfeeding_date) = DATE(pregnant_date) AND maternal_status = 'FNP' THEN
            SET maternal_status = (
                SELECT
                    CASE
                        WHEN value_coded = 1065 THEN 'FBf'
                        ELSE 'FNP'
                    END
                FROM obs
                WHERE concept_id = (
                        SELECT concept_id
                        FROM concept_name
                        WHERE name = 'Breastfeeding'
                    )
                    AND voided = 0
                    AND person_id = my_patient_id
                    AND obs_datetime = breastfeeding_date
										AND site_id = my_site_id
                LIMIT 1
            );
        END IF;
    END IF;

    IF maternal_status IN ('Check FP', 'Check BF') THEN
        SET maternal_status = (
            SELECT
                CASE
                    WHEN value_coded = 1065 THEN 'FP'
                    ELSE 'FNP'
                END
            FROM obs
            WHERE concept_id IN (
                    SELECT GROUP_CONCAT(concept_id)
                    FROM concept_name
                    WHERE name IN ('Is patient pregnant?', 'Patient pregnant')
                )
                AND voided = 0
                AND person_id = my_patient_id
                AND obs_datetime = pregnant_date
								AND site_id = my_site_id
            LIMIT 1
        );

        IF maternal_status = 'FNP' THEN
            SET maternal_status = (
                SELECT
                    CASE
                        WHEN value_coded IN (1755, 834, 5632) THEN 'FBf'
                        ELSE 'FNP'
                    END
                FROM obs
                WHERE concept_id IN (7563)
                    AND voided = 0
                    AND person_id = my_patient_id
                    AND obs_datetime = pregnant_date
										AND site_id = my_site_id
                LIMIT 1
            );
        END IF;
    END IF;

    RETURN maternal_status;
END$$
DELIMITER ;


-- Patient current regimen
DROP FUNCTION IF EXISTS patient_current_regimen;

DELIMITER $$
CREATE FUNCTION patient_current_regimen(set_patient_id INT, my_end_date DATE, my_site_id INT) RETURNS VARCHAR(255)
DETERMINISTIC
BEGIN
    DECLARE max_obs_datetime DATETIME;
    DECLARE regimen VARCHAR(255) DEFAULT 'N/A';

    SELECT MAX(orders.start_date)
    INTO max_obs_datetime
    FROM orders
    INNER JOIN drug_order ON drug_order.order_id = orders.order_id
    INNER JOIN arv_drug ON drug_order.drug_inventory_id = arv_drug.drug_id
    WHERE orders.patient_id = set_patient_id
    AND orders.voided = 0
    AND drug_order.quantity > 0
    AND DATE(orders.start_date) <= my_end_date
    AND orders.site_id = my_site_id 
    AND drug_order.site_id = my_site_id 
    AND drug_order.site_id = orders.site_id;

    SELECT GROUP_CONCAT(DISTINCT arv_drug.drug_id ORDER BY arv_drug.drug_id ASC)
    INTO @drug_ids
    FROM drug_order
    INNER JOIN arv_drug ON drug_order.drug_inventory_id = arv_drug.drug_id
    INNER JOIN orders ON drug_order.order_id = orders.order_id 
    INNER JOIN encounter ON encounter.encounter_id = orders.encounter_id
    WHERE orders.voided = 0
    AND DATE(orders.start_date) = DATE(max_obs_datetime)
    AND drug_order.quantity > 0
    AND orders.site_id = my_site_id 
    AND encounter.patient_id = set_patient_id
    AND encounter.voided = 0
    AND encounter.encounter_type = 25
    AND encounter.site_id = my_site_id;

    SELECT DISTINCT regimen_name.name INTO regimen
    FROM moh_regimen_combination AS combo
    INNER JOIN moh_regimen_combination_drug AS drug ON combo.regimen_combination_id = drug.regimen_combination_id
    INNER JOIN moh_regimen_name AS regimen_name ON combo.regimen_name_id = regimen_name.regimen_name_id
    WHERE FIND_IN_SET(drug.drug_id, @drug_ids)
    LIMIT 1;

    RETURN COALESCE(regimen, 'N/A');
END$$
DELIMITER ;


-- Patient date enrolled
DROP FUNCTION IF EXISTS patient_date_enrolled;

DELIMITER $$
CREATE FUNCTION patient_date_enrolled(set_patient_id INT, my_site_id INT) RETURNS DATE
DETERMINISTIC
BEGIN
    DECLARE my_start_date DATE;
    DECLARE arv_concept_id INT;

    SELECT MIN(DATE(orders.start_date))
    INTO my_start_date
    FROM orders
    INNER JOIN drug_order ON drug_order.order_id = orders.order_id
    INNER JOIN drug ON drug.drug_id = drug_order.drug_inventory_id
    WHERE orders.patient_id = set_patient_id
    AND orders.voided = 0
    AND drug.concept_id IN (SELECT concept_id FROM concept_set WHERE concept_set IN (SELECT concept_id FROM concept_name WHERE name = 'ANTIRETROVIRAL DRUGS'))
    AND drug_order.quantity > 0
    AND orders.site_id = my_site_id 
    AND drug_order.site_id = my_site_id;

    RETURN my_start_date;
END$$
DELIMITER ;

-- Patient given IPT
DROP FUNCTION IF EXISTS patient_given_ipt;

DELIMITER $$
CREATE FUNCTION patient_given_ipt(set_patient_id INT, my_end_date DATE, my_site_id INT) RETURNS INT(11)
DETERMINISTIC
BEGIN
    DECLARE given INT DEFAULT FALSE;

    SELECT COUNT(*) INTO given
    FROM drug_order d
    INNER JOIN orders o ON o.order_id = d.order_id
    WHERE d.drug_inventory_id IN (
            SELECT drug_id
            FROM drug
            WHERE concept_id IN (
                    SELECT concept_id
                    FROM concept_name
                    WHERE name IN ('Isoniazid')
                )
        )
        AND d.quantity > 0
        AND o.start_date = (
            SELECT MAX(start_date)
            FROM orders t
            WHERE t.patient_id = o.patient_id
                AND t.start_date BETWEEN my_start_date AND my_end_date
                AND t.patient_id = set_patient_id
        )
        AND o.site_id = my_site_id
        AND d.site_id = my_site_id;

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
    DECLARE side_effect VARCHAR(7);

    SET mw_side_effects_concept_id = (
        SELECT concept_id
        FROM concept_name
        WHERE name = 'Malawi ART Side Effects' AND voided = 0
        LIMIT 1
    );

    SET yes_concept_id = (
        SELECT concept_id
        FROM concept_name
        WHERE name = 'YES'
        LIMIT 1
    );

    SET no_concept_id = (
        SELECT concept_id
        FROM concept_name
        WHERE name = 'NO'
        LIMIT 1
    );

    SET side_effect = (
        SELECT IFNULL(
            (SELECT 'Yes' 
            FROM obs 
            INNER JOIN temp_earliest_start_date e ON e.patient_id = obs.person_id 
                AND obs.site_id = e.site_id AND obs.site_id = my_site_id
            WHERE obs_group_id IN (
                    SELECT obs_id 
                    FROM obs 
                    WHERE concept_id = mw_side_effects_concept_id 
                        AND person_id = my_patient_id 
                        AND obs.obs_datetime BETWEEN DATE_FORMAT(DATE(MAX(obs_datetime)), '%Y-%m-%d 00:00:00') 
                            AND DATE_FORMAT(DATE(MAX(obs_datetime)), '%Y-%m-%d 23:59:59') 
                        AND DATE(obs_datetime) != DATE(e.date_enrolled)
                ) 
                AND concept_id = mw_side_effects_concept_id
                AND value_coded = yes_concept_id
            GROUP BY concept_id 
            LIMIT 1), 
            'No'
        )
    );

    RETURN side_effect;
END$$
DELIMITER ;

-- Patient outcome
DROP FUNCTION IF EXISTS patient_outcome;

DELIMITER $$
CREATE FUNCTION patient_outcome(set_patient_id INT, my_end_date DATE, my_site_id INT) RETURNS VARCHAR(45)
DETERMINISTIC
BEGIN
    DECLARE set_program_id INT;
    DECLARE set_outcome VARCHAR(45);
    DECLARE set_timestamp DATETIME;

    -- Set the timestamp to the end of the specified date
    SET set_timestamp = CONCAT(DATE(my_end_date), ' 23:59:59');

    -- Get the program ID for the HIV program
    SET set_program_id = (SELECT program_id FROM program WHERE name = "HIV PROGRAM" LIMIT 1);

    -- Initialize the outcome variable
    SET set_outcome = 'Unknown';

    -- Retrieve the patient state and outcome
    SELECT 
        COALESCE(
            CASE
                WHEN ps.state = 1 THEN
                    CASE
                        WHEN current_defaulter(set_patient_id, set_timestamp, my_site_id) = 1 THEN 'Defaulted'
                        ELSE 'Pre-ART (Continue)'
                    END
                WHEN ps.state = 2 THEN 'Patient transferred out'
                WHEN ps.state = 3 OR ps.state = 127 THEN 'Patient died'
                WHEN ps.state != 3 AND ps.state != 127 THEN
                    CASE
                        WHEN EXISTS (
                            SELECT 1
                            FROM patient_state ps2
                            INNER JOIN patient_program pp ON pp.patient_program_id = ps2.patient_program_id 
                                AND pp.program_id = set_program_id AND pp.site_id = my_site_id
                            WHERE ps2.state = 3 AND ps2.voided = 0 AND pp.voided = 0 
                                AND DATE(ps2.start_date) <= my_end_date 
                                AND pp.patient_id = set_patient_id
                        ) THEN 'Patient died'
                    END
                WHEN ps.state = 6 THEN 'Treatment stopped'
                ELSE
                    CASE
                        WHEN current_defaulter(set_patient_id, set_timestamp, my_site_id) = 1 THEN 'Defaulted'
                        WHEN dq.dispensed_quantity > 0 THEN 'On antiretrovirals'
                        ELSE 'Unknown'
                    END
            END,
            'Unknown'
        ) INTO set_outcome
    FROM patient_state ps
    INNER JOIN patient_program pp ON pp.patient_program_id = ps.patient_program_id 
        AND pp.program_id = set_program_id AND pp.site_id = my_site_id
    LEFT JOIN (
        SELECT 
            MAX(d.quantity) AS dispensed_quantity,
            o.patient_id
        FROM orders o
        INNER JOIN drug_order d ON d.order_id = o.order_id
            AND o.site_id = my_site_id AND d.site_id = my_site_id
            AND d.drug_inventory_id IN (
                SELECT DISTINCT drug_id 
                FROM drug 
                WHERE concept_id IN (
                    SELECT concept_id 
                    FROM concept_set 
                    WHERE concept_set = 1085
                )
            ) 
        WHERE o.voided = 0
            AND DATE(o.start_date) <= my_end_date 
            AND d.quantity > 0 
        GROUP BY o.patient_id
    ) AS dq ON dq.patient_id = set_patient_id
    WHERE ps.voided = 0 
        AND pp.voided = 0 
        AND DATE(ps.start_date) <= my_end_date 
        AND pp.patient_id = set_patient_id
    ORDER BY ps.start_date DESC
    LIMIT 1; -- Limit to one row

    -- Return the outcome
    RETURN set_outcome;
END$$
DELIMITER ;



-- patient reason for starting ART
DROP FUNCTION IF EXISTS patient_reason_for_starting_art;

DELIMITER $$
CREATE FUNCTION patient_reason_for_starting_art(set_patient_id INT, my_site_id INT) RETURNS INT(11)
DETERMINISTIC
BEGIN
    DECLARE reason_concept_id INT;
    DECLARE coded_concept_id INT;

    SELECT 
        COALESCE(
            (
                SELECT value_coded 
                FROM obs 
                WHERE person_id = set_patient_id 
                    AND concept_id = (
                        SELECT concept_id 
                        FROM concept_name 
                        WHERE name = 'Reason for ART eligibility' 
                            AND voided = 0 
                            LIMIT 1
                    ) 
                    AND voided = 0 
                    AND site_id = my_site_id
                    AND obs_datetime = (
                        SELECT MAX(obs_datetime) 
                        FROM obs 
                        WHERE person_id = set_patient_id 
                            AND concept_id = (
                                SELECT concept_id 
                                FROM concept_name 
                                WHERE name = 'Reason for ART eligibility' 
                                    AND voided = 0 
                                    LIMIT 1
                            ) 
                            AND voided = 0 
                            AND site_id = my_site_id
                    )
                LIMIT 1
            ),
            0
        ) INTO coded_concept_id;

    RETURN coded_concept_id;
END$$
DELIMITER ;


-- patient reason for starting ART text
DROP FUNCTION IF EXISTS patient_reason_for_starting_art_text;

DELIMITER $$
CREATE FUNCTION patient_reason_for_starting_art_text(set_patient_id INT, my_site_id INT) RETURNS VARCHAR(255)
DETERMINISTIC
BEGIN
    DECLARE reason_concept_id INT;
    DECLARE coded_concept_id INT;
    DECLARE reason_text VARCHAR(255);

    SELECT 
        COALESCE(
            (
                SELECT value_coded 
                FROM obs 
                WHERE person_id = set_patient_id 
                    AND concept_id = (
                        SELECT concept_id 
                        FROM concept_name 
                        WHERE name = 'Reason for ART eligibility' 
                            AND voided = 0 
                            LIMIT 1
                    ) 
                    AND voided = 0 
                    AND site_id = my_site_id
                    AND obs_datetime = (
                        SELECT MAX(obs_datetime) 
                        FROM obs 
                        WHERE person_id = set_patient_id 
                            AND concept_id = (
                                SELECT concept_id 
                                FROM concept_name 
                                WHERE name = 'Reason for ART eligibility' 
                                    AND voided = 0 
                                    LIMIT 1
                            ) 
                            AND voided = 0 
                            AND site_id = my_site_id
                    )
                LIMIT 1
            ),
            0
        ) INTO coded_concept_id;

    SELECT 
        COALESCE(
            (
                SELECT name 
                FROM concept_name 
                WHERE concept_id = coded_concept_id 
                    AND name != '' 
                    AND name IS NOT NULL 
                    LIMIT 1
            ),
            'Unknown'
        ) INTO reason_text;

    RETURN reason_text;
END$$
DELIMITER ;

-- Patient screened for TB
DROP FUNCTION IF EXISTS patient_screened_for_tb;

DELIMITER $$
CREATE FUNCTION patient_screened_for_tb(my_patient_id INT, my_start_date DATE, my_end_date DATE, my_site_id INT) RETURNS int(11)
BEGIN
    DECLARE screened INT DEFAULT FALSE;
    DECLARE record_value INT;

    SELECT 
        COALESCE(
            (
                SELECT ob.person_id 
                FROM obs ob
                INNER JOIN temp_earliest_start_date e
                ON e.patient_id = ob.person_id
                AND e.site_id = my_site_id 
                AND ob.site_id = my_site_id
                WHERE ob.concept_id IN (
                    SELECT GROUP_CONCAT(DISTINCT(concept_id) ORDER BY concept_id ASC) 
                    FROM concept_name
                    WHERE name IN ('TB treatment','TB status') 
                    AND voided = 0
                ) 
                AND ob.voided = 0
                AND ob.obs_datetime = (
                    SELECT MAX(t.obs_datetime) 
                    FROM obs t 
                    WHERE t.obs_datetime BETWEEN DATE_FORMAT(DATE(my_start_date), '%Y-%m-%d 00:00:00') 
                    AND DATE_FORMAT(DATE(my_end_date), '%Y-%m-%d 23:59:59') 
                    AND t.person_id = ob.person_id 
                    AND ob.site_id = my_site_id 
                    AND t.concept_id IN (
                        SELECT GROUP_CONCAT(DISTINCT(concept_id) ORDER BY concept_id ASC) 
                        FROM concept_name 
                        WHERE name IN ('TB treatment','TB status') 
                        AND voided = 0
                    )
                ) 
                AND ob.person_id = my_patient_id 
                GROUP BY ob.person_id
            ),
            0
        ) INTO record_value;

    IF record_value IS NOT NULL THEN
        SET screened = TRUE;
    END IF;

    RETURN screened;
END$$

DELIMITER ;


-- Patient start date
DROP FUNCTION IF EXISTS patient_start_date;

DELIMITER $$
CREATE FUNCTION patient_start_date(set_patient_id INT, my_site_id INT) RETURNS DATE
DETERMINISTIC
BEGIN
    DECLARE start_date DATE;

    SELECT 
        MIN(DATE(obs_datetime)) 
    INTO 
        start_date
    FROM 
        obs 
    WHERE 
        voided = 0 
        AND person_id = set_patient_id 
        AND concept_id = (
            SELECT 
                concept_id 
            FROM 
                concept_name 
            WHERE 
                name = 'AMOUNT DISPENSED'
        ) 
        AND site_id = my_site_id 
        AND value_drug IN (
            SELECT 
                drug_id 
            FROM 
                drug d 
                INNER JOIN concept_set cs ON d.concept_id = cs.concept_id 
            WHERE 
                cs.concept_set = (
                    SELECT 
                        concept_id 
                    FROM 
                        concept_name 
                    WHERE 
                        name = 'ANTIRETROVIRAL DRUGS'
                )
        );

    RETURN start_date;
END$$

DELIMITER ;


-- Patient TB status
DROP FUNCTION IF EXISTS patient_tb_status;

DELIMITER $$
CREATE FUNCTION patient_tb_status(my_patient_id INT, my_end_date DATE, my_site_id INT) RETURNS INT(11)
DETERMINISTIC
BEGIN
    DECLARE tb_status INT;

    SELECT 
        COALESCE(
            (
                SELECT 
                    ob.value_coded 
                FROM 
                    obs ob
                    INNER JOIN concept_name cn ON ob.value_coded = cn.concept_id AND ob.site_id = my_site_id
                WHERE 
                    ob.concept_id = (
                        SELECT 
                            concept_id 
                        FROM 
                            concept_name 
                        WHERE 
                            name = 'TB status' AND voided = 0
                        LIMIT 1
                    ) 
                    AND ob.voided = 0 
                    AND ob.obs_datetime = (
                        SELECT 
                            MAX(t.obs_datetime) 
                        FROM 
                            obs t 
                        WHERE 
                            t.obs_datetime <= DATE_FORMAT(DATE(my_end_date), '%Y-%m-%d 23:59:59') 
                            AND t.voided = 0 
                            AND t.person_id = ob.person_id 
                            AND t.concept_id = ob.concept_id
                    )
                    AND ob.person_id = my_patient_id 
                    AND ob.site_id = my_site_id
                GROUP BY 
                    ob.person_id
                LIMIT 1
            ),
            0
        ) INTO tb_status;

    RETURN tb_status;
END$$

DELIMITER ;

-- Patient WHO stage
DROP FUNCTION IF EXISTS patient_who_stage;

DELIMITER $$
CREATE FUNCTION patient_who_stage(my_patient_id INT, my_site_id INT) RETURNS VARCHAR(50)
DETERMINISTIC
BEGIN
    DECLARE who_stage VARCHAR(50);

    SELECT 
        COALESCE(
            (
                SELECT 
                    cn.name 
                FROM 
                    obs o
                    INNER JOIN concept_name cn ON o.value_coded = cn.concept_id
                WHERE 
                    o.person_id = my_patient_id 
                    AND o.concept_id = (
                        SELECT 
                            concept_id 
                        FROM 
                            concept_name 
                        WHERE 
                            name = 'WHO stage' AND voided = 0 
                        LIMIT 1
                    ) 
                    AND o.voided = 0 
                    AND o.site_id = my_site_id
                    AND o.obs_datetime = (
                        SELECT 
                            MAX(t.obs_datetime) 
                        FROM 
                            obs t 
                        WHERE 
                            t.person_id = my_patient_id 
                            AND t.concept_id = (
                                SELECT 
                                    concept_id 
                                FROM 
                                    concept_name 
                                WHERE 
                                    name = 'WHO stage' AND voided = 0 
                                LIMIT 1
                            ) 
                            AND t.voided = 0 
                            AND t.site_id = my_site_id
                    )
                LIMIT 1
            ),
            'Unknown'
        ) INTO who_stage;

    RETURN who_stage;
END$$

DELIMITER ;


-- PEPFAR patient outcome
DROP FUNCTION IF EXISTS pepfar_patient_outcome;

DELIMITER $$
CREATE FUNCTION pepfar_patient_outcome(set_patient_id INT, my_end_date DATE, my_site_id INT) RETURNS VARCHAR(45)
DETERMINISTIC
BEGIN
    DECLARE set_program_id INT;
    DECLARE set_outcome VARCHAR(45);
    DECLARE set_timestamp DATETIME;

    -- Set the timestamp to the end of the specified date
    SET set_timestamp = CONCAT(DATE(my_end_date), ' 23:59:59');

    -- Get the program ID for the HIV program
    SET set_program_id = (SELECT program_id FROM program WHERE name = "HIV PROGRAM" LIMIT 1);

    -- Initialize the outcome variable
    SET set_outcome = 'Unknown';

    -- Retrieve the patient state and outcome
    SELECT 
        COALESCE(
            CASE
                WHEN ps.state = 1 THEN
                    CASE
                        WHEN current_pepfar_defaulter(set_patient_id, set_timestamp, my_site_id) = 1 THEN 'Defaulted'
                        ELSE 'Pre-ART (Continue)'
                    END
                WHEN ps.state = 2 THEN 'Patient transferred out'
                WHEN ps.state = 3 OR ps.state = 127 THEN 'Patient died'
                WHEN ps.state != 3 AND ps.state != 127 THEN
                    CASE
                        WHEN EXISTS (
                            SELECT 1
                            FROM patient_state ps2
                            INNER JOIN patient_program pp ON pp.patient_program_id = ps2.patient_program_id 
                                AND pp.program_id = set_program_id AND pp.site_id = my_site_id
                            WHERE ps2.state = 3 AND ps2.voided = 0 AND pp.voided = 0 
                                AND DATE(ps2.start_date) <= my_end_date 
                                AND pp.patient_id = set_patient_id
                        ) THEN 'Patient died'
                    END
                WHEN ps.state = 6 THEN 'Treatment stopped'
                ELSE
                    CASE
                        WHEN current_pepfar_defaulter(set_patient_id, set_timestamp, my_site_id) = 1 THEN 'Defaulted'
                        WHEN dq.dispensed_quantity > 0 THEN 'On antiretrovirals'
                        ELSE 'Unknown'
                    END
            END,
            'Unknown'
        ) INTO set_outcome
    FROM patient_state ps
    INNER JOIN patient_program pp ON pp.patient_program_id = ps.patient_program_id 
        AND pp.program_id = set_program_id AND pp.site_id = my_site_id
    LEFT JOIN (
        SELECT 
            MAX(d.quantity) AS dispensed_quantity,
            o.patient_id
        FROM orders o
        INNER JOIN drug_order d ON d.order_id = o.order_id
            AND o.site_id = my_site_id AND d.site_id = my_site_id
            AND d.drug_inventory_id IN (
                SELECT DISTINCT drug_id 
                FROM drug 
                WHERE concept_id IN (
                    SELECT concept_id 
                    FROM concept_set 
                    WHERE concept_set = 1085
                )
            ) 
        WHERE o.voided = 0
            AND DATE(o.start_date) <= my_end_date 
            AND d.quantity > 0 
        GROUP BY o.patient_id
    ) AS dq ON dq.patient_id = set_patient_id
    WHERE ps.voided = 0 
        AND pp.voided = 0 
        AND DATE(ps.start_date) <= my_end_date 
        AND pp.patient_id = set_patient_id
    ORDER BY ps.start_date DESC
    LIMIT 1; -- Limit to one row

    -- Return the outcome
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

    DECLARE taken_arvs_concept INT;
    DECLARE yes_concept INT;
    DECLARE no_concept INT;
    DECLARE date_art_last_taken_concept INT;

    SET yes_concept = (SELECT concept_id FROM concept_name WHERE name ='YES' LIMIT 1);
    SET no_concept = (SELECT concept_id FROM concept_name WHERE name ='NO' LIMIT 1);
    SET date_art_last_taken_concept = (SELECT concept_id FROM concept_name WHERE name ='DATE ART LAST TAKEN' LIMIT 1);

    SET check_one = (
        SELECT COUNT(*)
        FROM clinic_registration_encounter e 
        INNER JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id 
            AND e.site_id = ero.site_id AND e.site_id = my_site_id
        INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.concept_id = date_art_last_taken_concept 
            AND o.voided = 0 AND o.site_id = my_site_id 
        WHERE 
            (o.concept_id = date_art_last_taken_concept AND TIMESTAMPDIFF(day, o.value_datetime, o.obs_datetime) > 14)
            AND patient_date_enrolled(e.patient_id, my_site_id) = set_date_enrolled 
            AND e.patient_id = set_patient_id
    );

    IF check_one >= 1 THEN
        SET re_initiated = 'Re-initiated';
    ELSE
        SET taken_arvs_concept = (SELECT concept_id FROM concept_name WHERE name ='HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS' LIMIT 1);
        SET check_two = (
            SELECT COUNT(*)
            FROM clinic_registration_encounter e 
            INNER JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id 
                AND e.site_id = ero.site_id AND e.site_id = my_site_id
            INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.concept_id = taken_arvs_concept 
                AND o.voided = 0 AND o.site_id = my_site_id
            WHERE  
                (o.concept_id = taken_arvs_concept AND o.value_coded = no_concept) 
                AND patient_date_enrolled(e.patient_id, my_site_id) = set_date_enrolled 
                AND e.patient_id = set_patient_id
        );
        
        IF check_two >= 1 THEN
            SET re_initiated = 'Re-initiated';
        END IF;
    END IF;

    RETURN re_initiated;
END$$

DELIMITER ;

DROP FUNCTION IF EXISTS died_in;

DELIMITER $$
CREATE FUNCTION `died_in`(set_patient_id INT, set_status VARCHAR(25), date_enrolled DATE, my_site_id INT) RETURNS varchar(25) CHARSET latin1
    DETERMINISTIC
BEGIN
DECLARE set_outcome varchar(25) default 'N/A';
DECLARE date_of_death DATE;
DECLARE num_of_days INT;

IF set_status = 'Patient died' THEN

  SET date_of_death = (
    SELECT COALESCE(death_date, outcome_date)
    FROM temp_patient_outcomes
    INNER JOIN temp_earliest_start_date USING (patient_id, site_id)
    WHERE cum_outcome = 'Patient died' AND patient_id = set_patient_id AND site_id = my_site_id
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
