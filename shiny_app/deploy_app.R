library(rsconnect)

setwd("C:/Automatisierungen/management_changes/mgmt_changes_app")

rsconnect::setAccountInfo(name='awp-finanznachrichten',
                          token=Sys.getenv("token_shiny"),
                          secret=Sys.getenv("secret_shiny"))
deployApp()