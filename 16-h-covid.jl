using DataFrames
using Plots
using StatsPlots
using CSV

# hesitant = CSV.read("signal-plot.csv", DataFrame)
hesitant = CSV.read("state_hesitancy.csv", DataFrame)
sort!(hesitant, :mean_value, rev = true)
# sort!(hesitant, [:state, :mean_value], rev = true)

plotly()
SZ = 500, 500
# groupedbar(hesitant.county, hesitant.mean_value, group = hesitant.state)

scatter(hesitant.geo_value, hesitant.mean_value)
# scatter!(xticks = ([1:length(hesitant.geo_value)], hesitant.geo_value))
# bar(hesitant)