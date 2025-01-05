dfToTable_left <- function(df) {
  ## @df: Dataframe with row- and colnames embedded (in df-data, not col.names/row.names)
  ## return: string with table, all values formatted to the left
  
  library(stringr)
  #Breite pro Spalte festlegen
  width <- 0
  for (i in 1:ncol(df)) {
    width[i] <- max(max(nchar(str_extract(df[,i], ".*\n?"))), max(nchar(str_extract(df[,i], "\n?.*")))) + 2
  }
  #Alle Zeilen durchgehen und ausfüllen
  tabelle <- ""
  #Zeilenbezeichnung einfügen
  for (rownr in 1:nrow(df)) {
    tabelle <- paste0(tabelle, df[rownr, 1])
    #Werte einfügen
    for (colnr in 2:ncol(df)) {
      tabelle <- paste0(tabelle, strrep(" ", width[colnr-1]-nchar(str_replace(df[rownr,colnr-1], ".*\n", ""))), df[rownr, colnr])
    }
    tabelle <- paste0(tabelle, "\n")
  }
  return(tabelle)
}

dfToTable_right <- function(df) {
  ## @df: Dataframe with row- and colnames embedded (in df-data, not col.names/row.names)
  ## return: string with table, all values formatted to the right
  
  library(stringr)
  #Breite pro Spalte festlegen
  width <- 0
  for (i in 1:ncol(df)) {
    width[i] <- max(max(nchar(str_extract(df[,i], ".*\n?"))), max(nchar(str_extract(df[,i], "\n?.*")))) + 2
  }
  #Alle Zeilen durchgehen und ausfüllen
  tabelle <- ""
  #Zeilenbezeichnung einfügen
  for (rownr in 1:nrow(df)) {
    tabelle <- paste0(tabelle, df[rownr, 1])
    tabelle <- paste0(tabelle, strrep(" ", width[1]-nchar(str_replace(df[rownr,1], ".*\n", ""))+(width[2]-nchar(str_extract(df[rownr,2], ".*\n?")))), df[rownr, 2])
    #Werte einfügen
    if (ncol(df) > 2) {
      for (colnr in 3:ncol(df)) {
        tabelle <- paste0(tabelle, strrep(" ", width[colnr]-nchar(str_extract(df[rownr,colnr], ".*\n?"))), df[rownr, colnr])
      }
    }
    tabelle <- paste0(tabelle, "\n")
  }
  return(tabelle)
}

centerCol <- function(df, colnr, direction = "right") {
  ## @df: Dataframe to be formatted by functions dfToTable_left/right 
  ## @colnr: Index of column to be centered
  ## @direction: direction of df-format
  ## return: df that can be formatted by functions dfToTable_left/right 
  
  
  library(stringr)
  if (direction == "right") {
    dir <- 1
  } else {
    dir <- -1
  }
  width <- max(max(nchar(str_extract(df[,colnr], ".*\n?"))), max(nchar(str_extract(df[,colnr], "\n?.*"))))
  if ((width %% 2) != 0) {
    width <- width + 1
  }
  for (rownr in 1:nrow(df)) {
    colwidth <- nchar(str_extract(df[rownr,colnr], ".*\n?"))
    diff <- width - colwidth
    if (diff > 0) {
      if ((diff %% 2) == 0) {
        df[rownr, colnr] <- paste0(strrep(" ", diff/2), df[rownr, colnr], strrep(" ", diff/2))
      } else if (diff == 1) {
        df[rownr, colnr] <- paste0(df[rownr, colnr], strrep(" ", diff/2))        
      } else {
        df[rownr, colnr] <- paste0(strrep(" ", (diff+dir)/2), df[rownr, colnr], strrep(" ", (diff-dir)/2))
      }
    }
    df[rownr, colnr] 
  }
  return(df)
}

centerCol_sign <- function(df, colnr, sign) {
  ## @df: Dataframe to be formatted by functions dfToTable_left/right 
  ## @colnr: Index of column to be centered
  ## @sign: Sign that should be centeres (for example "-" in "100 - 150")
  
  
  library(stringr)
  max_left <- max(nchar(str_extract(df[,colnr], paste0(".*", sign))), na.rm = TRUE)
  max_right <- max(nchar(str_extract(df[,colnr], paste0(sign, ".*"))), na.rm = TRUE)
  max_width <- max(nchar(df[,colnr]), na.rm = TRUE)
  for (rownr in 1:nrow(df)) {
    if (df[rownr, colnr] != sign & nchar(df[rownr, colnr]) > 1) {
      if (!grepl(sign, df[rownr, colnr])) {
        width <- nchar(df[rownr,colnr])
        diff <- max_width-width
        if ((diff %% 2) == 0) {
          df[rownr, colnr] <- paste0(strrep(" ", diff/2), df[rownr, colnr], strrep(" ", diff/2))
        } else if (diff == 1) {
          df[rownr, colnr] <- paste0(df[rownr, colnr], strrep(" ", diff/2))        
        } else {
          df[rownr, colnr] <- paste0(strrep(" ", (diff+1)/2), df[rownr, colnr], strrep(" ", (diff-1)/2))
        }
      } else {
        left <- nchar(str_extract(df[rownr,colnr], paste0(".*", sign)))
        df[rownr, colnr] <- paste0(strrep(" ", max_left-left), df[rownr, colnr])
        right <- nchar(str_extract(df[rownr,colnr], paste0(sign, ".*")))
        df[rownr, colnr] <- paste0(df[rownr, colnr], strrep(" ", max_right-right))
      }
    }
  }
  return(df)
}

