CREATE OR REPLACE PROCEDURE cdk_mercury_output_file_jan2023()
LANGUAGE plpgsql AS $$
DECLARE
	date_var timestamp(0);
--    set statement_timeout to 10000000;
--    commit;
BEGIN
	SELECT into date_var CURRENT_timestamp;

    drop table if exists cdk_mercury_oncall_temp_table;
    drop table if exists cdk_mercury_oncall_temp_table_2;
    drop table if exists cdk_mercury_oncall_temp_table_3;
    
    create temporary table cdk_mercury_oncall_temp_table as
   
       SELECT
        
        -- root

        -- 1
         "dev"."oncall_v2_curated"."root".Identifier AS INCIDENT_ID,
        
        -- 2
        CASE 
            WHEN "dev"."oncall_v2_curated"."final_dealer_response".accepted = 'true' 
            THEN 'T'
            WHEN "dev"."oncall_v2_curated"."final_dealer_response".accepted = 'false' 
            THEN 'F'
        ELSE 
            NULL 
        END 
        AS ACCEPTED_FLAG, 

        "oncall_v2_curated"."final_dealer_response".responsetime,

        
        -- TODO: Mercury Team request 3.a
        -- 3
        CONCAT (
            EXTRACT( 
                year from to_timestamp(
                    "oncall_v2_curated"."root"."event_attributes_downat", 'YYYY-MM-DD HH24:MI:SS'
                )
            ),    
            LPAD (
                EXTRACT (
                    month from to_timestamp(
                        "oncall_v2_curated"."root"."event_attributes_downat", 'YYYY-MM-DD HH24:MI:SS'
                    )
                ), 2, '0'
            )
        )
        AS CALENDAR_CCYYMM_NBR,

        -- 4 
        "oncall_v2_curated"."assets".breakdown_city AS CITY,

        -- 5 
        "dev"."oncall_v2_curated"."invoice_products".attributes_tirecondition AS CONDITION_OF_TIRE,
        
        -- TODO: Mercury Team request 2.
        -- TODO: double check - in theory there is no bill_to for service providers
        -- 6
        "root".orderer_billto AS CUST_BT_CUST_NBR,
        
        -- 7
        "oncall_v2_curated"."assets".unit AS DEFECTIVE_UNIT,
        
        -- TODO: Mercury Team request 3.e
        -- 8 
        CASE 
            WHEN "oncall_v2_curated"."event_status_history".newstatus LIKE '%DISPATCH' 
            --THEN extract(month FROM to_timestamp("oncall_v2_curated"."event_status_history".changedat, 'YYYY-MM-DD HH24:MI:SS'))
            THEN 
                CONCAT (
                    EXTRACT( 
                        year from to_timestamp(
                            "oncall_v2_curated"."event_status_history".changedat, 'YYYY-MM-DD HH24:MI:SS'
                        )
                    ),    
                    LPAD (
                        EXTRACT (
                            month from to_timestamp(
                                "oncall_v2_curated"."event_status_history".changedat, 'YYYY-MM-DD HH24:MI:SS'
                            )
                        ), 2, '0'
                    )
                )
        ELSE 
            NULL 
        END 
        AS DISPATCH_CCYYMM_NBR,

        -- 9
        CASE 
            WHEN "oncall_v2_curated"."event_status_history".newstatus LIKE '%DISPATCH'  
            THEN split_part("dev"."oncall_v2_curated"."event_status_history".changedat, 'T', 1) 
        ELSE 
            NULL 
        END 
        AS DISPATCH_DATE,
        
        -- 10
        CASE 
            WHEN "oncall_v2_curated"."event_status_history".newstatus LIKE '%DISPATCH' 
            THEN left(split_part("dev"."oncall_v2_curated"."event_status_history".changedat, 'T', 2),8) 
        ELSE 
            NULL 
        END 
        AS DISPATCH_TIME,

        -- TODO: Mercury Team request 3.c
        --extract(month FROM to_timestamp("oncall_v2_curated"."root"."event_attributes_downat", 'YYYY-MM-DD HH24:MI:SS'))
        -- 11
        CONCAT (
            EXTRACT( 
                year from to_timestamp(
                    "oncall_v2_curated"."root"."event_attributes_downat", 'YYYY-MM-DD HH24:MI:SS'
                )
            ),    
            LPAD (
                EXTRACT (
                    month from to_timestamp(
                        "oncall_v2_curated"."root"."event_attributes_downat", 'YYYY-MM-DD HH24:MI:SS'
                    )
                ), 2, '0'
            )
        )
        AS DOWNTIME_CCYYMM_NBR,
        
        -- 12
        CASE 
            WHEN extract(dayofweek FROM to_timestamp("oncall_v2_curated"."root"."event_attributes_downat", 'YYYY-MM-DD HH24:MI:SS')) = 0 
            THEN 'sunday'
            WHEN extract(dayofweek FROM to_timestamp("oncall_v2_curated"."root"."event_attributes_downat", 'YYYY-MM-DD HH24:MI:SS')) = 1 
            THEN 'monday'
            WHEN extract(dayofweek FROM to_timestamp("oncall_v2_curated"."root"."event_attributes_downat", 'YYYY-MM-DD HH24:MI:SS')) = 2 
            THEN 'tuesday'
            WHEN extract(dayofweek FROM to_timestamp("oncall_v2_curated"."root"."event_attributes_downat", 'YYYY-MM-DD HH24:MI:SS')) = 3 
            THEN 'wednesday'
            WHEN extract(dayofweek FROM to_timestamp("oncall_v2_curated"."root"."event_attributes_downat", 'YYYY-MM-DD HH24:MI:SS')) = 4 
            THEN 'thursday'
            WHEN extract(dayofweek FROM to_timestamp("oncall_v2_curated"."root"."event_attributes_downat", 'YYYY-MM-DD HH24:MI:SS')) = 5 
            THEN 'friday'
            WHEN extract(dayofweek FROM to_timestamp("oncall_v2_curated"."root"."event_attributes_downat", 'YYYY-MM-DD HH24:MI:SS')) = 6 
            THEN 'saturday'
        END 
        AS DOWNTIME_DAY_OF_WEEK,
        
        -- 13
        split_part("oncall_v2_curated"."root"."event_attributes_downat", 'T', 1) 
        AS "DOWNTIME_START_DATE", 
        
        -- 14
        left(split_part("oncall_v2_curated"."root"."event_attributes_downat", 'T', 2),8) 
        AS "DOWNTIME_START_TIME",

        -- 15
        CASE 
            WHEN "dev"."oncall_v2_curated"."orderer_person"."type" 
            LIKE '%DRIVER%' 
            THEN split_part("dev"."oncall_v2_curated"."orderer_person"."name", ' ', 1) 
        ELSE 
            NULL
        END 
        AS driver_first_name,
        
        -- 16
        CASE 
            WHEN "dev"."oncall_v2_curated"."orderer_person"."type" 
            LIKE '%DRIVER%' 
            THEN split_part("dev"."oncall_v2_curated"."orderer_person"."name", ' ', 2) 
        ELSE 
            NULL 
        END 
        AS "driver_last_name",
        
        -- 17
        CASE 
            WHEN "dev"."oncall_v2_curated"."orderer_person"."type" 
            LIKE '%DRIVER%' 
            THEN "dev"."oncall_v2_curated"."orderer_person"."phone" 
        ELSE 
            NULL 
        END 
        AS "driver_phone",
        
        -- 18
        CASE 
            WHEN "dev"."oncall_v2_curated"."orderer_person"."type" 
            LIKE '%DRIVER%'  
            THEN "dev"."oncall_v2_curated"."orderer_person"."type" 
        ELSE 
            NULL 
        END 
        AS "driver_phone_type",

        -- 19
        "oncall_v2_curated"."ch_inboundprogram".fields_store AS INBOUND_CALLER_STORE, 
       
        -- 20
        "oncall_v2_curated"."ch_inboundprogram".fields_name AS INBOUND_PROGRAM,
        
        -- 21
        "oncall_v2_curated"."assets".breakdown_latitude AS LATITUDE,
        
        -- 22
        "oncall_v2_curated"."assets".breakdown_longitude AS LONGITUDE,
        
        -- 23 
        "root".orderer_accountselected AS NATIONAL_ACCOUNT,


        -- 24
        CASE 
            WHEN "dev"."oncall_v2_curated"."final_dealer_response".accepted = 'false' 
            THEN "dev"."oncall_v2_curated"."final_dealer_response".reason
        ELSE 
            NULL 
        END 
        AS REFUSAL_ACCEPTED_REASON,

        -- 25
        "dev"."oncall_v2_curated"."invoice_products".attributes_requestedaction AS REPLACEMENT_TIRE,
        
        -- 26
        "dev"."oncall_v2_curated"."invoice_products".attributes_rimtype AS RIM_TYPE,
        

        -- TODO: Mercury Team request 3.d
        -- extract(month FROM to_timestamp("oncall_v2_curated"."root"."event_attributes_rollingat", 'YYYY-MM-DD HH24:MI:SS'))
        -- 27
        CONCAT (
            EXTRACT( 
                year from to_timestamp(
                    "oncall_v2_curated"."root"."event_attributes_rollingat", 'YYYY-MM-DD HH24:MI:SS'
                )
            ),    
            LPAD (
                EXTRACT (
                    month from to_timestamp(
                        "oncall_v2_curated"."root"."event_attributes_rollingat", 'YYYY-MM-DD HH24:MI:SS'
                    )
                ), 2, '0'
            )
        )
        AS ROLL_CCYYMM_NBR,
        
        -- 28
        split_part("oncall_v2_curated"."root"."event_attributes_rollingat", 'T', 1) 
        AS "ROLL_DATE", 
        
        -- 29
        left(split_part("oncall_v2_curated"."root"."event_attributes_rollingat", 'T', 2),8) 
        AS "ROLL_TIME",

        -- 30
        "dev"."oncall_v2_curated"."invoice_products".attributes_requestedaction AS SERVICE_PROVIDED,

        -- 31
        "oncall_v2_curated"."final_dealer_response".shipto AS SERVICING_DEALER_ST_CUST_NBR,

        -- 32
        "root".orderer_shipto AS ST_CUST_NBR,
        
        -- 33
        "oncall_v2_curated"."assets".breakdown_state AS STATE,

        -- 34
        "oncall_v2_curated"."assets".assettype AS STATUS_LEVEL,
        
        -- 35
        "oncall_v2_curated"."assets".breakdown_street AS STREET_ADR,
        
        -- 36
        "dev"."oncall_v2_curated"."invoice_products".attributes_sculptedtreadname AS SUPPLIED_TREAD_DESIGN,

        -- 37
        CASE 
            WHEN "dev"."oncall_v2_curated"."final_dealer_response".accepted = true 
            THEN split_part("dev"."oncall_v2_curated"."final_dealer_response".responsetime, 'T', 1) 
        ELSE 
            NULL 
        END 
        AS TECH_ACCEPTANCE_DATE,
        
        -- 38
        CASE 
            WHEN "dev"."oncall_v2_curated"."final_dealer_response".accepted = true 
            THEN left(split_part("dev"."oncall_v2_curated"."final_dealer_response".responsetime, 'T', 2),8) 
        ELSE 
            NULL 
        END 
        AS TECH_ACCEPTANCE_TIME,
        
        -- TODO: Mercury Team request 3.b
        -- 39
        CASE 
            WHEN "dev"."oncall_v2_curated"."final_dealer_response".accepted = true 
            --THEN extract(month FROM to_timestamp("oncall_v2_curated"."final_dealer_response".responsetime, 'YYYY-MM-DD HH24:MI:SS'))
            THEN 
                CONCAT (
                    EXTRACT( 
                        year from to_timestamp(
                            "oncall_v2_curated"."final_dealer_response".responsetime, 'YYYY-MM-DD HH24:MI:SS'
                        )
                    ),    
                    LPAD (
                        EXTRACT (
                            month from to_timestamp(
                                "oncall_v2_curated"."final_dealer_response".responsetime, 'YYYY-MM-DD HH24:MI:SS'
                            )
                        ), 2, '0'
                    )
                )
        ELSE 
            NULL 
        END 
        AS TECH_ACCPT_CCYYMM_NBR,
        
        -- 40
        "provider_person".name AS TECH_NAME, 
        
        -- 41
        "provider_person".phone AS TECH_NBR_1,

        -- 42
        "oncall_v2_curated"."estimate_products".attributes_tireposition AS TIRE_POSITION,

        -- 43
        "dev"."oncall_v2_curated"."order_products".attributes_tiresize AS TIRE_SIZE,

        -- 44
        "dev"."oncall_v2_curated"."order_products".attributes_sculptedtreadname AS TREAD_DESIGN,

        -- 45
        "oncall_v2_curated"."assets".assettype AS VEHICLE_TYPE,

        -- 46
        "root".provider_location_zip AS ZIP_CODE,

        -- 47
        "oncall_v2_curated"."ch_dealerresponse".fields_response_time AS TIME_OF_CALL_RECEIVED,

        -- 48
        CASE 
            
            WHEN lower("oncall_v2_curated"."final_dealer_response".reason) LIKE 'accept%' -- it should begin with accept -- '%accept%' also considered "unacceptable pricing" and "does not accept payment method"
            THEN 'ACCEPTED'
            
            -- WHEN lower("oncall_v2_curated"."final_dealer_response".reason) LIKE '%%' THEN 'NOT SERVICED'
            
            WHEN lower("oncall_v2_curated"."final_dealer_response".reason) 
            IN (
                'eta missed / customer cancelled', 
                'eta missed / fleet cancelled', -- in the field reason, this is the reason and not 'eta missed / customer cancelled'
                'eta too long', 
                'incorrect tech rotation', 
                'no afterhours service', 
                'no answer', 
                'no national accounts', 
                'no service available',
                'out of service area (less than 50 miles)', 
              --  'out of service area (greater than 50 miles)', -- removed from declined and put in not serviced
                'phone number disconnected', 
                'rim not available',
                'technician refused service',  
                'too busy', -- consolidated to "Technician refused service" ie Declined
                'fx no product available', 
                'fx no service available'
            ) 
            THEN 'DECLINED'
            
            WHEN "oncall_v2_curated"."final_dealer_response".reason 
            IN (
                'checking tire availability', 
                'fleet cancellation', 
                'customer cancellation', -- reason not in the current data
                'fleet cancelled after dispatch',
                'customer cancelled after dispatch', -- reason not in the current data
                'fleet on credit hold', 
                'customer on credit hold',  -- reason not in the current data
                'does not accept payment method', 
                'other shop closer', 
                'out of service area (greater than 50 miles)', -- moved to not serviced instead of declined 
                'phone outage',
                'poor weather conditions',
                'power outage', 
                'referred to backup', 
                'tire size not available (outside stock profile)',  -- moved to not serviced instead of declined ticket 522 -- consolidated to "Preferred Tire Not Available"
                'tires on backorder',  -- moved to not serviced instead of declined ticket 522 -- consolidated to "Preferred Tire Not Available"
				'unacceptable pricing',
                'tire brand - not stocked by dealer (non michelin)', -- moved to not serviced instead of declined ticket 522 -- consolidated to "Preferred Tire Not Available"
                'fx fleet canceled', -- reason not in the current data
                'fx customer canceled', 
                'fx fleet canceled after dispatch', -- reason not in the current data
                'fx customer canceled after dispatch',
                'other service provider dispatched', -- reason not in the current data
                'other dealer dispatched', 
                'rejected', -- reason not in the current data
                'holiday or event closure', -- moved to not serviced instead of declined ticket 522
                'referred to store',  -- moved to not serviced instead of declined ticket 522
                'tire preference not available', -- moved to not serviced instead of declined ticket 522 -- consolidated to "Preferred Tire Not Available"
                'tire brand brand - not stocked by dealer', -- moved to not serviced instead of declined ticket 522 -- consolidated to "Preferred Tire Not Available"
				'tire brand brand - not stocked by service provider',  -- moved to not serviced instead of declined ticket 522 -- consolidated to "Preferred Tire Not Available"
				'tire size not available (included in stock profile)',  -- moved to not serviced instead of declined ticket 522 -- consolidated to "Preferred Tire Not Available"
                'tire size not available' -- moved to not serviced instead of declined ticket 522 -- consolidated to "Preferred Tire Not Available"
               
            ) 
            THEN 'NOT_SERVICED'

        ELSE 
            NULL 
        END 
        AS CALL_STATUS,

        -- 49
        "oncall_v2_curated"."ch_dealerresponse".fields_asset_location_drive_distance AS ACTUAL_DISTANCE_MILES,

        -- 50
        "oncall_v2_curated"."assets".breakdown_country AS BREAKDOWN_COUNTRY,

        -- 51
        -- TODO: field not found
        -- SUB_DEFECTIVE_UNIT
        NULL AS SUB_DEFECTIVE_UNIT,

        -- 52
        "dev"."oncall_v2_curated"."invoice_products".attributes_manufacturer AS SUPPLIED_BRAND,

        -- These field was requested by Maleek - requested brand and Notes 
        "dev"."oncall_v2_curated"."order_products".attributes_manufacturer AS REQUESTED_BRAND,

        "dev"."oncall_v2_curated"."assets".breakdown_note AS ASSET_BREAKDOWN_NOTE,
        "dev"."oncall_v2_curated"."ch_assetlocation".fields_note AS CH_ASSETLOCATION_FIELDS_NOTE,
        "dev"."oncall_v2_curated"."ch_assetlocation_changes".fields_note AS CH_ASSETLOCATION_CHANGES_FIELDS_NOTE,
        "dev"."oncall_v2_curated"."ch_dealerresponse".fields_note AS CH_DEALERRESPONSE_FIELDS_NOTE,
        "dev"."oncall_v2_curated"."ch_dealerresponse_changes".fields_note AS CH_DEALERRESPONSE_CHANGES_FIELDS_NOTE,


        -- 53 (to be depracated)
        -- TODO: field not found
        -- TIRE_SIZE_TYPE
        -- NULL AS TIRE_SIZE_TYPE,

        -- 54
        "dev"."oncall_v2_curated"."order_products".attributes_tirecondition AS FAILURE_REASON,

        -- 55
        "root".orderer_name AS ST_FLEET_NAME,

        -- 56
        "dev"."oncall_v2_curated"."order_products".attributes_producttype AS TIRE_TYPE,


        -- Date used for different purposes    
        "oncall_v2_curated"."root"."lastupdated" AS LASTUPDATED


        FROM "dev"."oncall_v2_curated"."root"
        LEFT JOIN "dev"."oncall_v2_curated"."provider_person"
            ON "dev"."oncall_v2_curated"."root"."provider_person_sk" = "dev"."oncall_v2_curated"."provider_person"."provider_person_sk"
        LEFT JOIN "dev"."oncall_v2_curated"."orderer_person"
            ON "dev"."oncall_v2_curated"."root"."orderer_person_sk" = "dev"."oncall_v2_curated"."orderer_person"."orderer_person_sk"
        LEFT JOIN "dev"."oncall_v2_curated"."order_products"
            ON "dev"."oncall_v2_curated"."root"."order_products_sk" = "dev"."oncall_v2_curated"."order_products"."order_products_sk"
        LEFT JOIN "dev"."oncall_v2_curated"."invoice_products"
            ON "dev"."oncall_v2_curated"."root"."invoice_products_sk" = "dev"."oncall_v2_curated"."invoice_products"."invoice_products_sk"
        LEFT JOIN "dev"."oncall_v2_curated"."final_dealer_response"
            ON "dev"."oncall_v2_curated"."root"."finaldealersresponse_sk" = "dev"."oncall_v2_curated"."final_dealer_response"."finaldealersresponse_sk"
        LEFT JOIN "dev"."oncall_v2_curated"."estimate_products"
            ON "dev"."oncall_v2_curated"."root"."estimate_products_sk" = "dev"."oncall_v2_curated"."estimate_products"."estimate_products_sk"
        LEFT JOIN "dev"."oncall_v2_curated"."ch_inboundprogram"
            ON "dev"."oncall_v2_curated"."root"."combinedhistory_inboundprogram_sk" = "dev"."oncall_v2_curated"."ch_inboundprogram"."combinedhistory_inboundprogram_sk"
        LEFT JOIN "dev"."oncall_v2_curated"."ch_dealerresponse"
            ON "dev"."oncall_v2_curated"."root"."combinedhistory_dealerresponse_sk" = "dev"."oncall_v2_curated"."ch_dealerresponse"."combinedhistory_dealerresponse_sk"
        LEFT JOIN "dev"."oncall_v2_curated"."ch_dealerresponse_changes"
            ON "dev"."oncall_v2_curated"."ch_dealerresponse_changes"."combinedhistory_dealerresponse_changes_sk" = "dev"."oncall_v2_curated"."ch_dealerresponse"."combinedhistory_dealerresponse_changes_sk"
        LEFT JOIN "dev"."oncall_v2_curated"."assets" 
            ON "dev"."oncall_v2_curated"."root"."assets_sk" = "dev"."oncall_v2_curated"."assets"."assets_sk"
        LEFT JOIN "dev"."oncall_v2_curated"."event_status_history"
            ON "dev"."oncall_v2_curated"."root"."event_statushistory_sk" = "dev"."oncall_v2_curated"."event_status_history"."event_statushistory_sk"
        LEFT JOIN "dev"."oncall_v2_curated"."ch_assetlocation"
            ON "dev"."oncall_v2_curated"."root"."combinedhistory_assetlocation_sk" = "dev"."oncall_v2_curated"."ch_assetlocation"."combinedhistory_assetlocation_sk"
        LEFT JOIN "dev"."oncall_v2_curated"."ch_assetlocation_changes"
            ON "dev"."oncall_v2_curated"."ch_assetlocation_changes"."combinedhistory_assetlocation_changes_sk" = "dev"."oncall_v2_curated"."ch_assetlocation"."combinedhistory_assetlocation_changes_sk"

        WHERE 
                extract(year FROM to_timestamp("oncall_v2_curated"."root".LASTUPDATED, 'YYYY-MM-DD HH24:MI:SS')) = extract(year from current_date)
        and 
                 extract(month from to_timestamp("oncall_v2_curated"."root".LASTUPDATED, 'YYYY-MM-DD HH24:MI:SS')) = extract(month from current_date)
        and 
                 extract(day from to_timestamp("oncall_v2_curated"."root".LASTUPDATED, 'YYYY-MM-DD HH24:MI:SS')) = extract(day from current_date) 
