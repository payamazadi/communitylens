--Starting with assumption that there's no problems with clearing whole incidents with single offense arrests..

--This query will provide detailed clearance rates for each crime category in each county.
--Start with all offenses grouped by county and offense. Then merge that with:
--All offenses that have matching arrests; grouped by county and offense; filtered by status of non-exceptional clearance.
--Some county/offense combinations will have 0 arrests, so we use the coalesce in views to turn those from null to 0
--I want to show clearances both by arrest and by exceptional means, and then roll that up into distinct clearance rates

--15030 sum total of arrests, without any exclusions
--expect to be understating number of arrests here because an arrest is for a single offense
--however one incident may have multiple arrests
with calculated_values as (
	select 
	*,
	(clearances_normal + clearances_exceptional_total) as clearances_total
	FROM
	county_incident_clearances_all_aggregated
)
SELECT
	county_name,
	offense_name,
	offense_count,
	clearances_total,
	ROUND((clearances_total::numeric / offense_count) * 100, 2) as clearance_ratio_total_percent,
	ROUND((clearances_normal::numeric / offense_count) * 100, 2) as clearance_ratio_normal_percent,
	ROUND((clearances_exceptional_total::numeric / offense_count) * 100, 2) as clearance_ratio_exceptional_percent,
	clearances_normal,
	clearances_exceptional_total,
	arrests,
	clearances_exceptional_death_offender,
	clearances_exceptional_prosecution_declined,
	clearances_exceptional_custody_elsewhere,
	clearances_exceptional_victim_uncooperative,
	clearances_exceptional_juvenile_release
FROM calculated_values
order by county_name, clearance_ratio_total_percent desc


/*validation 1
for which departments and for which codes do we have arrests without matching offenses?

814 arrests that are not in the above subset. what are they?
	150124468 the arrests are coded for all other larceny, the offenses were theft of motor vehicle parts and 'all other larceny'
	150124524 the arrests are coded for identity theft, the offenses were 'all other larceny'
	368 'all other offenses' for society, not matching offenses
	84 'agg assaults', not matching offenses, 
*/
select 
pub_agency_name, y.offense_code, max(offense_name), count(y.offense_code)
from (
	select 
	* 
	from 
	nibrs_arrestee 
	where incident_id not in
		(
			select incident_id 
			from
			county_incident_arrests
		)
	) AS y 
inner join nibrs_incident on y.incident_id = nibrs_incident.incident_id
inner join agencies on nibrs_incident.agency_id = agencies.agency_id
inner join nibrs_offense_type on y.offense_code = nibrs_offense_type.offense_code
group by agencies.agency_id, y.offense_code
order by count(y.offense_code) desc



-- validation 3 - am i overcounting arrests?
--147339055 5 arrests, 2 crimes
--147339992 2 arrests, 2 crimes
--no, not when adding in the match for offense_code between the offense and the arrest
select 
incident_offenses.incident_id, count(*)
from incident_offenses
inner join nibrs_arrestee on nibrs_arrestee.incident_id = incident_offenses.incident_id and incident_offenses.offense_code = nibrs_arrestee.offense_code
where county_name = 'MONTGOMERY' and offense_name ilike '%prost%'
--and incident_offenses.incident_id = 147339992
group by incident_offenses.incident_id, offense_name


--validation 4
--7 incidents with arrests marked exceptionally cleared. 3 montgomery, 4 baltimore
--139766694 an arrest for simple assault, marked that victim wouldn't cooperate. montgomery
--144981478 an arrest for simple assault, marked juvenile/no custody
--148741468 an arrest for motor vehicle theft, marked juvenile/no custody. montgomery
--150138911 an arrest for 'all other larceny', marked juvenile/no custody. baltimore
--150144956 same ^
--150145376 same ^
--150176373 an arrest for weapon law violation, marked juevenile/no custody. baltimore
select 
incident_offenses.incident_id, county_name, offense_name, count(*) as count_arrests
from incident_offenses
inner join nibrs_arrestee on nibrs_arrestee.incident_id = incident_offenses.incident_id and incident_offenses.offense_code = nibrs_arrestee.offense_code
--where nibrs_arrestee.incident_id = 140458226
--where nibrs_arrestee.multiple_indicator = 'M'
where incident_offenses.cleared_except_id != 6
group by incident_offenses.incident_id, county_name, offense_name




/*
TODO: 
X arrest normal clearance rate, exceptional clearance rate, total clearance rate by crime and county
X offenses tied to cleared incidents without arrests
what are the offenses in cleared incidents for which there were no arrests? this margin is the overestimation of the clearance rate and should be deducted from the counts at the individual offense level.
time from incident submitted to arrest
service calls
	origination, relation to clearances, counts per type and arrests, how quickly they result in arrests
do some places call the police and file incidents more than others?
do some victim demographics (or offender demographics) get more "resources" than others? e.g. are white women more likely to get rape clearances, or are black people more likely to get arrested for simple assault?
extend setup/queries to use a custom-imposed crime taxonomy
extend ingest/database/queries to multi-state. presumably because of the standardization of the tables, the same queries should work in every state. exceptions might be around native reservations, dont yet know how those are handled
create/extend ingest process 