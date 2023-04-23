--Create view for cumulative join showing all incident offenses and agencies without filters (one row per offense)
create or replace view incident_offenses AS
select
nibrs_incident.incident_id, nibrs_offense.offense_id, incident_date, submission_date, cleared_except_id, nibrs_offense.offense_code, offense_name, attempt_complete_flag, agencies.agency_id, pub_agency_name, agency_type_name, submitting_agency_name, county_name, population_group_desc, parent_pop_group_desc, population
from nibrs_incident 
inner join nibrs_offense on nibrs_incident.incident_id = nibrs_offense.incident_id
inner join nibrs_offense_type on nibrs_offense_type.offense_code = nibrs_offense.offense_code
inner join agencies on nibrs_incident.agency_id = agencies.agency_id

--Create view that aggregates offenses in incidents (one row per incident)
create or replace view incident_offenses_aggregated AS
select 
	nibrs_incident.incident_id, nibrs_incident.incident_date, nibrs_incident.submission_date, nibrs_incident.cleared_except_id,
    pub_agency_name, agency_type_name, submitting_agency_name, county_name, population_group_desc, parent_pop_group_desc, population,
	count(nibrs_offense.*) AS offenses_count,
    string_agg(nibrs_offense_type.offense_name, ',,,,, ') AS offenses
from nibrs_incident
inner join nibrs_offense ON nibrs_incident.incident_id = nibrs_offense.incident_id
inner join nibrs_offense_type ON nibrs_offense_type.offense_code = nibrs_offense.offense_code
inner join agencies ON nibrs_incident.agency_id = agencies.agency_id
group by nibrs_incident.incident_id, agencies.agency_id;


--Create view for single offense incidents
create or replace view incident_offenses_single AS
select * from incident_offenses_aggregated where offenses_count = 1

--Create view for multi offense incidents
create or replace view incident_offenses_multiple AS
select * from incident_offenses_aggregated where offenses_count > 1


--Create view for count of offenses in county
create or replace view county_offenses AS
select
offense_name, county_name, count(*) offense_count
from incident_offenses
group by county_name, offense_name
order by offense_count desc

--Create view for count of arrests per offense in county
create or replace view county_incident_arrests AS
select
incident_offenses.incident_id, county_name, offense_name, count(*) as count_arrests
from incident_offenses
inner join nibrs_arrestee on nibrs_arrestee.incident_id = incident_offenses.incident_id and incident_offenses.offense_code = nibrs_arrestee.offense_code
where incident_offenses.cleared_except_id = 6
group by incident_offenses.incident_id, county_name, offense_name

--Create view for total arrests and clearances for each offense TYPE per county
create or replace view county_incident_arrests_aggregated AS
select county_name, offense_name, count(offense_name) as clearances_normal, sum(count_arrests) as arrests
from
county_incident_arrests
group by county_name, offense_name

--Create view for exceptional clearance breakdowns per offense in county
create or replace view county_incident_clearances_exceptional_aggregated AS
select *, clearances_exceptional_death_offender+clearances_exceptional_prosecution_declined+clearances_exceptional_custody_elsewhere+clearances_exceptional_victim_uncooperative+clearances_exceptional_juvenile_release as clearances_exceptional_total
from (
	select 
	county_name, offense_name, 
	sum(CASE WHEN incident_offenses.cleared_except_id = 1 THEN 1 ELSE 0 END) as clearances_exceptional_death_offender,
	sum(CASE WHEN incident_offenses.cleared_except_id = 2 THEN 1 ELSE 0 END) as clearances_exceptional_prosecution_declined,
	sum(CASE WHEN incident_offenses.cleared_except_id = 3 THEN 1 ELSE 0 END) as clearances_exceptional_custody_elsewhere,
	sum(CASE WHEN incident_offenses.cleared_except_id = 4 THEN 1 ELSE 0 END) as clearances_exceptional_victim_uncooperative,
	sum(CASE WHEN incident_offenses.cleared_except_id = 5 THEN 1 ELSE 0 END) as clearances_exceptional_juvenile_release
	from incident_offenses
	inner join nibrs_cleared_except on incident_offenses.cleared_except_id = nibrs_cleared_except.cleared_except_id
	where incident_offenses.cleared_except_id != 6
	group by county_name, offense_name--, cleared_except_code
) as x

--Create view for total clearance counts and arrests by offense and county
create or replace view county_incident_clearances_all_aggregated AS
select
county_offenses.county_name,
county_offenses.offense_name,
county_offenses.offense_count,
coalesce(county_incident_arrests_aggregated.clearances_normal, 0) as clearances_normal,
coalesce(county_incident_clearances_exceptional_aggregated.clearances_exceptional_total, 0) as clearances_exceptional_total,
coalesce(county_incident_arrests_aggregated.arrests, 0) as arrests,
coalesce(county_incident_clearances_exceptional_aggregated.clearances_exceptional_death_offender, 0) as clearances_exceptional_death_offender,
coalesce(county_incident_clearances_exceptional_aggregated.clearances_exceptional_prosecution_declined, 0) as clearances_exceptional_prosecution_declined,
coalesce(county_incident_clearances_exceptional_aggregated.clearances_exceptional_custody_elsewhere, 0) as clearances_exceptional_custody_elsewhere,
coalesce(county_incident_clearances_exceptional_aggregated.clearances_exceptional_victim_uncooperative, 0) as clearances_exceptional_victim_uncooperative,
coalesce(county_incident_clearances_exceptional_aggregated.clearances_exceptional_juvenile_release, 0) as clearances_exceptional_juvenile_release
from county_offenses
left outer join county_incident_arrests_aggregated on county_incident_arrests_aggregated.offense_name = county_offenses.offense_name and county_incident_arrests_aggregated.county_name = county_offenses.county_name
left outer join county_incident_clearances_exceptional_aggregated on county_incident_clearances_exceptional_aggregated.offense_name = county_offenses.offense_name and county_incident_clearances_exceptional_aggregated.county_name = county_offenses.county_name
order by county_name, offense_count desc