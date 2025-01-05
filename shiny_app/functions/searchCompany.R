searchCompany <- function(search_string, db_masterdata){
  
  ########################
  ## Function purpose: Get company choice(s) according to search string
  ##
  ## Input
  ## search_string: string
  ## db_masterdata: db conn
  ##
  ## Return
  ## companies: Vector with company choices
  ########################
  
  companies <- c("Keine Firma gewählt" = NA)
  
  if (!is.null(search_string) && search_string != "") {
    
    # Set field selection
    fields <- "ID, Name, Ort, SDA "
    
    # Replace star wildcard with equivalent for SQL
    search_string <- str_replace_all(search_string, "\\*", "%")
      
    # Search in tickers
    sqlstr <- paste0("SELECT ", fields,
                     "FROM masterdata.companies ",
                     "WHERE Ticker LIKE '%", search_string, "%'",
                     " ORDER BY Name;")
    comp_data <- dbGetQuery(db_masterdata, sqlstr)
    
    
    # Search in Kurzname
    if (nrow(comp_data) != 1) {
      
      sqlstr <- paste0("SELECT ", fields,
                       "FROM masterdata.companies ",
                       "WHERE Name LIKE '", search_string, "%'",
                       " ORDER BY Name;")
      comp_data <- dbGetQuery(db_masterdata, sqlstr)
      
    }
    
    # Prepare choices from SQL result
    if (nrow(comp_data) > 0) {
      companies <- c()
      for (i in 1:nrow(comp_data)) {
        companies[paste0(comp_data[i,]$Name, ", ", comp_data[i,]$Ort)] <- comp_data[i,]$ID
      }
    }
    
  }

  return(companies)
  
}