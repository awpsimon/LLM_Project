##########################
## Script purpose: View, edit and publish management changes messages
## Important to know: DB entries are written by Python process
##  
## Author
## name: Manuel Frick
## e-mail: mf@awp.ch
##
## R-Version: R version 4.2.1 (2022-06-23 ucrt)
##########################

##########################      
## Preparation          ##                
##########################

# Get PWs
readRenviron(".Renviron")

# Set timezone
Sys.setenv(TZ='CET')

# Load libraries
library(shiny)
library(DBI)
library(RMySQL)
library(pool)
library(shinyjs)
library(shinyalert)
library(shinyBS)
library(stringr)
library(shinybusy)
library(shinyvalidate)

# Remember initial working dir
wd_initial <- getwd()

# Load Functions
source("./tools/Funktionen/Utils.R")
source("./tools/Funktionen/create_meldung.R")
source("./functions/searchCompany.R")
source("./functions/loadCompany.R")
source("./functions/translateWithDeepL.R")

# Test-Switch
test <- FALSE

# Create DB pools
db_mgmt <- pool::dbPool(
  drv = RMySQL::MySQL(),
  dbname = "management",
  host = "185.101.156.105",
  username = "auto1",
  password = Sys.getenv("db_auto1")
)
onStop(function() {
  pool::poolClose(db_mgmt)
})
db_masterdata <- pool::dbPool(
  drv = RMySQL::MySQL(),
  dbname = "masterdata",
  host = "185.101.156.105",
  username = "auto1",
  password = Sys.getenv("db_auto1")
)
onStop(function() {
  pool::poolClose(db_masterdata)
})

# Create an event listener at <body> which fires as soon as the modal is shown
# sets the focus to the first input element
set_focus <- HTML("$('body').on('shown.bs.modal', (x) => 
                   $(x.target).find('input:first').focus())")

# Global vars
current_mail_parsing_time <- NULL
modus <- "Withheld"
translated <- FALSE


#######################
# Create UI-Function  #
#######################

