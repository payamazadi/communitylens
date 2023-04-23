--How many incidents have multiple offenses?
--1: 87%, 2: 11%, 3: 1%
select 
	offensecount,
	count(offensecount) AS thecount,
	count(offensecount) * 1.0 / SUM(count(offensecount)) OVER () as percentage_records
from
incident_offense_counts
group by offensecount
order by offensecount


--Count per offense, state wide
select 
offense_name, count(*) offensecount 
from incident_offenses
group by offense_name
order by offensecount desc