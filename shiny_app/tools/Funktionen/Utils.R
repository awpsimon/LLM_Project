# *** Allgemeine Funktionen (thematisch/alphabetisch geordnet) *** 
#   * DB
#     - connectDB
#     - dbDisconnectAll
#     - quote_str
#   * FTP
#     - retry
#   * Google Drive
#     - driveAuth
#   * Mail
#     - send_notification
#     - send_attachment
#     - send_html_notification
#   * Mathe 
#     - round2
#   * Meldungen
#     - get_ID
#     - number_to_string
#     - translate_month
#     - replace_special_chars
#     - plainText_to_htmlText

###### DB #######

### Read environment
readRenviron("~/.Renviron")

# DB-Verbindung
connectDB <- function(dbuser='auto1', dbpassword=Sys.getenv("db_auto1"), db_name = '') {
  library(DBI)
  library(RMySQL)
  mydb <- dbConnect(MySQL(), user=dbuser, password=dbpassword, dbname=db_name, host='185.101.156.105')
  return(mydb)
}

### DB-Verbindungen trennen
dbDisconnectAll <- function(){
  ile <- length(dbListConnections(MySQL())  )
  lapply( dbListConnections(MySQL()), function(x) dbDisconnect(x) )
  cat(sprintf("%s connection(s) closed.\n", ile))
}

### String in einfache Anführungszeichen einbetten 
quote_str <- function(string) {
  result <- paste0("\'", string, "\'")
  return(result)
}

###### FTP ########


###Funktion für Retry beim Upload
retry <- function(expr, isError=function(x) "try-error" %in% class(x), maxErrors=5, sleep=0) {
  library(futile.logger)
  attempts = 0
  retval = try(eval(expr))
  while (isError(retval)) {
    attempts = attempts + 1
    if (attempts >= maxErrors) {
      msg = sprintf("retry: too many retries [[%s]]", capture.output(str(retval)))
      flog.fatal(msg)
      stop(msg)
    } else {
      msg = sprintf("retry: error in attempt %i/%i [[%s]]", attempts, maxErrors, 
                    capture.output(str(retval)))
      flog.error(msg)
      warning(msg)
    }
    if (sleep > 0) Sys.sleep(sleep)
    retval = try(eval(expr))
  }
  return(retval)
}

##### GOOGLEDRIVE #######

### Authentifizierung für Google-Drive
driveAuth <- function() {
  library(googledrive)
  
  drive_auth(
    email = "robot.awp@gmail.com",
    path = NULL,
    scopes = "https://www.googleapis.com/auth/drive",
    cache = gargle::gargle_oauth_cache(),
    use_oob = gargle::gargle_oob_default(),
    token = NULL
  )
}


##### MAIL #######

send_notification <- function (subject, nbody, recipients = "robot-notification@awp.ch") {
  ########################
  ## Function purpose: Send an email
  ## Important to know: If email is down, use one of the commented out alternatives
  ## 
  ## Input
  ## subject: String for email-Subject 
  ## body: String for email-body 
  ## recipients: String for email-recipients. You can use multiple recipients by separating them with a comma "test@test.ch, test2@test2.ch" 
  ##  
  ## Return
  ## result: Mail is sent
  ########################
  
  library(mailR)
  
  send.mail(from = "robot-notification@awp.news",
            to = unlist(strsplit(recipients, ",\\s?")),
            subject = subject,
            body = nbody,
            smtp = list(host.name = "ms7smtp.webland.ch", port = 465, user.name = "robot-notification@awp.news", passwd = Sys.getenv("mail"), ssl = TRUE),
            authenticate = TRUE,
            send = TRUE)
  
  ### Alternative BW2
  # send.mail(from = "robot-notification@awp.ch",
  #           to = unlist(strsplit(recipients, ",\\s?")),
  #           subject = subject,
  #           body = nbody,
  #           smtp = list(host.name = "pop.businesswideweb.net", port = 465, user.name = "robot-notification@awp.ch", passwd = Sys.getenv("mail_bw2"), ssl = TRUE),
  #           authenticate = TRUE,
  #           send = TRUE)
  #
  ### Alternative Blatr
  #library(blatr)
  #
  # blat(f = "robot-notification@awp.news",
  #      to = recipients,
  #      s = subject,
  #      body = nbody,
  #      server = "ms7smtp.webland.ch",
  #      u = "robot-notification@awp.news",
  #      pw = Sys.getenv("mail")
  # )
  # 

}

