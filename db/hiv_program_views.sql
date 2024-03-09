

-- view to capture avg ART/HIV care treatment time for ART patients at a given site
DROP TABLE IF EXISTS `patient_service_waiting_time`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
VIEW `patient_service_waiting_time` AS
    SELECT
        `e`.`patient_id` AS `patient_id`,
        cast(`e`.`encounter_datetime` as date) AS `visit_date`,
        min(`e`.`encounter_datetime`) AS `start_time`,
        max(`e`.`encounter_datetime`) AS `finish_time`,
        timediff(max(`e`.`encounter_datetime`),
                min(`e`.`encounter_datetime`)) AS `service_time`
    FROM
        (`encounter` `e`
        join `encounter` `e2` ON (((`e`.`patient_id` = `e2`.`patient_id`)
            AND (`e`.`encounter_type` in (7 , 9, 12, 25, 51, 52, 53, 54, 68)))))
    WHERE
        ((`e`.`encounter_datetime` BETWEEN date_format((now() - interval 7 day),
                '%Y-%m-%d 00:00:00') AND date_format((now() - interval 1 day),
                '%Y-%m-%d 23:59:59'))
            AND (right(`e`.`encounter_datetime`, 2) <> '01')
            AND (right(`e`.`encounter_datetime`, 2) <> '01'))
    GROUP BY `e`.`patient_id` , cast(`e`.`encounter_datetime` as date)
    ORDER BY `e`.`patient_id` , `e`.`encounter_datetime`;

-- Non-voided HIV Clinic Consultation encounters
DROP TABLE IF EXISTS `clinic_consultation_encounter`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `clinic_consultation_encounter` AS
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
  WHERE (`encounter`.`encounter_type` = 53 AND `encounter`.`voided` = 0);

-- ARV drugs
DROP TABLE IF EXISTS `arv_drug`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
	VIEW `arv_drug` AS
	SELECT `drug_id` FROM `drug`
	WHERE `concept_id` IN (SELECT `concept_id` FROM `concept_set` WHERE `concept_set` = 1085);

-- ARV drugs orders
DROP TABLE IF EXISTS `arv_drugs_orders`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
   VIEW `arv_drugs_orders` AS
   SELECT `ord`.`patient_id`, `ord`.`encounter_id`, `ord`.`concept_id`, `ord`.`start_date`
   FROM `orders` `ord`
   WHERE `ord`.`voided` = 0
   AND `ord`.`concept_id` IN (SELECT `concept_id` FROM `concept_set` WHERE `concept_set` = 1085);

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







