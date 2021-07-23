#version 0.2
setInCitesKey <- function(yourKey) {
	if (file.exists(paste0(Sys.getenv("HOME"), "/.Renviron")) == FALSE) { ## if .Renviron file does not exist, create it and store the key to it
		theEnv <- paste0("INCITES_API_KEY = \"", yourKey,"\"")
		writeLines(theEnv, con = paste0(Sys.getenv("HOME"), "/.Renviron"))
	}
	else if (nchar(Sys.getenv("INCITES_API_KEY")) > 0) { ## if the file exists, and already has a key set, stop
		stop(paste("Your INCITES_API_KEY already exists. It is", Sys.getenv("INCITES_API_KEY")))
	}
	else {
	theEnv <- scan(paste0(Sys.getenv("HOME"), "/.Renviron"), what = "varchar", sep = "\n", quiet = TRUE) ## if the file exists, but doesn't have a key, set it and then re-save the file 
	theEnv <- c(theEnv, paste0("INCITES_API_KEY = \"", yourKey,"\""))
	theEnv <- paste(theEnv, collapse = "\n")
	writeLines(theEnv, con = paste0(Sys.getenv("HOME"), "/.Renviron"))
	}
	message(paste0("InCites API Key successfully saved to ", Sys.getenv("HOME"), "/.Renviron. Please restart R for the change to take effect."))
}

getInCitesKey <- function(yourKey) {
	Sys.getenv("INCITES_API_KEY")
}

lastUpdated <- function(x) {
	myKey <- Sys.getenv("INCITES_API_KEY")
	theURL <- httr::GET("https://api.clarivate.com/api/incites/InCitesLastUpdated/json", httr::add_headers("X-ApiKey" = myKey))
	httr::stop_for_status(theURL)
	theData <- httr::content(theURL, as = "text")
	theData <- jsonlite::fromJSON(theData)
	theDate <- theData$api$rval[[1]]
	return(theDate)
}

orgPubCount <- function(startYear) {
	myKey <- Sys.getenv("INCITES_API_KEY")
	theURL <- httr::GET("https://api.clarivate.com/api/incites/DocumentLevelMetricsByInstitutionIdRecordCount/json", httr::add_headers("X-ApiKey" = myKey), query = list(year = startYear))
	httr::stop_for_status(theURL)
	theData <- httr::content(theURL, as = "text")
	theData <- jsonlite::fromJSON(theData)
	resultCount <- as.numeric(theData$api$rval)
	return(resultCount)
}

