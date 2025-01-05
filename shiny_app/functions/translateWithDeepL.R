library(deeplr)

translateWithDeepL <- function(text, source_language = "DE", target_language = "FR"){
  
  ########################
  ## Function purpose: Translate a text with DeepL API
  ##
  ## Input
  ## text: string
  ## source_language: string ("DE", "FR", "EN")
  ## source_language: string ("DE", "FR", "EN")
  ##
  ## Return
  ## translation: string
  ########################
  
  translation <- ""
  
  tryCatch({
    
  }, error=function(e) {
          subject <- "Fehler bei Prozess processname" 
          body <- paste0("Beim Prozess processname gab es einen Fehler. 
                          Fehlermeldung:\n", e)
          send_notification(subject, body)
   })
   
   
  
  translation <- translate(
    text,
    target_lang = target_language,
    source_lang = source_language,
    split_sentences = TRUE,
    preserve_formatting = FALSE,
    get_detect = FALSE,
    auth_key = Sys.getenv("awp_pro_api")
  )
  
  return(translation)
  
}