send_attachment <- function (subject, nbody, attachment, recipients = "robot-notification@awp.ch") {
  ########################
  ## Function purpose: Send an email with one or more attachments
  ## Important to know: If email is down, use one of the commented out alternatives
  ## 
  ## Input
  ## subject: String for email-Subject 
  ## body: String for email-body 
  ## attachment: String/Vector of Strings for path to valid file to attach, for multiple files combine them into a list with c(). Example: c("pathToAttachment1", "pathToAttachment2")
  ## recipients: String for email-recipients. You can use multiple recipients by separating them with a comma "test@test.ch, test2@test2.ch" (with blatr only one attachment is sent)
  ##  
  ## Return
  ## result: Mail is sent
  ########################
  
  library(mailR)
  if (!is.null(attachment) & all(attachment != "") & all(sapply(attachment, function(x) file.exists(x)))) {
  
  send.mail(from = "robot-notification@awp.news",
            to = unlist(strsplit(recipients, ",\\s?")),
            subject = subject,
            body = nbody,
            attach.files = attachment,
            smtp = list(host.name = "ms7smtp.webland.ch", port = 465, user.name = "robot-notification@awp.news", passwd = Sys.getenv("mail"), ssl = TRUE),
            authenticate = TRUE,
            send = TRUE)
  
  ### Alternative BW2
  # send.mail(from = "robot-notification@awp.ch",
  #           to = unlist(strsplit(recipients, ",\\s?")),
  #           subject = subject,
  #           body = nbody,
  #           attach.files = attachment,
  #           smtp = list(host.name = "pop.businesswideweb.net", port = 465, user.name = "robot-notification@awp.ch", passwd = Sys.getenv("mail_bw2"), ssl = TRUE),
  #           authenticate = TRUE,
  #           send = TRUE)
  #
  ### Alternative Blatr
  # library(blatr)
  #   
  # if (length(attachment) > 1) {
  #   attachment <- attachment[1]
  #   print("Attention: Only first attachment was sent")
  # }
  # 
  # blat(f = "robot-notification@awp.news",
  #      to = recipients,
  #      s = subject,
  #      body = nbody,
  #      attach = attachment,
  #      server = "ms7smtp.webland.ch",
  #      u = "robot-notification@awp.news",
  #      pw = Sys.getenv("mail")
  # )
  # #
  } else {
    print("Please specify attachment for a valid file (=path to attached file) or use send_notification to send email without attachment")
  }
  
}

send_html_notification <- function (subject, htmlFilePath, recipients = "robot-notification@awp.ch") {
  ########################
  ## Function purpose: Send an email formatted with HTML
  ## Important to know: If email is down, use one of the commented out alternatives
  ## 
  ## Input
  ## subject: String for email-Subject 
  ## htmlFilePath: String for path to valid file with HTML-Formatted body
  ## recipients: String for email-recipients. You can use multiple recipients by separating them with a comma "test@test.ch, test2@test2.ch" (with blatr only one attachment is sent)
  ##  
  ## Return
  ## result: Mail is sent
  ########################
  
  library(readr)
  library(mailR)
  
  ## Make sure the encoding is right (needs to be latin1)
  htmlFileEncoding <- guess_encoding(htmlFilePath)$encoding[1]
  if (htmlFileEncoding == "ISO-8859-1") {
    htmlContent <- read_file(htmlFilePath)
    Encoding(htmlContent) <- "latin1"
    cat(htmlContent, file = file(htmlFilePath, encoding = "UTF-8"))
  }
  
  send.mail(from = "robot-notification@awp.news",
            to = unlist(strsplit(recipients, ",\\s?")),
            subject = subject,
            body = htmlFilePath,
            html = TRUE,
            inline = TRUE,
            smtp = list(host.name = "ms7smtp.webland.ch", port = 465, user.name = "robot-notification@awp.news", passwd = Sys.getenv("mail"), ssl = TRUE),
            authenticate = TRUE,
            send = TRUE)

  ### Alternative BW2
  # send.mail(from = "robot-notification@awp.ch",
  #           to = unlist(strsplit(recipients, ",\\s?")),
  #           subject = subject,
  #           body = htmlFilePath,
  #           html = TRUE,
  #           inline = TRUE,
  #           smtp = list(host.name = "pop.businesswideweb.net", port = 465, user.name = "robot-notification@awp.ch", passwd = Sys.getenv("mail_bw2"), ssl = TRUE),
  #           authenticate = TRUE,
  #           send = TRUE)
  #
  ### Alternative Blatr
  # library(blatr)
  # 
  # library(readr)
  # 
  # ## Make sure the encoding is right (needs to be latin1)
  # htmlFileEncoding <- guess_encoding(htmlFilePath)$encoding[1]
  # if (htmlFileEncoding == "UTF-8") {
  #   htmlContent <- read_file(htmlFilePath)
  #   cat(htmlContent, file = file(htmlFilePath, encoding = "latin1"))
  # }
  # 
  # blat(f = "robot-notification@awp.news",
  #      to = recipients,
  #      s = subject,
  #      filename = htmlFilePath,
  #      server = "ms7smtp.webland.ch",
  #      u = "robot-notification@awp.news",
  #      pw = Sys.getenv("mail")
  # )

}

