# incites_api
R functions to work with the InCites API

## Overview
inCites_api is a set of functions to allow you to work with version 2 of the InCites API from Clarivate Analytics in the R programming language. The API allows you to either request indicators for all publications from your institution starting from a specific year or to request indicators for a specific set of Web of Science accession numbers (or UT numbers). These two options are implemented in the inCites_api package in the orgMetrics() and searchByUT() functions, respectively. 

To use these functions, you or your organization must have a current subscription to the InCites database that includes access to the InCites API. You must also obtain an API key from the Clarivate Analytics Developer Portal at https://developer.clarivate.com/. You must also have the httr and jsonlite packages installed in your local version of R. Both packages are contained in the tidyverse, so you probably already have them, but it's worth double-checking to be sure. 

## Setting Up
First, download and save the incites_api.r file to your computer in a place that you can find it. Then get your API Key from the Developer Portal and save it somewhere secure.

Once you have your API key, you need to store it in a place that these functions can find. Rather than passing it in as an argument, which you might inadvertantly share with others when sharing code, the inCites_api package contains a helper function, setInCitesKey(), to store your API key in your .Renviron file. This file allows you to create a custom set of environment variables every time R starts, so it's handy for storing things like API keys. 

To do so, start R and then load the .r file with source()

    source("./incites_api.r")
    
Then, use the setInCitesKey() function to save the key to your .Renviron file

    setInCitesKey("[yourkey]")
    
replacing the [yourkey] text with your API key. You should then get a message saying that your key was successfully stored and to restart R for the change to take effect. So restart R and you should be good to go. Every time you start R from now until you update R, your key will be available in your R session. The inCites_api package also has a convenience function, getInCitesKey(), to have R print out your key for you by simply running

    getInCitesKey()
    
Be aware, though, that your .Renviron file might get erased when you update your version of R, so make sure you have your key available somewhere else. And if, after you update R and try to run other functions in this package, you get an error message saying that the "INCITES_API_KEY" variable does not exist, run the setInCitesKey() function again to store it, restart R, and then you should be fine. 

## Requesting Data for your Organization

xxx

## Requesting Data for a Set of UTs

xxx

## Working with the Results
