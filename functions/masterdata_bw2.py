from awptools import utils
from string import Template
import re

SQL_QUERY = Template('SELECT ID, Ort, Name, Indices FROM masterdata.companies WHERE Name LIKE "%$name%";')

COMPANY_SUFFIXES = ["\sAG$", "\sS.A.$", "\sSA$",
                    "\sLTD.$", "\sLTD$", "\sLIMITED$",
                    ",\sINC.$", "\sINC.$", "\sINC$",
                    "\sPLC.$", "\sPLC$",
                    "\sGMBH$",
                    "\s& CO.$", "\sCO.$",
                    "\sN.V.$", "\sNV$",
                    "\s\(SWITZERLAND\)$", "\sSWITZERLAND$", "\s\(SCHWEIZ\)$", "\sSCHWEIZ$",
                    "\s\(CH\)$", "\s\(SWISS\)$", "\sSWISS$",
                    "\s\(EUROPE\)$","\sEUROPE$",
                    "\sGROUP$", "\sHOLDINGS$", "\sHOLDING$", "-HOLDING$",
                    "\sKAPITALMARKT$", "\sFINANCE$", "\sFINANCIAL$", "\sFINANZ$",
                    "\sBANK$",
                    ",\s.*"]

def __extract_company(db_row, company):
    company["id"] = db_row[0]
    company["town"] = db_row[1].strip()
    if "SPI" in db_row[3] and "NOSPI" not in db_row[3]:
        company["wire"] = "P"
    else:
        company["wire"] = "K"
    return company

def get_company(company_name):

    company = {}
    company["id"] = ""
    company["town"] = ""
    company["wire"] = ""

    if company_name != "":

        try:
            # Prepare company string
            company_name = company_name.upper()
            company_name = company_name.replace("ST.", "ST. ")
            company_name = company_name.replace("/", " ")
            company_name = company_name.strip()

            # Establish db connection
            masterdata_db = utils.connect_db("masterdata")
            masterdata_cursor = masterdata_db.cursor()

            # Search for exact match
            masterdata_cursor.execute(SQL_QUERY.substitute(name=company_name))
            rows = masterdata_cursor.fetchall()
            if rows and len(rows) == 1:
                company = __extract_company(rows[0], company)
            else:
                # Search for approximate match
                for suffix in COMPANY_SUFFIXES:
                    company_name = re.sub(suffix, "", company_name)
                company_name = company_name.split(", ")[0]
                masterdata_cursor.execute(SQL_QUERY.substitute(name=company_name))
                rows = masterdata_cursor.fetchall()
                if rows:
                    if len(rows) == 1:
                        company = __extract_company(rows[0], company)
                    else:
                        for row in rows:
                            bw2_name = row[2].upper()
                            for suffix in COMPANY_SUFFIXES:
                                bw2_name = re.sub(suffix, "", bw2_name)
                            if company_name == bw2_name:
                                company = __extract_company(row, company)
                                break


            # Close db connection
            masterdata_cursor.close()
            masterdata_db.close()

        except:
            pass

    return company
