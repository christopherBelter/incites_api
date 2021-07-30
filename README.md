# incites_api
R functions to work with the InCites API

## Overview
`inCites_api` is a set of functions to allow you to work with version 2 of the InCites API from Clarivate Analytics in the R programming language. The API allows you to either request indicators for all publications from your institution starting from a specific year or to request indicators for a specific set of Web of Science accession numbers (or UT numbers). These two options are implemented in the `inCites_api` package in the `orgMetrics()` and `searchByUT()` functions, respectively. 

To use these functions, you or your organization must have a current subscription to the InCites database that includes access to the InCites API. You must also obtain an API key from the [Clarivate Analytics Developer Portal](https://developer.clarivate.com/). You must also have the `httr` and `jsonlite` packages installed in your local version of R. Both packages are contained in the `tidyverse`, so you probably already have them, but it's worth double-checking to be sure. 

## Setting Up
First, download and save the `incites_api.r` file to your computer in a place that you can find it. Then get your API Key from the Developer Portal and save it somewhere secure.

Once you have your API key, you need to store it in a place that these functions can find. Rather than passing it in as an argument, which you might inadvertantly share with others when sharing code, the `inCites_api` package contains a helper function, `setInCitesKey()`, to store your API key in your .Renviron file. This file allows you to create a custom set of environment variables every time R starts, so it's handy for storing things like API keys. 

To do so, start R and then load the .r file with source()
```r
source("./incites_api.r")
```
Then, use the setInCitesKey() function to save the key to your .Renviron file
```r
setInCitesKey("[yourkey]")
```
replacing the [yourkey] text with your API key. You should then get a message saying that your key was successfully stored and to restart R for the change to take effect. So restart R and you should be good to go. Every time you start R from now until you update R, your key will be available in your R session. The `inCites_api` package also has a convenience function, `getInCitesKey()`, to have R print out your key for you by simply running
```r
getInCitesKey()
```    
Be aware, though, that your .Renviron file might get erased when you update your version of R, so make sure you have your key available somewhere else. And if, after you update R and try to run other functions in this package, you get an error message saying that the "INCITES_API_KEY" variable does not exist, run the `setInCitesKey()` function again to store it, restart R, and then you should be fine. 

## Requesting Data for your Organization

Requesting data for all publications by authors from your organization is done with the `orgPubCount()` and `orgMetrics()` functions. Both functions are tied to your organization ID in WOS by your API key, so you can't currently change what organization you request these metrics for. Both functions are tied to a specific start year, and will return indicators for publications by authors at your organization starting from the year you specify. To use them, load the .r file 
```r
source("./incites_api.r")
```
and then use the `orgPubCount()` function to see how many publications are available for you to request. So to see how many publications are available for your organization from 2019-present, run 
```r
orgPubCount("2019")
```
If you want to actually download the indicators for that entire set of publications, you can run 
```r
pubs <- orgMetrics("2019", outfile = "org_metrics.txt")
```
or to just download the first 200 publications, you can set the 'retMax' argument to 200
```r
pubs <- orgMetrics("2019", retMax = 200, outfile = "org_metrics.txt")
```
Two other arguments to the `orgMetrics()` function to be aware of are `schema` and `esci`. The `schema` argument allows you to change the subject category schema from the default Web of Science categories `schema = "wos"` to a different schema like the new citation topics schema `schema = "ct"`. A full list of the available schema and their input values is available from the Developer Portal. The `esci` argument allows you to decide whether or not to include citations from the Emerging Sources Citation Index in the returned metrics. The function defaults to "y" to include them, but to exclude these citations, use `esci = "n"`. 

## Requesting Data for a Set of UTs

Requesting data for a known set of publications by their WOS accession number, or UT number, is done with the `searchByUT()` function. The main argument to the function is a vector of UT numbers for the set of publications you want indicators for. The `schema` and `esci` arguments from the `orgMetrics()` function are also available here. So to request InCites indicators for a set of UT numbers named "myIDs", simply run 
```r
pubs <- searchByUT(myIDs, outfile = "pub_metrics.txt")
```
Or to request the indicators for these publications using the Citation Topics schema, run 
```r
pubs <- searchByUT(myIDs, schema = "ct", outfile = "pub_metrics.txt")
```
## Working with the Results

Both the `orgMetrics()` and `searchByUT()` functions will loop through the results to download all of the available publications (or until the `retMax` argument is reached in the `orgMetrics()` function), save the resulting JSON to the file specified in the `outfile` argument, and then parse the resulting JSON to a usable format in R. 

The structure of the results will vary depending on the `schema` requested. For subject category schema in which publications can only belong to a single subject category, like the Essential Science Indicators schema, the results will be a single data frame containing all the results. For schema in which publications can belong to multiple subject categories, the API returns all of the percentile values for all of the subject categories that each publication belongs to, so the results will be a list of two data frames. The first data frame, `pubs$pubData`, contains the non-percentile indicators for the requested publications and the second, `pubs$percentileData`, contains the percentile rank information.

This structure allows you flexibility in how you would like to combine the percentile rank data for multi-category publications. Following the recommendations in the bibliometrics literature, you could take the mean of the assigned categories by doing something like 
```r
mPerc <- sapply(split(pubs$percentileData$CAT_PERC, pubs$percentileData$ACCESSION_NUMBER), mean, na.rm = TRUE)
mPerc <- data.frame(ACCESSION_NUMBER = names(mPerc), mean_percentile = mPerc)
finPubs <- merge(pubs$pubData, mPerc, by = "ACCESSION_NUMBER")
```
Or, following the current InCites web interface, you could chose the percentile rank for the category in which the article scores best 
```r
mPerc <- pubs$percentileData[pubs$percentileData$IS_BEST == "true",]
finPubs <- merge(pubs$pubData, mPerc, by = "ACCESSION_NUMBER")
```
For the Citation Topics schema, the API returns indicators at all three levels of aggregation (micro, meso, and macro), so you can choose which level of aggregation you wish to see the indicators for. So to chose indicators at the meso level, you could do
```r
mPerc <- pubs$percentileData[pubs$percentileData$LEVEL == "2",]
finPubs <- merge(pubs$pubData, mPerc, by = "ACCESSION_NUMBER")
```
In any of these cases, the `finPubs` data frame contains all of the InCites indicators returned for the requested publications in a flat format, which you can analyze or save as you would any other data frame in R.