;
                       


-- Removing duplicates using distinct * (where the entire row is duplicated)
		create temporary table cdk_mercury_oncall_temp_table_2 as
		select distinct * from cdk_mercury_oncall_temp_table;
        
        
-- using a window function to remove the duplicate values based on root.identifier (incident_id) and response time 
-- for the call to get the latest/updated response 

		
       	create temporary table cdk_mercury_oncall_temp_table_3 as
		select  row_number() over(partition by incident_id, servicing_dealer_st_cust_nbr order by dispatch_ccyymm_nbr) as row_number_, *
		from cdk_mercury_oncall_temp_table_2
		order by incident_id, responsetime desc, servicing_dealer_st_cust_nbr desc, dispatch_ccyymm_nbr ;
			
        
        delete from cdk_mercury_oncall_temp_table_3
        where row_number_ != 1;
        
        ALTER TABLE cdk_mercury_oncall_temp_table_3
  		DROP COLUMN row_number_;

		update cdk_mercury_oncall_temp_table_3
		set refusal_accepted_reason = 'Technician refused service'
		where refusal_accepted_reason = 'Too busy';

		update cdk_mercury_oncall_temp_table_3
		set refusal_accepted_reason = 'Preferred Tire Not Available'
		where lower(refusal_accepted_reason) = 'tire preference not available'
		or lower(refusal_accepted_reason) = 'tire size not available (outside stock profile)'
		or lower(refusal_accepted_reason) = 'tires on backorder'
		or lower(refusal_accepted_reason) = 'tire brand - not stocked by dealer (non michelin)'
		or lower(refusal_accepted_reason) = 'tire preference not available'
		or lower(refusal_accepted_reason) = 'tire brand brand - not stocked by dealer'
		or lower(refusal_accepted_reason) = 'tire brand brand - not stocked by service provider'
		or lower(refusal_accepted_reason) = 'tire size not available (included in stock profile)'
		or lower(refusal_accepted_reason) = 'tire size not available';


		delete from cdk_mercury_oncall_temp_table_3
        where call_status is null;
        
        
        -- ALTER TABLE cdk_mercury_oncall_temp_table_2
  		-- DROP COLUMN responsetime;    
        

        -- updating to maintain the coherence between the two in case some condition is missed in the CASE STATEMENT

