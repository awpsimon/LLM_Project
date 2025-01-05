loadCompany <- function(company_id_bw2, db_masterdata){
  
  ########################
  ## Function purpose: Get company choice(s) according to search string
  ##
  ## Input
  ## company_id_bw2: string
  ## db_masterdata: db conn
  ##
  ## Return
  ## companies: Vector with company choices
  ########################
  
  companies <- c("Keine Firma gewählt" = NA)
  
  if (!is.null(company_id_bw2) && startsWith(company_id_bw2, "-")) {
    
    # Set field selection
    fields <- "ID, Name, Ort, SDA "
    
    # Search with company ID
    sqlstr <- paste0("SELECT ", fields,
                     "FROM masterdata.companies ",
                     "WHERE ID = '", company_id_bw2, "'",
                     " ORDER BY Name;")
    comp_data <- dbGetQuery(db_masterdata, sqlstr)
    
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