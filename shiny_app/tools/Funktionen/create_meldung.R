### Read environment
readRenviron("~/.Renviron")

create_meldung <- function(title, text, company = "", sprache="de", code=c("NEW"), name="generic", Wire = c("P"), 
                           path = "" , modus="Withheld", server="test", byline=NULL, country=c("CH"), hint="T") {
  ## title: String for Headline
  ## text: String for Body
  ## company: String or list of Strings for companies to tag
  ## sprache: String for language, "de" default or "fr", "it"
  ## code: list of subjects to tag, usually three characters (ERN, MNA, MGT, ...)
  ## name: String for name of the process, optional, xml-files can be attributed easier
  ## Wire: list of wires, "P" as default
  ## Path: Optional, String for folder to save xml-file in. Default: Looks for Folder named "Output" 
  ## Modus: "Withheld" default or "Usable" (published for review or directly) 
  ## Server: "Test" default or "live"
  ## byline: String for Byline
  ## country: list of country codes
  ## hint: string, "T" as default
  
  library(readr)
  library(RCurl)
  library(stringr)
  
  source("./tools/Funktionen/Utils.R")
  
  #Meldung erzeugen 
  date_and_time <- format(Sys.time(), "%Y%m%dT%H%M%S%z")
  
  #ID erzeugen
  ID <- get_ID()
  
  #Vorlage laden
  vorlage <- read_file("./tools/Vorlage_XML/Vorlage_XML_byline_country_wires.txt")
  
  #Subjects einfügen  
  subjects <- ""
  for (i in 1:length(code)) {
    subjects <- paste0(subjects, '<Property FormalName="Subject" Value="', code[i], '"/>')
  }
  
  #countries einfügen
  countries <- ""
  if (!is.null(country) && !country == "") {
    for (i in 1:length(country)) {
      countries <- paste0(countries, '<Property FormalName="Country" Value="', country[i], '"/>')
    }
  } else {
    countries <- '<Property FormalName="Country" Value="CH"/>'
  }
  
  #channels einfügen
  wires <- ""
  for (i in 1:length(Wire)) {
    wires <- paste0(wires, '<Property FormalName="Wire" Value="', Wire[i], '"/>')
  }
  
  #companies einfügen
  companies <- ""
  for (i in 1:length(company)) {
    company[i] <- replace_special_chars(company[i])
    companies <- paste0(companies, '<Property FormalName="FullName" Value="', company[i],'" />')
  }
  
  #Byline
  if (is.null(byline)) {
    byline <- ""
  }
  
  ###Daten einfügen
  vorlage <- str_replace_all(vorlage, "Insert_DateAndTime",date_and_time)
  vorlage <- str_replace_all(vorlage, "Insert_ID",as.character(ID))
  vorlage <- str_replace_all(vorlage, "Insert_Status",modus)
  vorlage <- str_replace_all(vorlage, "Insert_Storytype",hint)
  vorlage <- str_replace_all(vorlage, "Insert_Language",sprache)
  vorlage <- str_replace_all(vorlage, "Insert_Countries",countries)
  vorlage <- str_replace_all(vorlage, "Insert_Companies",companies)
  vorlage <- str_replace_all(vorlage, "Insert_Wires",wires)
  vorlage <- str_replace_all(vorlage, "Insert_Relations",subjects)
  vorlage <- str_replace_all(vorlage, "Insert_Byline",byline)
  
  #Titel und Text einfügen
  title <- replace_special_chars(title)
  text <- replace_special_chars(text)
  vorlage <- str_replace_all(vorlage,"Insert_Headline",title)
  vorlage <- str_replace_all(vorlage,"Insert_Text",text)
  
  #Datei speichern
  if (path == "") {
    if (!grepl("Output", getwd())) {
      setwd("./Output")
    }
  } else {
    setwd(path)
  }
  firmenname <- unlist(str_split(title, ":? "))[1]
  xmlfilename <- paste0(date_and_time,"_", name, "_", firmenname, "_d.xml")
  xmlfile <- file(xmlfilename, encoding="iso-8859-1")
  cat(vorlage,file=xmlfile)
  
  ###FTP-Upload
  #ID wird im Namen für xml-File auf Server gebraucht, damit die Files nicht aus Versehen blockiert werden aufgrund des gleichen Namens
  if (server == "test") {
    ftpUpload(xmlfilename, paste0("ftp://ftp2.awp.ch/",name, ID, "_d"),userpwd=Sys.getenv("ftp_awp_test"))
  } else {
    ftpUpload(xmlfilename, paste0("ftp://ftp.awp.ch/",name, ID, "_d"),userpwd=Sys.getenv("ftp_awp"))
  }
  
  close(xmlfile)
}