orgMetrics <- function(startYear, ver = 2, schema = "wos", esci = "y", numrecs = 100, startRec = 1, retMax = Inf, parsed = TRUE, outfile) {
	myKey <- Sys.getenv("INCITES_API_KEY")
	validSchema <- c("anvur", "for1", "for2", "capesl1", "capesl2", "capesl3", "ct", "scadcl1", "scadcl2", "esi", "fapesp", "gipp", "kakenl2", "kakenl3", "oecd", "pl19", "ris3", "ref2008", "ref2014", "ref2021", "wos")
	if (!schema %in% validSchema) {
		stop(c("Invalid schema. Valid schema values are: ", paste0(sort(validSchema), collapse = ", ")))
	}
	theURL <- httr::GET("https://api.clarivate.com/api/incites/DocumentLevelMetricsByInstitutionIdRecordCount/json", httr::add_headers("X-ApiKey" = myKey), query = list(year = startYear))
	if (httr::http_error(theURL) == TRUE) { 
		print("Encountered an HTTP error. Details follow.") 
		print(httr::http_status(theURL)) 
		break
	}
	theData <- httr::content(theURL, as = "text")
	theData <- jsonlite::fromJSON(theData)
	resultCount <- as.numeric(theData$api$rval)
	print(paste("Retrieving", resultCount, "records."))
	retrievedCount <- 0
	theJ <- list()
	## loop to request metrics
	while (retrievedCount < resultCount && retrievedCount < retMax) {
		theURL <- httr::GET("https://api.clarivate.com/api/incites/DocumentLevelMetricsByInstitutionId/json", httr::add_headers("X-ApiKey" = myKey), query = list(year = startYear, ver = ver, schema = schema, esci = esci, recordcount = numrecs, startingrecord = startRec))
		if (httr::http_error(theURL) == TRUE) { 
			print("Encountered an HTTP error. Details follow.") 
			print(httr::http_status(theURL)) 
			break
		}
		theJ[[length(theJ) + 1]] <- httr::content(theURL, as = "text")
		retrievedCount <- retrievedCount + numrecs
		startRec <- startRec + numrecs
		print(paste("Retrieved", retrievedCount, "of", resultCount, "records. Getting more."))
		Sys.sleep(1)
	}
	print(paste("Retrieved", retrievedCount, "records. Formatting and saving results."))
	writeLines(unlist(theJ), con = outfile)
	if (parsed == FALSE) {
		return(theJ)
	}
	else {
	theData <- lapply(theJ, jsonlite::fromJSON)
	theData <- lapply(1:length(theData), function(x) theData[[x]]$api$rval[[1]])
	theData <- theData[which(sapply(theData, is.data.frame) == TRUE)]
	oaflag <- lapply(1:length(theData), function(x) theData[[x]]$OPEN_ACCESS$OA_FLAG)
	oatype <- lapply(1:length(theData), function(x) theData[[x]]$OPEN_ACCESS$STATUS)
	oatype <- lapply(1:length(oatype), function(x) sapply(1:length(oatype[[x]]), function(y) oatype[[x]][y][[1]]$TYPE))
	oatype <- lapply(1:length(oatype), function(x) sapply(oatype[[x]], paste, collapse = ";"))
	theData <- lapply(1:length(theData), function(x) theData[[x]][,which(colnames(theData[[x]]) != "OPEN_ACCESS")])
	theData <- lapply(1:length(theData), function(x) cbind(theData[[x]], "oaflag" = oaflag[[x]], stringsAsFactors = FALSE))
	theData <- lapply(1:length(theData), function(x) cbind(theData[[x]], "oatype" = oatype[[x]], stringsAsFactors = FALSE))
	percs <- lapply(1:length(theData), function(x) theData[[x]]$PERCENTILE)
	for (i in 1:length(percs)) {
		percs[[i]][sapply(percs[[i]], is.data.frame) == FALSE] <- replicate(length(percs[[i]][sapply(percs[[i]], is.data.frame) == FALSE]), data.frame(CODE = NA, CAT_PERC = NA, stringsAsFactors = FALSE), simplify = FALSE)
	}
	## test to see if any of the pubs has more than one subject category; if it does, create a list to store the different data frames
	if (any(lapply(1:length(percs), function(x) mean(sapply(percs[[x]][which(sapply(percs[[x]], class) == "data.frame")], nrow), na.rm = TRUE)) > 1) == TRUE) {
		percs <- lapply(1:length(percs), function(x) mapply(cbind, percs[[x]], "ACCESSION_NUMBER" = theData[[x]]$ACCESSION_NUMBER, SIMPLIFY = FALSE, stringsAsFactors = FALSE))
		percs <- lapply(1:length(percs), function(x) do.call(plyr::rbind.fill, percs[[x]]))
		percs <- do.call(rbind, percs)
		percs[,c(2,4,6)] <- sapply(c(2,4,6), function(x) as.numeric(percs[,x]))
		percs$ACCESSION_NUMBER <- paste0("WOS:", percs$ACCESSION_NUMBER)
		theData <- lapply(1:length(theData), function(x) theData[[x]][,which(colnames(theData[[x]]) != "PERCENTILE")])
		theData <- do.call(rbind, theData)
		theData$ACCESSION_NUMBER <- paste0("WOS:", theData$ACCESSION_NUMBER)
		theData$oatype[theData$oatype == ""] <- NA
		numCols <- c("IS_INTERNATIONAL_COLLAB", "TIMES_CITED", "JOURNAL_EXPECTED_CITATIONS", "IMPACT_FACTOR", "JNCI", "IS_INDUSTRY_COLLAB", "IS_INSTITUTION_COLLAB", "HARMEAN_CAT_EXP_CITATION", "AVG_CNCI", "ESI_HIGHLY_CITED_PAPER", "ESI_HOT_PAPER", "oaflag")
		theData[,numCols] <- sapply(numCols, function(x) as.numeric(theData[,x]))
		theData <- list(pubData = theData, percentileData = percs)
	}
	## if not, then put the results directly into the data frame
	else {
	subs <- lapply(1:length(theData), function(x) sapply(1:nrow(theData[[x]]), function(y) theData[[x]]$PERCENTILE[[y]]$SUBJECT))
	subs <- lapply(1:length(subs), function(x) sapply(subs[[x]], function(y) ifelse(is.null(y), NA, y)))
	sub_perc <- lapply(1:length(theData), function(x) sapply(1:nrow(theData[[x]]), function(y) theData[[x]]$PERCENTILE[[y]]$CAT_PERC))
	sub_perc <- lapply(1:length(sub_perc), function(x) sapply(sub_perc[[x]], function(y) ifelse(is.null(y), NA, y)))
	sub_cnci <- lapply(1:length(theData), function(x) sapply(1:nrow(theData[[x]]), function(y) theData[[x]]$PERCENTILE[[y]]$CNCI))
	sub_cnci <- lapply(1:length(sub_cnci), function(x) sapply(sub_cnci[[x]], function(y) ifelse(is.null(y), NA, y)))
	sub_exp_cites <- lapply(1:length(theData), function(x) sapply(1:nrow(theData[[x]]), function(y) theData[[x]]$PERCENTILE[[y]]$CAT_EXP_CITATION))
	sub_exp_cites <- lapply(1:length(sub_exp_cites), function(x) sapply(sub_exp_cites[[x]], function(y) ifelse(is.null(y), NA, y)))	
	theData <- lapply(1:length(theData), function(x) theData[[x]][,which(colnames(theData[[x]]) != "PERCENTILE")])
	theData <- lapply(1:length(theData), function(x) cbind(theData[[x]], "subject" = subs[[x]], stringsAsFactors = FALSE))
	theData <- lapply(1:length(theData), function(x) cbind(theData[[x]], "expected_cites" = sub_exp_cites[[x]], stringsAsFactors = FALSE))
	theData <- lapply(1:length(theData), function(x) cbind(theData[[x]], "percentile" = sub_perc[[x]], stringsAsFactors = FALSE))
	theData <- lapply(1:length(theData), function(x) cbind(theData[[x]], "cnci" = sub_cnci[[x]], stringsAsFactors = FALSE))
	theData <- do.call(rbind, theData)
	numCols <- c("IS_INTERNATIONAL_COLLAB", "TIMES_CITED", "JOURNAL_EXPECTED_CITATIONS", "IMPACT_FACTOR", "JNCI", "IS_INDUSTRY_COLLAB", "IS_INSTITUTION_COLLAB", "HARMEAN_CAT_EXP_CITATION", "AVG_CNCI", "ESI_HIGHLY_CITED_PAPER", "ESI_HOT_PAPER", "oaflag")
	theData[,numCols] <- sapply(numCols, function(x) as.numeric(theData[,x]))
	theData$ACCESSION_NUMBER <- paste0("WOS:", theData$ACCESSION_NUMBER)
	theData$oatype[theData$oatype == ""] <- NA
	}
	}
	print("Done")
	return(theData)
}

