/* COUNTING */
/* 1. How many observations for each signal at the county level? */
SELECT signal, COUNT(*) as signal_num_rows
FROM covid
WHERE geo_type = 'county'
GROUP BY signal
ORDER BY signal_num_rows DESC

/* 2. How many observations for each state? */
SELECT geo_value, COUNT(*) AS num_rows
FROM covid
WHERE geo_type = 'state' /* AND geo_value = 'ca' */
GROUP BY geo_value
ORDER BY num_rows DESC

/* 3. Number of survey responses (using unweighted, unsmoothed signal) */
select SUM(sample_size) from covid
WHERE data_source = 'fb-survey'
AND geo_type = 'nation'
AND signal = 'raw_cli'
GROUP BY signal

/* OPEN ENDED QUESTIONS */
/* 1. Find an interesting signal in fb-survey
/* Examine mean hesitancy by county */
SELECT state, county, signal, AVG(value) AS mean_value
FROM covid, county
WHERE covid.geo_type = 'county'
AND covid.data_source = 'fb-survey'
AND covid.signal = 'smoothed_hesitancy_reason_dislike_vaccines'
AND CAST(covid.geo_value AS int) = CAST(county.id2 AS int)
GROUP BY county, state, signal
ORDER BY mean_value DESC

/* Examine mean hesitancy by state */
SELECT geo_value, AVG(value) AS mean_value
FROM covid
WHERE geo_type = 'state'
AND data_source = 'fb-survey'
AND signal = 'smoothed_hesitancy_reason_dislike_vaccines'
GROUP BY geo_value
ORDER BY mean_value DESC

/* Bring in outside data source; JOIN data in tables */
SELECT a.state, a.mean_state_income, b.mean_state_hesitancy 
FROM
    (SELECT state,
            AVG("income-2015") AS mean_state_income
    FROM county_income
    GROUP BY  state) AS a
INNER JOIN 
    (SELECT UPPER(geo_value) AS geo_value,
         AVG(value) AS mean_state_hesitancy
    FROM covid
    WHERE geo_type = 'state'
    AND data_source = 'fb-survey'
    AND signal = 'smoothed_hesitancy_reason_dislike_vaccines'
    GROUP BY  geo_value) AS b 
    
ON a.state = b.geo_value
ORDER BY mean_state_income DESC
/* At end of 5/3 lecture
1. Download table as local file (csv)
2. Upload table into S3 directory
3. Crawl new directory with a new crawler: set up crawler, run crawler
4. Crawler should add new table to existing database