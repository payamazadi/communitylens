--Starting with assumption that there's no problems with clearing whole incidents with single offense arrests..

--This query will provide detailed clearance rates for each crime category in each county.
--Start with all offenses grouped by county and offense. Then merge that with:
--All offenses that have matching arrests; grouped by county and offense; filtered by status of non-exceptional clearance.
--Some county/offense combinations will have 0 arrests, so we use the coalesce functions to turn those from null to 0
--The NULIF is an extra safety check to provide divide by 0 errors when calculating the clearance rate. But we don't expect to get rows when there are 0 offenses for it
--I want to show clearances both by arrest and by exceptional means, and then roll that up into a clearance rate 
--Uncomment next and final line in order to get an overall count of arrests. This number is not 100% reliable due to the way that arrests are tied to incidents and not offenses, creating potential challenges for multi offense incidents
--select sum(arrests) from (
select
county_offenses.offense_name,
county_offenses.county_name,
county_offenses.offense_count,
coalesce(normally_cleared_offenses.clearances_normal, 0) as cleared_normally_count,
coalesce(normally_cleared_offenses.arrests, 0) as arrests,
ROUND(coalesce((1.0 * normally_cleared_offenses.clearances_normal) / NULLIF(county_offenses.offense_count, 0) * 100, 0), 2) AS solved_crime_ratio
from county_offenses
left outer join
	(
		select county_name, offense_name, count(offense_name) as clearances_normal, sum(count_arrests) as arrests from
		(
			select 
			incident_offenses.incident_id, county_name, offense_name, count(*) as count_arrests
			from incident_offenses
			inner join nibrs_arrestee on nibrs_arrestee.incident_id = incident_offenses.incident_id and incident_offenses.offense_code = nibrs_arrestee.offense_code
			where incident_offenses.cleared_except_id = 6
			--and nibrs_arrestee.incident_id = 147339992
			group by incident_offenses.incident_id, county_name, offense_name
		) incident_clearances
		group by county_name, offense_name
	) as normally_cleared_offenses on normally_cleared_offenses.offense_name = county_offenses.offense_name  and county_offenses.county_name = normally_cleared_offenses.county_name
order by solved_crime_ratio desc
--) as x

/*
15030 sum total of arrests, without any exclusions
expect to be understating number of arrests here because an arrest is for a single offense
814 arrests that are not in the above subset. what are they?
	150124468 the arrests are coded for all other larceny, the offenses were theft of motor vehicle parts and 'all other larceny'
	150124524 the arrests are coded for identity theft, the offenses were 'all other larceny'
	368 'all other offenses' for society, not matching offenses
	84 'agg assaults', not matching offenses, 

7 times there are arrests associated to incidents where the incident is marked as exceptionally cleared
*/

--validation 1
--show all the arrests where i dont have a matching offense
--814 records
select 
* 
--offense_code, count(*)
from nibrs_arrestee where incident_id not in
	(
		select incident_id from
			(
				select 
				incident_offenses.incident_id, county_name, offense_name, count(*) as count_arrests
				from incident_offenses
				inner join nibrs_arrestee on nibrs_arrestee.incident_id = incident_offenses.incident_id and incident_offenses.offense_code = nibrs_arrestee.offense_code
				group by incident_offenses.incident_id, county_name, offense_name
			) as x
	) --and offense_code = '13A' 
	group by offense_code order by count(*) desc
	

--validation 2 following validation one, which departments and for which codes do we not have matching offenses?
select 
pub_agency_name, y.offense_code, max(offense_name), count(y.offense_code)
from (
	select 
	* 
	--offense_code, count(*)
	from nibrs_arrestee where incident_id not in
		(
			select incident_id from
				(
					select 
					incident_offenses.incident_id, county_name, offense_name, count(*) as count_arrests
					from incident_offenses
					inner join nibrs_arrestee on nibrs_arrestee.incident_id = incident_offenses.incident_id and incident_offenses.offense_code = nibrs_arrestee.offense_code
					group by incident_offenses.incident_id, county_name, offense_name
				) as x
		) --and offense_code = '13A' 
		--group by offense_code order by count(*) desc
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
--7 arrests marked exceptionally clared. 3 montgomery, 4 baltimore
select 
			incident_offenses.incident_id, county_name, offense_name, count(*) as count_arrests
			from incident_offenses
			inner join nibrs_arrestee on nibrs_arrestee.incident_id = incident_offenses.incident_id and incident_offenses.offense_code = nibrs_arrestee.offense_code
			--where nibrs_arrestee.incident_id = 140458226
			--where nibrs_arrestee.multiple_indicator = 'M'
			where incident_offenses.cleared_except_id != 6
			group by incident_offenses.incident_id, county_name, offense_name

--139766694 an arrest for simple assault, marked that victim wouldn't cooperate. montgomery
--144981478 an arrest for simple assault, marked juvenile/no custody
--148741468 an arrest for motor vehicle theft, marked juvenile/no custody. montgomery
--150138911 an arrest for 'all other larceny', marked juvenile/no custody. baltimore
--150144956 same ^
--150145376 same ^
--150176373 an arrest for weapon law violation, marked juevenile/no custody. baltimore
select * from nibrs_arrestee where incident_id = 150176373
select * from nibrs_offense_type where offense_code = '520'
select cleared_except_id from nibrs_incident where incident_id = 150176373
select * from nibrs_cleared_except




select 
county_name, offense_name, 
sum(CASE WHEN incident_offenses.cleared_except_id = 1 THEN 1 ELSE 0 END) as cleared_death_offender,
sum(CASE WHEN incident_offenses.cleared_except_id = 2 THEN 1 ELSE 0 END) as cleared_prosecution_declined,
sum(CASE WHEN incident_offenses.cleared_except_id = 3 THEN 1 ELSE 0 END) as cleared_custody_elsewhere,
sum(CASE WHEN incident_offenses.cleared_except_id = 4 THEN 1 ELSE 0 END) as cleared_victim_uncooperative,
sum(CASE WHEN incident_offenses.cleared_except_id = 5 THEN 1 ELSE 0 END) as cleared_juvenile_release
from incident_offenses
inner join nibrs_cleared_except on incident_offenses.cleared_except_id = nibrs_cleared_except.cleared_except_id
where incident_offenses.cleared_except_id != 6
group by county_name, offense_name, cleared_except_code


select * from nibrs_cleared_except
select distinct cleared_except_id from nibrs_incident limit 1

--group by county_name, offense_name
/*
TODO: 
arrest clearance rate and exceptional clearance rate by crim
if arrest is for highest level offense in multi offense incidents
is clearance based on "top level" crime
time from incident submitted to arrest
service calls that lead to immediate arrest
do some places call the police and file incidents more than others?