searchByUT <- function(utList, ver = 2, schema = "wos", esci = "y", parsed = TRUE, outfile) {
	myKey <- Sys.getenv("INCITES_API_KEY")
	validSchema <- c("anvur", "for1", "for2", "capesl1", "capesl2", "capesl3", "ct", "scadcl1", "scadcl2", "esi", "fapesp", "gipp", "kakenl2", "kakenl3", "oecd", "pl19", "ris3", "ref2008", "ref2014", "ref2021", "wos")
	if (!schema %in% validSchema) {
		stop(c("Invalid schema. Valid schema values are: ", paste0(sort(validSchema), collapse = ", ")))
	}
	theIDs <- unique(as.character(utList))
	resultCount <- as.numeric(length(theIDs))
	idList <- split(theIDs, ceiling(seq_along(theIDs)/100))
	idList <- gsub("WOS:", "", lapply(idList, paste0, collapse = ","))
	print(paste("Retrieving", resultCount, "records."))
	theData <- list()
	retrievedCount <- 0
	for (i in 1:length(idList)) {
		string <- idList[i]
		theURL <- httr::GET("https://api.clarivate.com/api/incites/DocumentLevelMetricsByUT/json", httr::add_headers("X-ApiKey" = myKey), query = list(UT = string, ver = ver, schema = schema, esci = esci))
		if (httr::http_error(theURL) == TRUE) { 
			print("Encountered an HTTP error. Details follow.") 
			print(httr::http_status(theURL)) 
			break
		}
	theData[[i]] <- httr::content(theURL, as = "text")
	Sys.sleep(1)
	retrievedCount <- retrievedCount + 100
	print(paste("Retrieved", retrievedCount, "of", resultCount, "records. Getting more."))
	}
	print(paste("Retrieved", retrievedCount, "records. Formatting and saving results."))
	writeLines(unlist(theData), outfile)
	if (parsed == FALSE) {
		return(theData)
	}
	else {
	theData <- lapply(theData, jsonlite::fromJSON)
	theData <- lapply(1:length(theData), function(x) theData[[x]]$api$rval[[1]])
	theData <- theData[which(sapply(theData, is.data.frame) == TRUE)]
	oaflag <- lapply(1:length(theData), function(x) theData[[x]]$OPEN_ACCESS$OA_FLAG)
	oatype <- lapply(1:length(theData), function(x) theData[[x]]$OPEN_ACCESS$STATUS)
	oatype <- lapply(1:length(oatype), function(x) sapply(1:length(oatype[[x]]), function(y) oatype[[x]][y][[1]]$TYPE))
	oatype <- lapply(1:length(oatype), function(x) sapply(oatype[[x]], paste, collapse = ";"))
	theData <- lapply(1:length(theData), function(x) theData[[x]][,which(colnames(theData[[x]]) != "OPEN_ACCESS")])
	theData <- lapply(1:length(theData), function(x) cbind(theData[[x]], "oaflag" = oaflag[[x]], stringsAsFactors = FALSE))
	theData <- lapply(1:length(theData), function(x) cbind(theData[[x]], "oatype" = oatype[[x]], stringsAsFactors = FALSE))
	percs <- lapply(1:length(theData), function(x) theData[[x]]$PERCENTILE)
	for (i in 1:length(percs)) {
		percs[[i]][sapply(percs[[i]], is.data.frame) == FALSE] <- replicate(length(percs[[i]][sapply(percs[[i]], is.data.frame) == FALSE]), data.frame(CODE = NA, CAT_PERC = NA, stringsAsFactors = FALSE), simplify = FALSE)
	}
	## test to see if any of the pubs has more than one subject category; if it does, create a list to store the different data frames
	if (any(lapply(1:length(percs), function(x) mean(sapply(percs[[x]][which(sapply(percs[[x]], class) == "data.frame")], nrow), na.rm = TRUE)) > 1) == TRUE) {
		percs <- lapply(1:length(percs), function(x) mapply(cbind, percs[[x]], "ACCESSION_NUMBER" = theData[[x]]$ACCESSION_NUMBER, SIMPLIFY = FALSE, stringsAsFactors = FALSE))
		percs <- lapply(1:length(percs), function(x) do.call(plyr::rbind.fill, percs[[x]]))
		percs <- do.call(rbind, percs)
		percs[,c(2,4,6)] <- sapply(c(2,4,6), function(x) as.numeric(percs[,x]))
		percs$ACCESSION_NUMBER <- paste0("WOS:", percs$ACCESSION_NUMBER)
		theData <- lapply(1:length(theData), function(x) theData[[x]][,which(colnames(theData[[x]]) != "PERCENTILE")])
		theData <- do.call(rbind, theData)
		theData$ACCESSION_NUMBER <- paste0("WOS:", theData$ACCESSION_NUMBER)
		theData$oatype[theData$oatype == ""] <- NA
		numCols <- c("IS_INTERNATIONAL_COLLAB", "TIMES_CITED", "JOURNAL_EXPECTED_CITATIONS", "IMPACT_FACTOR", "JNCI", "IS_INDUSTRY_COLLAB", "IS_INSTITUTION_COLLAB", "HARMEAN_CAT_EXP_CITATION", "AVG_CNCI", "ESI_HIGHLY_CITED_PAPER", "ESI_HOT_PAPER", "oaflag")
		theData[,numCols] <- sapply(numCols, function(x) as.numeric(theData[,x]))
		theData <- list(pubData = theData, percentileData = percs)
	}
	## if not, then put the results directly into the data frame
	else {
	subs <- lapply(1:length(theData), function(x) sapply(1:nrow(theData[[x]]), function(y) theData[[x]]$PERCENTILE[[y]]$SUBJECT))
	subs <- lapply(1:length(subs), function(x) sapply(subs[[x]], function(y) ifelse(is.null(y), NA, y)))
	sub_perc <- lapply(1:length(theData), function(x) sapply(1:nrow(theData[[x]]), function(y) theData[[x]]$PERCENTILE[[y]]$CAT_PERC))
	sub_perc <- lapply(1:length(sub_perc), function(x) sapply(sub_perc[[x]], function(y) ifelse(is.null(y), NA, y)))
	sub_cnci <- lapply(1:length(theData), function(x) sapply(1:nrow(theData[[x]]), function(y) theData[[x]]$PERCENTILE[[y]]$CNCI))
	sub_cnci <- lapply(1:length(sub_cnci), function(x) sapply(sub_cnci[[x]], function(y) ifelse(is.null(y), NA, y)))
	sub_exp_cites <- lapply(1:length(theData), function(x) sapply(1:nrow(theData[[x]]), function(y) theData[[x]]$PERCENTILE[[y]]$CAT_EXP_CITATION))
	sub_exp_cites <- lapply(1:length(sub_exp_cites), function(x) sapply(sub_exp_cites[[x]], function(y) ifelse(is.null(y), NA, y)))	
	theData <- lapply(1:length(theData), function(x) theData[[x]][,which(colnames(theData[[x]]) != "PERCENTILE")])
	theData <- lapply(1:length(theData), function(x) cbind(theData[[x]], "subject" = subs[[x]], stringsAsFactors = FALSE))
	theData <- lapply(1:length(theData), function(x) cbind(theData[[x]], "expected_cites" = sub_exp_cites[[x]], stringsAsFactors = FALSE))
	theData <- lapply(1:length(theData), function(x) cbind(theData[[x]], "percentile" = sub_perc[[x]], stringsAsFactors = FALSE))
	theData <- lapply(1:length(theData), function(x) cbind(theData[[x]], "cnci" = sub_cnci[[x]], stringsAsFactors = FALSE))
	theData <- do.call(rbind, theData)
	numCols <- c("IS_INTERNATIONAL_COLLAB", "TIMES_CITED", "JOURNAL_EXPECTED_CITATIONS", "IMPACT_FACTOR", "JNCI", "IS_INDUSTRY_COLLAB", "IS_INSTITUTION_COLLAB", "HARMEAN_CAT_EXP_CITATION", "AVG_CNCI", "ESI_HIGHLY_CITED_PAPER", "ESI_HOT_PAPER", "oaflag")
	theData[,numCols] <- sapply(numCols, function(x) as.numeric(theData[,x]))
	theData$ACCESSION_NUMBER <- paste0("WOS:", theData$ACCESSION_NUMBER)
	theData$oatype[theData$oatype == ""] <- NA
	}
	print("Done")
	return(theData)
	}
} 

### calculate mean percentile for each paper for papers with multiple categories
### mPerc <- sapply(split(test1$percentileData$CAT_PERC, test1$percentileData$ACCESSION_NUMBER), mean, na.rm = TRUE)
### mPerc <- data.frame(ACCESSION_NUMBER = names(mPerc), mean_percentile = mPerc)
### finPubs <- merge(test1$pubData, mPerc, by = "ACCESSION_NUMBER")

### use best subject category for each paper
### pubDat2 <- test1$percentileData[test1$percentileData$IS_BEST == "true",]
### finPubs2 <- merge(test1$pubData, pubDat2, by = "ACCESSION_NUMBER")