--      update cdk_mercury_oncall_temp_table_2
-- 		set accepted_flag = 'T'
-- 		where call_status = 'ACCEPTED';

--         update cdk_mercury_oncall_temp_table_2
-- 		set accepted_flag = 'F'
-- 		where call_status = 'DECLINED' or call_status = 'NOT_SERVICED';


        create schema if not exists dev.cdk_mercury_request;

		create table if not exists "cdk_mercury_request".daily
        (like cdk_mercury_oncall_temp_table_3);
        
        Insert into cdk_mercury_request.daily
        select * from cdk_mercury_oncall_temp_table_3;
                
        ALTER TABLE cdk_mercury_oncall_temp_table_3
  		DROP COLUMN LASTUPDATED;
        
    
EXECUTE 'unload ('
        || '''  select * from  cdk_mercury_oncall_temp_table_3  '''
        || ') '
		|| 'to '
        || '''s3://cdk-mercury-daily-files-temp/daily/'
        || date_var
        || ' '''
        || ' iam_role '
        || '''arn:aws:iam::464340339497:role/oncall-90-day-file-test-redshift-to-s3'''
        || ' header'
        || ' parallel off'
       || ' MAXFILESIZE 64 MB'
		|| ' csv;'
        ;

--         || ' MAXFILESIZE 128 MB' this is deleted for daily uploads 

		drop table cdk_mercury_oncall_temp_table;
        drop table cdk_mercury_oncall_temp_table_2;
        drop table cdk_mercury_oncall_temp_table_3;
        
END;
$$;
Call cdk_mercury_output_file_jan2023();