ui <- fluidPage(

  useShinyjs(),
  add_busy_spinner(
    position="full-page",
    color = "#1377b9",
    spin = "dots"
  ),
  tags$head(
    tags$script(HTML(
      "Shiny.addCustomMessageHandler('setIframeSource', function(binaryData) {
        const blob = new Blob([binaryData], {type: 'text/html'});
        const iframe = document.getElementById('pdfviewer');
        iframe.src = URL.createObjectURL(blob);
      });")),
    tags$link(rel = "icon", type = "image/png", sizes = "32x32", href = "awp-webclip.png"),
    tags$style(HTML("
      @import url('https://fonts.googleapis.com/css?family=Lato');
      .awpbutton {
        background-color: #1377b9;
        color: white;
      }
      .awpheader {
        color: #1377b9;
        font-family: Lato, sans-serif;
        font-size: 2rem;
        font-weight: bold;
      }
      .cbcontainer {
        display: inline-block;
      }
      .checkbox {
       text-align: right;
       display: inline-block;
      }
      .checkbox input {
        float: right;
        position: relative !important;
        margin: 5px !important;
      }
      .checkbox label {
        padding-left: 0px !important;
      }
      .checkbox, .radio {
        margin-top: 5px;
        margin-bottom: 5px;
      }
      .awpsubtitle {
        color: #1377b9;
        font-family: Lato, sans-serif;
        font-weight: bold;
        font-size: 1.5rem;
      }
      .modal-lg {
        width: 70%;
      }
      .modal-footer {
        text-align: left;
        padding-top: 0px;
        padding-bottom: 15px;
        padding-left: 18px;
        padding-right: 15px;
        border-top: 0px;
      }
      #preview pre {
        white-space: pre-wrap;
        word-break: keep-all;
      }
      "))),
      tags$header(tags$script(type = "text/javascript", set_focus)),
  
  br(),
          
  
  tags$div(id = 'data_found',
           
  
    sidebarLayout(
      
      # Sidebar with a slider input
      sidebarPanel(
        width = 6,
        
        # Header
        div(
          "ORIGINAL",
          id = "original_header",
          class = "awpheader"
        ),
        br(),
        
        tabsetPanel(id = "tabset1",
                    tabPanel(title = "Artikel auf Französisch",
                             value = "tab1",
                             br(),
                             textInput(inputId="title_original", label="Titel", width="100%"),
                             textAreaInput(inputId="text_original", label="Text", width="100%", height = "553px"),
                    ),
                    tabPanel(title = "Mail",
                             value = "tab2",
                             br(),
                             
                             # Display of original mail
                             div(textOutput(outputId = "mail_subject"),
                                 style = "font-size: 1.5rem; color: #1377b9; font-weight: bold; border: 1px solid #D3D3D3; border-radius: 5px; padding: 6px; background-color: white;"),
                             br(),
                             tags$iframe(
                               id = "pdfviewer",
                               src = "",
                               width = "100%",
                               style = "border: none; height: 607px;",
                             )
                    )
        )
                    
      ), 
      
      # Show a plot of the generated distribution
      mainPanel(
        width = 6,
        
        # Header
        br(),
        fluidRow(
          column(12,
                 div(
                   "ARTIKEL-VORSCHLAG",
                   id = "draft_header",
                   class = "awpheader",
                   style="float: left;",
                 ),
                 div(
                   actionButton(
                     inputId="reload_1", 
                     label = "", 
                     icon = icon("arrows-rotate"), 
                     class = "awpbutton"
                   ), style="float: right;")),
                 bsTooltip(id = "reload_1", title = "Neu laden", 
                    placement = "left", trigger = "hover")
        ),
        
        br(),
        
        # Input
        textInput(inputId="title", label="Titel", width="100%"),
        textAreaInput(inputId="text", label="Text", width="100%", height = "570px"),

        
        # Wire & Company
        fluidRow(
          column(2, selectInput(inputId="wire_dropdown", label="Wire", choices=c("K", "P", "P + R"), width="100%")),
          column(1, ),
          column(3, textInput(inputId="company_search", label="Firmasuche", placeholder="Suchbegriff eingeben", width="100%")),
          column(1, div(actionButton(inputId="search_company", "",icon = icon("magnifying-glass", lib = "font-awesome")), style="margin-top: 25px;")),
          bsTooltip(id = "search_company", title = "Suchen", 
                    placement = "top", trigger = "hover"),
          column(5, selectInput(inputId="company_dropdown", label="Verknüpfung wählen", choices=c(), width="100%")),
        ),
        
        # Action buttons
        div(style = "display:inline-block; float:right", actionButton(inputId="publish", "Publizieren", class = "awpbutton")),
        div(style = "display:inline-block; float:right", actionButton(inputId="send_to_robotbox", "An RobotBox senden", class = "awpbutton")),
        div(style = "display:inline-block; float:right", actionButton(inputId="discard", "", class = "awpbutton", icon = icon("poo", lib = "font-awesome"))),
        bsTooltip(id = "discard", title = "Artikel verwerfen", 
                  placement = "top", trigger = "hover")
        
      ),
      
      position = "left",
      fluid = TRUE
    )
    
  ),
  
  tags$div(id = 'data_not_found',
           br(),
           br(),
           img(src="lost.gif", style = 'display: block; margin-left: auto; margin-right: auto;'),
           div(HTML('<h3><span>Keine anstehende Meldung gefunden...</span></h3>'), class="awpsubtitle", style = 'text-align: center;'),
           fluidRow(
             column(
               12,
               actionButton(inputId="reload_2", label = "", icon = icon("arrows-rotate"), class = "awpbutton"), style="display: inline-block;"),
             align = "center"            
           ),
           bsTooltip(id = "reload_2", title = "Neu laden", 
                     placement = "bottom", trigger = "hover")
  )

)


###########################
# Create Server-Function  #
###########################

server <- function(input, output, session) {
  
  reload <- function () {
    
    # Reset working dir (could be compromised by create_meldung)
    setwd(wd_initial)
    
    # Load from DB
    sqlstr <- "SELECT * FROM management.management_changes_mail WHERE status = 'N' ORDER BY mail_parsing_time DESC LIMIT 1;"
    data <- dbGetQuery(db_mgmt, sqlstr)
    
    if (nrow(data) > 0) {
      
      # Decide if it a translated message
      if (!is.na(data[1, ]$original_awp_title)) {
        translated <<- TRUE
      } else {
        translated <<- FALSE
      }
      
      # Set timestamp into globar var
      current_mail_parsing_time <<- data[1, ]$mail_parsing_time
    
      # Set right side (original)
      output$mail_subject <- renderText(data[1, ]$mail_subject)
      
      # Get shiny user
      if (test == TRUE) {
        user <- "test"
      } else {
        user <- stringr::str_remove(session$user, "@awp.ch")
      }
      
      # Set left side (draft message) and add current user as author
      updateTextInput(inputId="title", value=data[1, ]$draft_title)
      updateTextAreaInput(inputId="text", value=paste0(data[1, ]$draft_text, user))
      
      # Set blob (html file) to iFrame
      blob <- data[1, ]$original_html
      blob <- str_replace(blob, "iso-8859-15", "utf-8")
      blob <- str_replace(blob, "ISO-8859-15", "utf-8")
      blob <- str_replace(blob, "iso-8859-1", "utf-8")  # Replace charset in html metainfo
      blob <- str_replace(blob, "ISO-8859-1", "utf-8")
      blob <- str_replace(blob, "windows-1252", "utf-8")
      blob <- str_replace(blob, "Windows-1252", "utf-8")
      if (is.na(blob)) {
        # Generate html from plain text
        plain_text <- data[1, ]$original_text
        if (!is.na(plain_text))
          blob <- plainText_to_htmlText(plain_text)
      }
      session$sendCustomMessage('setIframeSource', blob)
      
      # Set wire according to DB
      if (data[1, ]$draft_wire == "P") {
        updateSelectInput(
          inputId = "wire_dropdown",
          label="Wire",
          choices=c("P", "K", "P + R")
        )
      } else if (data[1, ]$draft_wire == "P + R") {
        updateSelectInput(
          inputId = "wire_dropdown",
          label="Wire",
          choices=c("P + R", "P", "K")
        )
      } else {
        updateSelectInput(
          inputId = "wire_dropdown",
          label="Wire",
          choices=c("K", "P", "P + R")
        )
      }
      
      # Load Company
      updateSelectInput(
        inputId = "company_dropdown",
        label="Verknüpfung wählen",
        choices=loadCompany(data[1, ]$draft_company_id_bw2, db_masterdata)
      )
      updateTextInput(inputId="company_search", value="")
      
      # Load article in original language
      if (!is.na(data[1, ]$original_awp_title) && data[1, ]$original_awp_title != "") {
        updateTextInput(inputId="title_original", value=data[1, ]$original_awp_title)
        updateTextAreaInput(inputId="text_original", value=data[1, ]$original_awp_text)
        
        # Show both tabs, activate tab for original article
        showTab(inputId = "tabset1", target = "tab1", select = TRUE, session = session)
        showTab(inputId = "tabset1", target = "tab2", select = FALSE, session = session)
        shinyjs::disable("title_original")
        shinyjs::disable("text_original")
        
      } else {
        
        # Show only tab for mail
        hideTab(inputId = "tabset1", target = "tab1", session = session)
        showTab(inputId = "tabset1", target = "tab2", select = TRUE, session = session)
      }
      
      # Show panel for new mail
      shinyjs::hide("data_not_found")
      shinyjs::show("data_found")
      
    } else {
      
      # Reset timestamp in globar var
      current_mail_parsing_time <<- NULL
      
      # Show panel for no mail found
      shinyjs::hide("data_found")
      shinyjs::show("data_not_found")
      
    }
    
  }
  
  reload()
  
  # Validator
  iv <- InputValidator$new()
  iv$add_rule("title", ~ if (nchar(.) > 80) "Zu lang")
  iv$enable()
  
  # EVENT complete reload (from data_found panel)
  observeEvent(input$reload_1, {
    reload()
  })
  
  # EVENT complete reload (from data_not_found panel)
  observeEvent(input$reload_2, {
    reload()
  })
  
  # EVENT search company
  observeEvent(input$search_company, {
    updateSelectInput(
      inputId = "company_dropdown",
      label="Verknüpfung wählen",
      choices=searchCompany(input$company_search, db_masterdata)
    )
  })
  
  # EVENT show WYSIWYG / confirm panel
  show_wysiwyg <- function() {
    
    # Validation
    valid <- TRUE
    if (valid) {
      if (input$title == "") {
        valid <- FALSE
        shinyalert("Bitte Titel eingeben", type = "error")
      } else if (nchar(input$title) > 80) {
        valid <- FALSE
        shinyalert("Der Titel ist zu lang", type = "error")
      }
    }
    if (valid) {
      if (input$text == "") {
        valid <- FALSE
        shinyalert("Bitte Text eingeben", type = "error")
      }
    }
    if (valid) {
      if (is.na(input$company_dropdown) || input$company_dropdown == "" || input$company_dropdown == "NA") {
        valid <- FALSE
        shinyalert("Bitte Firma auswählen", type = "error")
      }
    }
    
    if (valid) {
      
      # Show WYSIWYG / confirm panel
      showModal(
        modalDialog(
          tags$h3(paste('Folgende Personalienmeldung wirklich', ifelse(modus == "Usable", "publizieren?", "an RobotBox senden?"))),
          div(
            id = "preview",
            HTML(paste(tags$b(tags$pre(input$title)))),
            HTML(paste(tags$pre(input$text))),
            style = "background-color: #F5F5F5; box-shadow: 5px 5px 0 #DDD; padding: 10px; border: 1px solid #e4e4e4; border-radius: 3px; margin: 20px 0px;"),
          footer = div(
            div(style = "display:inline-block; float:left", checkboxInput(inputId = "translate", label = "Französische Übersetzung erstellen", value = FALSE)),
            div(style = "display:inline-block; float:right", modalButton("Nein")),
            div(style = "display:inline-block; float:right", actionButton("publish_confirmed", "Ja"))
          ),
          size = c("l")
        )    
      )
      if (translated) {
        shinyjs::hide("translate")
      } else {
        shinyjs::show("translate")
      }
      
    }
  }
  observeEvent(input$publish, {
    modus <<- "Usable"
    show_wysiwyg()
  })
  observeEvent(input$send_to_robotbox, {
    modus <<- "Withheld"
    show_wysiwyg()
  })
  
  # EVENT publish confirmed
  observeEvent(input$publish_confirmed, {
    
    tryCatch({
      
      # Get status from DB
      sqlstr <- paste0("SELECT status, mail_subject, original_html, original_text ",
                       "FROM management.management_changes_mail ",
                       "WHERE mail_parsing_time = '", current_mail_parsing_time, "';")
      mail_before <- dbGetQuery(db_mgmt, sqlstr)
      if (!is.null(mail_before)) {
        status <- mail_before$status
      }
      
      # Check if other user has published or discarded in the meantime
      if (status != "N") {
        stop()
      }
      else {
      
        # Load company full name with ID
        company <- ""
        sqlstr <- paste0("SELECT Name ",
                         "FROM masterdata.companies ",
                         "WHERE ID = ", input$company_dropdown, ";")
        result <- dbGetQuery(db_masterdata, sqlstr)
        if (!is.null(result)) {
          company <- result$Name
        }
        
        
        # Upload to BW2
        if (test) {
          setwd("C:/Automatisierungen/management_changes/mgmt_changes_app")
        }
        if (input$wire_dropdown == "P + R") {
          wire <- c("P", "R")
        } else {
          wire <- c(input$wire_dropdown)
        }
        create_meldung(title=input$title,
                       text=plainText_to_htmlText(input$text),
                       company = company,
                       sprache="de",
                       code=c("MGT"),
                       name="mgmt_changes_app",
                       Wire = wire,
                       path = "",
                       modus = modus,
                       server=ifelse(test, "test", "live"),
                       byline="",
                       hint="")
        
        # Update row in DB
        title <- str_replace_all(input$title, '"', '\\\\"')
        title <- str_replace_all(title, "'", "\\\\'")
        text <- str_replace_all(input$text, '"', '\\\\"')
        text <- str_replace_all(text, "'", "\\\\'")
        if (!is.null(current_mail_parsing_time)) {
          sqlstr <- paste0("UPDATE management.management_changes_mail SET status = 'P', ", 
                           "published_company_id_bw2 = '", input$company_dropdown, "', ",
                           "published_title = '", title, "', ",
                           "published_text = '", text, "' WHERE mail_parsing_time = '", current_mail_parsing_time, "';" )
          dbGetQuery(db_mgmt, sqlstr)
        }
        
        # Insert translation into DB of french tool
        if (!translated && input$translate) {
          if (!is.null(current_mail_parsing_time)) {
            
            tryCatch({
              
              # Copy row to french version
              sqlstr <- paste0("INSERT INTO management.management_changes_mail_fr (mail_parsing_time, mail_subject, original_html, original_text) ",
                               "SELECT mail_parsing_time, mail_subject, original_html, original_text ",
                               "FROM management.management_changes_mail ",
                               "WHERE mail_parsing_time = '", current_mail_parsing_time, "';")
              dbGetQuery(db_mgmt, sqlstr)
              
              # Translate texts and update french version
              title_translated <- retry(translateWithDeepL(input$title, source_language = "DE", target_language = "FR"))
              title_translated <- str_replace_all(title_translated, '"', '\\\\"')
              title_translated <- str_replace_all(title_translated, "'", "\\\\'")
              text_translated <- retry(translateWithDeepL(input$text, source_language = "DE", target_language = "FR"))
              text_translated <- str_replace_all(text_translated, '"', '\\\\"')
              text_translated <- str_replace_all(text_translated, "'", "\\\\'")
              sqlstr <- paste0("UPDATE management.management_changes_mail_fr ",
                               "SET draft_company_name = '", company, "', draft_company_id_bw2 = '", input$company_dropdown,
                               "', draft_wire = '", input$wire_dropdown, "', draft_title = '", title_translated,
                               "', draft_text = '", text_translated, "', original_awp_title = '", title, "', original_awp_text = '", text, "'",
                               "WHERE mail_parsing_time = '", current_mail_parsing_time, "';")
              dbGetQuery(db_mgmt, sqlstr)
              
            }, error=function(e) {
              shinyalert("Übersetzungsprozess gescheitert", type = "error")
             })
             
             
            
            
          }
        }
        
        # Close WYSIWYG panel
        removeModal()
        
        # Success message and reload
        shinyalert(title = paste("Artikel", ifelse(modus == "Usable", "publiziert.", "an RobotBox gesendet.")),
                 "Die App wird neu geladen.", 
                   type = "success",
                   callbackR = function(modal_result) {if (modal_result == TRUE) reload()} )
        
      }
      
    }, error = function(e){ 
      
      # Close WYSIWYG panel
      removeModal()
      
      # Error message and reload
      shinyalert(title = "Fehler beim Publizieren. 
               Die App wird neu geladen.", 
                 type = "error",
                 callbackR = function(modal_result) {if (modal_result == TRUE) reload()} )
      
    })
    
    
  })
  
  # EVENT discard
  discard <- function() {
    
    # Update status in DB
    if (!is.null(current_mail_parsing_time)) {
      sqlstr <- paste0("UPDATE management.management_changes_mail SET status = 'D' WHERE mail_parsing_time = '", current_mail_parsing_time, "';" )
      dbGetQuery(db_mgmt, sqlstr)
    }
    
    reload()
    
  }
  observeEvent(input$discard, {
    shinyalert(paste0('Willst du den Artikel wirklich verwerfen?'), 
               type = "warning", 
               showConfirmButton = TRUE, 
               confirmButtonText = "Ja", 
               showCancelButton = TRUE, 
               cancelButtonText = "Nein",
               callbackR = function(modal_result) {if (modal_result == TRUE) discard()}
    )
  })

}


#################################
# Combine ui and server to app  #
#################################

shinyApp(ui, server)