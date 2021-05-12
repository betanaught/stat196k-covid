
## Homework COVID Database
# Brendan Wakefield
# May 6, 2021

Outcomes

- Query data using SQL (structured query language)
- Find, upload, and join new tables to existing tables

### Setup

Use [AWS Glue](https://console.aws.amazon.com/glue/home?region=us-east-1#catalog:tab=crawlers) to create a database by crawling `s3://stat196k-data-examples/covid_db/`.
Your database should contain 3 tables:

1. `covid`, with around 120 million rows from [COVIDcast](https://delphi.cmu.edu/covidcast/) by CMU Delphi Group. 
    This was originally `covidcast_data` in the [AWS COVID data lake](https://aws.amazon.com/covid-19-data-lake/).
    I gave it a shorter name to make it easier to write.
2. `county`, with rows for the population of every county.
    This was originally `county_populations` in the data lake.
3. `states` containing names for every state.
    This was originally `us_state_abbreviations` in the data lake.


## Understanding the data

4 pts

1. Pick one of the [limitations described in the data documentation](https://cmu-delphi.github.io/delphi-epidata/api/covidcast-signals/fb-survey.html#limitations) and elaborate on it.
    What does it mean?

```Social desirability. Previous survey research has shown that people’s responses to surveys are often biased by what responses they believe are socially desirable or acceptable. For example, if it there is widespread pressure to wear masks, respondents who do not wear masks may feel pressured to answer that they do. This survey is anonymous and online, meaning we expect the social desirability effect to be smaller, but it may still be present.```
    This one is huge! Bias and influencing factors present in surveys is a fascinating topic (affecting the skew and linearity of numeric data), and the subconcious influences on survey-respondents is a fascinating (and almost metaphysical) issue social psychologists need to deal with. The factors influencing Social Desirability are centered around people answering in a way consistent with how they wish to be perceived, which has the potential to shift results from "reality." And, while yes the survey is anonymous, it is a testiment to the survey designers that they acknowledge this potential impact in the responses.

1. Find a row in the `covid` table that contains SE (standard error) for one signal.
    Use this to construct and interpret a "quick and dirty" 95% confidence interval for that particular signal in that row.

data_source	signal	geo_type	time_value	geo_value	direction	value	stderr	sample_size
1	fb-survey	smoothed_nohh_cmnty_cli	nation	20210423	us		11.5368532	0.0708588	203265.0

The quick-and-dirty CI calculation comes from the value +/- (1.96)(SE), so here it is (11.5368532) +/- (1.96)(0.0708588)
```julia
(11.5368532 + (1.96)(0.0708588), 11.5368532 - (1.96)(0.0708588))
```

```
(11.675736448, 11.397969951999999)
```





## Counting

8 pts
_Include your answers and show SQL queries for the questions below._

### 1

How many observations are there for each signal in the county level `covid` rows?
County level rows means that `geo_type = 'county'`.
Show the top 5 `signals` with the most counts.
```sql
SELECT signal, COUNT(*) as signal_num_rows
FROM covid
WHERE geo_type = 'county'
GROUP BY signal
ORDER BY signal_num_rows DESC
```
The number of observations for each signal ranges from 2000 - 35,000; the top five signals are "confirmed_incidence_num", "confirmed_cumulative_num", "confirmed_cumulative_prop", "confirmed_incidence_prop", and "deaths_cumulative_num".
### 2

How many county level rows does the `covid` table have for each state?
Show the top 5 states with the most counts, including the name of the state.
How many observations does California have?
```sql
SELECT geo_value, COUNT(*) AS num_rows
FROM covid
WHERE geo_type = 'state' /* AND geo_value = 'ca' */
GROUP BY geo_value
ORDER BY num_rows DESC
```
There are generally 50,000 - 56,000 rows for each state. California has 56,080.
### 3

The original data source claims to have around 20 million Facebook survey responses.
Does it appear that there are around 20 million survey responses present in the `covid` table?
```sql
select SUM(sample_size) from covid
WHERE data_source = 'fb-survey'
AND geo_type = 'nation'
AND signal = 'raw_cli'
GROUP BY signal
```
To find the number of responses (which differes from the number of rows WHERE data_source = 'fb-survey', I picked an *unsmoothed*, and *unweighted* signal and returned the sample size for that variable (I chose 'raw_cli'). This did indeed return just over 19M samples (19,646,428)

## Open ended questions

8 points
_Include the SQL and at least 1 plot in your answers to the following questions.
It's sufficient to include a plot for either the first or second question._


### 1

Pick one of the signals from Delphi's [Facebook survey](https://cmu-delphi.github.io/delphi-epidata/api/covidcast-signals/fb-survey.html) that you find personally interesting.
Explain what the signal means, and use this signal to pose and answer a question using the `covid` table.

```sql
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
```
I was curious to investigate the signal 'smoothed_hesitancy_reason_dislike_vaccines' which was a measurmente of respondents who were hesitant to receive a covid vaccination because they do not like vaccines. I plotted the mean hesitancy by state to see how the states rank, and I saw that AK has the highest by a large margin:
```julia
using DataFrames
using Plots
# using StatsPlots
using CSV

# hesitant = CSV.read("signal-plot.csv", DataFrame)
hesitant = CSV.read("state_hesitancy.csv", DataFrame)
sort!(hesitant, :mean_value, rev = true)
# sort!(hesitant, [:state, :mean_value], rev = true)

plotly()
# groupedbar(hesitant.county, hesitant.mean_value, group = hesitant.state)

scatter(hesitant.geo_value, hesitant.mean_value, legend = false)
# scatter!(xticks = ([1:length(hesitant.geo_value)], hesitant.geo_value))
# bar(hesitant)
```





### 2

Load an external table into your database and use it to ask and answer a new question by joining it with the existing tables.
For example, we could look at the relationship between political backgrounds and COVID attitudes by finding a table with votes for each party by state or county for the 2020 presidential election.

```sql
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
```
Does mean state wealth potentially provide the luxury of feeling hesitant to get the vaccine? I downloaded a data table of the average household income by county, and uploaded this to S3 to be crawled by Glue. My query JOINs mean 'hesitancy' by state to mean household income by state.

```julia
using DataFrames
using Plots
# using StatsPlots
using CSV

# hesitant = CSV.read("signal-plot.csv", DataFrame)
state_income_hesitancy = CSV.read("state_income_hesitancy.csv", DataFrame)
sort!(state_income_hesitancy, :mean_state_income, rev = true)
# sort!(hesitant, [:state, :mean_value], rev = true)

plotly()
# groupedbar(hesitant.county, hesitant.mean_value, group = hesitant.state)

scatter(state_income_hesitancy.mean_state_income,
        state_income_hesitancy.mean_state_hesitancy,
        legend = false)
```



Quick and dirty LM, I would prefer to take the raw survey data and fit a model with the states as random effects

```julia
using GLM
lm1 = lm(@formula(mean_state_hesitancy ~ mean_state_income), state_income_hesitancy)
```

```
StatsModels.TableRegressionModel{GLM.LinearModel{GLM.LmResp{Vector{Float64}
}, GLM.DensePredChol{Float64, LinearAlgebra.CholeskyPivoted{Float64, Matrix
{Float64}}}}, Matrix{Float64}}

mean_state_hesitancy ~ 1 + mean_state_income

Coefficients:
───────────────────────────────────────────────────────────────────────────
────────
                        Coef.  Std. Error      t  Pr(>|t|)    Lower 95%   U
pper 95%
───────────────────────────────────────────────────────────────────────────
────────
(Intercept)        9.96531     0.814511    12.23    <1e-15   8.32763     11
.603
mean_state_income  2.14564e-5  1.55034e-5   1.38    0.1728  -9.71519e-6   5
.2628e-5
───────────────────────────────────────────────────────────────────────────
────────
```




Almost no evidence of an extremely small effect of income on the mean hesitancy!