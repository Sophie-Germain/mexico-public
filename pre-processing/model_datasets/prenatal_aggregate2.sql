CREATE TABLE nick.prenatal_care_municipal2 AS
SELECT concat(mother_res_state::text,mother_res_muni) as municipality,
	avg(CASE WHEN mother_health_affiliation = 1 THEN total_parental_consultations ELSE NULL END) as none_avg_prenatal_consults,
	avg(CASE WHEN mother_health_affiliation = 2 THEN total_parental_consultations ELSE NULL END) as imss_avg_prenatal_consults,
	avg(CASE WHEN mother_health_affiliation = 3 THEN total_parental_consultations ELSE NULL END) as issste_avg_prenatal_consults,
	avg(CASE WHEN mother_health_affiliation IN(4,5,6,8) THEN total_parental_consultations ELSE NULL END) as other_avg_prenatal_consults,
	avg(CASE WHEN mother_health_affiliation IN(88,99) THEN total_parental_consultations ELSE NULL END) as unspecified_avg_prenatal_consults,
	avg(CASE WHEN mother_health_affiliation = 7 THEN total_parental_consultations ELSE NULL END) as sp_avg_prenatal_consults,
	avg(CASE WHEN mother_health_affiliation = 10 THEN total_parental_consultations ELSE NULL END) as oportunidades_avg_prenatal_consults,
	SUM((first_parental_trimester=0 AND mother_health_affiliation = 1)::int) AS none_first_prenatal_tri_no,
	SUM((first_parental_trimester=1 AND mother_health_affiliation = 1)::int) AS none_first_prenatal_tri_1,
	SUM((first_parental_trimester=2 AND mother_health_affiliation = 1)::int) AS none_first_prenatal_tri_2,
	SUM((first_parental_trimester=3 AND mother_health_affiliation = 1)::int) AS none_first_prenatal_tri_3,
	SUM((first_parental_trimester IN(8,9) AND mother_health_affiliation = 1)::int) AS none_first_prenatal_tri_ignored,
	SUM((mother_health_affiliation = 1)::int) AS none_insurance_births,
	SUM((first_parental_trimester=0 AND mother_health_affiliation = 2)::int) AS imss_first_prenatal_tri_no,
	SUM((first_parental_trimester=1 AND mother_health_affiliation = 2)::int) AS imss_first_prenatal_tri_1,
	SUM((first_parental_trimester=2 AND mother_health_affiliation = 2)::int) AS imss_first_prenatal_tri_2,
	SUM((first_parental_trimester=3 AND mother_health_affiliation = 2)::int) AS imss_first_prenatal_tri_3,
	SUM((first_parental_trimester IN(8,9) AND mother_health_affiliation = 2)::int) AS imss_first_prenatal_tri_ignored,
	SUM((mother_health_affiliation = 2)::int) AS imss_insurance_births,
	SUM((first_parental_trimester=0 AND mother_health_affiliation = 3)::int) AS issste_first_prenatal_tri_no,
	SUM((first_parental_trimester=1 AND mother_health_affiliation = 3)::int) AS issste_first_prenatal_tri_1,
	SUM((first_parental_trimester=2 AND mother_health_affiliation = 3)::int) AS issste_first_prenatal_tri_2,
	SUM((first_parental_trimester=3 AND mother_health_affiliation = 3)::int) AS issste_first_prenatal_tri_3,
	SUM((first_parental_trimester IN(8,9) AND mother_health_affiliation = 3)::int) AS issste_first_prenatal_tri_ignored,
	SUM((mother_health_affiliation = 3)::int) AS issste_insurance_births,
	SUM((first_parental_trimester=0 AND mother_health_affiliation IN(4,5,6,8))::int) AS other_first_prenatal_tri_no,
	SUM((first_parental_trimester=1 AND mother_health_affiliation IN(4,5,6,8))::int) AS other_first_prenatal_tri_1,
	SUM((first_parental_trimester=2 AND mother_health_affiliation IN(4,5,6,8))::int) AS other_first_prenatal_tri_2,
	SUM((first_parental_trimester=3 AND mother_health_affiliation IN(4,5,6,8))::int) AS other_first_prenatal_tri_3,
	SUM((first_parental_trimester IN(8,9) AND mother_health_affiliation IN(4,5,6,8))::int) AS other_first_prenatal_tri_ignored,
	SUM((mother_health_affiliation IN(4,5,6,8))::int) AS other_insurance_births,
	SUM((first_parental_trimester=0 AND mother_health_affiliation IN(88,99))::int) AS unspecified_first_prenatal_tri_no,
	SUM((first_parental_trimester=1 AND mother_health_affiliation IN(88,99))::int) AS unspecified_first_prenatal_tri_1,
	SUM((first_parental_trimester=2 AND mother_health_affiliation IN(88,99))::int) AS unspecified_first_prenatal_tri_2,
	SUM((first_parental_trimester=3 AND mother_health_affiliation IN(88,99))::int) AS unspecified_first_prenatal_tri_3,
	SUM((first_parental_trimester IN(8,9) AND mother_health_affiliation IN(88,99))::int) AS unspecified_first_prenatal_tri_ignored,
	SUM((mother_health_affiliation IN(88,99))::int) AS unspecified_insurance_births,
	SUM((first_parental_trimester=0 AND mother_health_affiliation = 7)::int) AS sp_first_prenatal_tri_no,
	SUM((first_parental_trimester=1 AND mother_health_affiliation = 7)::int) AS sp_first_prenatal_tri_1,
	SUM((first_parental_trimester=2 AND mother_health_affiliation = 7)::int) AS sp_first_prenatal_tri_2,
	SUM((first_parental_trimester=3 AND mother_health_affiliation = 7)::int) AS sp_first_prenatal_tri_3,
	SUM((first_parental_trimester IN(8,9) AND mother_health_affiliation = 7)::int) AS sp_first_prenatal_tri_ignored,
	SUM((mother_health_affiliation = 7)::int) AS sp_insurance_births,
	SUM((first_parental_trimester=0 AND mother_health_affiliation = 10)::int) AS oportunidades_first_prenatal_tri_no,
	SUM((first_parental_trimester=1 AND mother_health_affiliation = 10)::int) AS oportunidades_first_prenatal_tri_1,
	SUM((first_parental_trimester=2 AND mother_health_affiliation = 10)::int) AS oportunidades_first_prenatal_tri_2,
	SUM((first_parental_trimester=3 AND mother_health_affiliation = 10)::int) AS oportunidades_first_prenatal_tri_3,
	SUM((first_parental_trimester IN(8,9) AND mother_health_affiliation = 10)::int) AS oportunidades_first_prenatal_tri_ignored,
	SUM((mother_health_affiliation = 10)::int) AS oportunidades_insurance_births
FROM births_data
WHERE table_year >= 2009 AND table_year <= 2012
GROUP BY municipality