##### MATHE ######

### kaufmännisches Runden
round2 = function(x, n = 0) {
  posneg = sign(x)
  z = abs(x)*10^n
  z = z + 0.5
  z = trunc(z)
  z = z/10^n
  z*posneg
}

###### MELDUNGEN #######
get_ID <- function() {
  ID <- read.delim("./tools/ID_Meldungen/ID_Meldungen.txt", header=FALSE)
  ID <- as.numeric(ID)
  ID_new <- ID+1
  cat(paste0(ID_new, "\n"), file="./tools/ID_Meldungen/ID_Meldungen.txt")
  return(ID)
}

#Zahl in String umwandeln
number_to_string <- function(number, nsmall=1, add_plus=TRUE) {
  string <- format(number, decimal.mark=",", nsmall=nsmall, big.mark="'")
  if (is.numeric(number) && !is.na(number)) {
    if (add_plus & number > 0) {
      string <- paste0("+", string)
    }
  }
  return(string)
}

#Englische Monatsnamen übersetzen
translate_month <- function(month,language) {
  
  if (language == "de") {
    month <- gsub("January","Januar",month)
    month <- gsub("February","Februar",month)
    month <- gsub("March","März",month)
    month <- gsub("May","Mai",month)
    month <- gsub("June","Juni",month)
    month <- gsub("July","Juli",month)
    month <- gsub("October","Oktober",month)
    month <- gsub("December","Dezember",month)
  } else if (language == "fr") {
    month <- gsub("January","Janvier",month)
    month <- gsub("February","Février",month)
    month <- gsub("March","Mars",month)
    month <- gsub("April","Avril",month)
    month <- gsub("May","Mai",month)
    month <- gsub("June","Juin",month)
    month <- gsub("July","Julliet",month)
    month <- gsub("August","Août",month)
    month <- gsub("September","Septembre",month)
    month <- gsub("October","Octobre",month)
    month <- gsub("November","Novembre",month)
    month <- gsub("December","Décembre",month)
  } else if (language == "it") {
    month <- gsub("January","gennaio",month)
    month <- gsub("February","febbraio",month)
    month <- gsub("March","marzo",month)
    month <- gsub("April","aprile",month)
    month <- gsub("May","maggio",month)
    month <- gsub("June","giugno",month)
    month <- gsub("July","luglio",month)
    month <- gsub("August","agosto",month)
    month <- gsub("September","settembre",month)
    month <- gsub("October","ottobre",month)
    month <- gsub("November","novembre",month)
    month <- gsub("December","dicembre",month)
  }  
  return(month)
}

replace_special_chars <- function(text) {
  ## @text: Text to be converted
  ## return: text with special characters &, <, > replaced with HTML entities
  
  library(stringr)
  
  text <- str_replace_all(text,"&(?!amp;|lt;|gt;)", "&amp;")
  text <- str_replace_all(text, "<(?!/?(p.*|h3|/)>)", "&lt;") 
  text <- str_replace_all(text,"(?<!\\</?(p.{0,3}|h3))>", "&gt;")
  return(text)
}

plainText_to_htmlText <- function(text_plain) {
  ########################
  ## Function purpose: Insert p-tags and remove special chars
  ##
  ## Input
  ## text_plain: String
  ##
  ## Return
  ## text_html: String
  ########################
  
  library(stringr)
  
  text_html <- ""
  if (text_plain != "") {
    paragraphs <- str_split(text_plain, "\n\n")[[1]]
    if (length(paragraphs > 0)) {
      for (i in 1:length(paragraphs)) {
        text_splitted <- str_split(paragraphs[i], "\n")[[1]]
        for (j in 1:length(text_splitted)) {
          text_splitted[j] <- paste0("<p>",
                                     replace_special_chars(trimws(
                                       text_splitted[j]
                                     )),
                                     "</p>")
        }
        paragraphs[i] <- paste0(text_splitted, collapse = "\n")
      }
      text_html <- paste0(paragraphs, collapse = "\n<p/>")
    }
  }
  return(text_html)
}