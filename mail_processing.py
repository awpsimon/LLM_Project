import keyring
from fnc import imapReader
from fnc import claudeAi
from fnc import masterdata_bw2
from fnc import pdfConverter
from awptools import utils
import os
import time
import datetime
from bs4 import UnicodeDammit
import logging
import re
import concurrent.futures
import sys

test = False

###############
# Preparation #
###############

# Alert recipients
if test:
    alert_recipients = "sw@awp.ch"
else:
    alert_recipients = "redakt@awp.ch"

# Set language version
version = "german"
try:
    if sys.argv[1].lower() == "french":
        version = "french"
except:
    pass

# Set weekdays
if version == "french":
    weekdays = {
        0: "lundi",
        1: "mardi",
        2: "mercredi",
        3: "jeudi",
        4: "vendredi",
        5: "samedi",
        6: "dimanche"
    }
else:
    weekdays = {
        0: "Montag",
        1: "Dienstag",
        2: "Mittwoch",
        3: "Donnerstag",
        4: "Freitag",
        5: "Samstag",
        6: "Sonntag"
    }

# Set town names
towns = {
    "Basel": "Bâle",
    "Bern": "Berne",
    "Biel": "Bienne",
    "Brig": "Brigue",
    "Chur": "Coire",
    "Freiburg": "Fribourg",
    "Glarus": "Glaris",
    "Luzern": "Lucerne",
    "Murten": "Morat",
    "Olten": "Olte",
    "St. Gallen": "Saint Gall",
    "Schwyz": "Schwytz",
    "Siders": "Sierre",
    "Sitten": "Sion",
    "Solothurn": "Soleure",
    "Visp": "Viège",
    "Winterthur": "Winterthour",
    "Zug": "Zoug",
    "Zürich": "Zurich"
}

# Prepare logging
log_folder = "C:\\Automatisierungen\\management_changes\\logs"
if not os.path.isdir(log_folder):
    os.mkdir(log_folder)
log_name = os.path.join(log_folder, datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
                        + ('_mail_processing_de.log' if (version == "german") else '_mail_processing_fr.log'))
logging.basicConfig(filename=log_name,
                    level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s')
logging.info(f"Started process in {version} version")

# Get passwords
mail_password = None
if version == "french":
    mail_user = "gestion@awp.news"
else:
    mail_user = "personalia@awp.news"
claude_password = None
for attempt in range(3):
    try:
        mail_password = keyring.get_password("Webland", mail_user)
        claude_password = keyring.get_password("Claude", "anthropic_api_key")
    except Exception as e:
        err = e
        continue
    else:  # no exception, continue remainder of code
        break
else:  # did not break the for loop, therefore all attempts raised an exception
    alert_subject = "Personalien-Prozess konnte nicht gestartet werden"
    alert_body = ("Der Prozess management_changes_mail/mail_processing.py ist abgestürzt.\n\n"
                  + "Fehlermeldung: " + str(err) + "\n\nAWP Robot")
    utils.send_notification(alert_subject, alert_body, "robot-notification@awp.ch")
    logging.error("Getting passwords with keyring failed with error: " + str(err))
    raise err

# Mail configuration
mail_folder = "C:\\Automatisierungen\\management_changes\\_parsed_mails"
if not os.path.isdir(mail_folder):
    os.mkdir(mail_folder)
mail_server = "ms7imap.webland.ch"
if test:
    mail_allowed_sender_domain = ["gmx.ch", "awp.ch"]
else:
    mail_allowed_sender_domain = ["awp.ch"]
# mail_parser = imapReader.InboxParser(user=mail_user,
#                                      password=mail_password,
#                                      server=mail_server,
#                                      allowed_sender_domain=mail_allowed_sender_domain,
#                                      move_to_folder="Processed")

# Claude AI configuration
if version == "french":
    claude = claudeAi.ClaudeAi(api_key=claude_password, output_language="french")
else:
    claude = claudeAi.ClaudeAi(api_key=claude_password, output_language="german")

# Set loop interval
loop_interval = 5

# Set timeout in seconds for mail parser
timeout = 120

# Set process end time
process_end_hour = 22
current_hour = datetime.datetime.now().hour


########
# Loop #
########

logging.info("Start checking " + mail_user + " on " + mail_server)

# Loop for reading mails
while current_hour < process_end_hour:

    try:

        time.sleep(loop_interval)
        send_error_mail = False


        # Parse one new mail at a time
        mail_parser = imapReader.InboxParser(user=mail_user,
                                             password=mail_password,
                                             server=mail_server,
                                             allowed_sender_domain=mail_allowed_sender_domain,
                                             move_to_folder="Processed")
        os.chdir(mail_folder)
        parsing_result = None
        # try:
        #     parsing_result = mail_parser.parse_latest_mail()
        # except Exception as e:
        #     logging.warning("Imap access or mail parsing failed with error " + str(e))
        #     parsing_result = None
        with concurrent.futures.ThreadPoolExecutor() as executor:
            future = executor.submit(mail_parser.parse_latest_mail)
            try:
                # Wait for the function to complete
                parsing_result = future.result(timeout=timeout)
            except concurrent.futures.TimeoutError:
                logging.warning(f"Imap access or mail parsing timed out after {timeout} seconds")
                parsing_result = None
                # # Create new instance of mail_parser in case it got corrupted
                # mail_parser = imapReader.InboxParser(user=mail_user,
                #                                      password=mail_password,
                #                                      server=mail_server,
                #                                      allowed_sender_domain=mail_allowed_sender_domain,
                #                                      move_to_folder="Processed")
            except Exception as e:
                logging.warning("Imap access or mail parsing failed with error " + str(e))
                parsing_result = None


        # Continue if mail parsed
        if parsing_result and parsing_result["mail_parsed"]:

            logging.info("\nParsing successful\nSender: " + parsing_result["sender_address"]
                         + "\nSubject: " + parsing_result["subject"] + "\n")


            # Create prioritized list with texts
            texts = []
            try:
                for entry in parsing_result["pdf_attached_texts"]:
                    texts.append(entry)
                for entry in parsing_result["pdf_downloaded_texts"]:
                    texts.append(entry)
                if len(parsing_result["html_text"]) != 0:
                    texts.append(parsing_result["html_text"])
                if len(parsing_result["plain_text"]) != 0:
                    texts.append(parsing_result["plain_text"])
            except Exception as e:
                logging.error("Prioritizing of texts failed with error " + str(e))
                send_error_mail = True


            # Create message draft
            draft = None
            try:
                draft = claude.create_message_draft(texts)
            except Exception as e:
                logging.error("Creating a draft with Claude AI failed with error " + str(e))
                send_error_mail = True
                draft = None


            if draft:

                try:

                    # Convert PDF to HTML if necessary and extract html text
                    html = None
                    filepath = draft["original_filepath"]
                    if filepath.lower().__contains__("pdf"):
                        # Convert PDF to HTML (because PDF cannot be displayed properly in ShinyApp)
                        filepath = pdfConverter.pdf_to_html(filepath)
                        with open(filepath, 'r', encoding="utf-8") as file:  # Converted PDFs are always UTF-8
                            html = file.read()
                    elif filepath.lower().__contains__("html"):
                        try:
                            with open(filepath, 'r') as file:  # Works most of the time better but causes sometimes errors
                                html = file.read()
                        except:
                            with open(filepath, 'rb') as binary_file:  # Fallback (but can't always displayed properly)
                                content = binary_file.read()
                            suggestion = UnicodeDammit(content)
                            encoding = suggestion.original_encoding
                            with open(filepath, 'r', encoding=encoding) as file:
                                html = file.read()


                    # Detect company (BW2)
                    company = masterdata_bw2.get_company(draft["company"])
                    if version == "german":
                        if company["town"] == "Geneve" or company["town"] == "Genève" or company["town"] == "Geneva":
                            company["town"] = "Genf"


                    # Add author and dateline (Spitzmarke)
                    draft["text"] += "\n\nawp-robot/"
                    dateline = (company["town"] if company["town"] != "" else "Zürich") + " (awp) - "
                    if not draft["text"].startswith(dateline):
                        draft["text"] = dateline + draft["text"]
                    if version == "french":
                        for town_de, town_fr in towns.items():
                            draft["text"] = draft["text"].replace(town_de, town_fr)


                    # Remove / replace unwanted details in texts
                    draft["text"] = re.sub("\\s\\(SIX:\\s.*\\)", "", draft["text"])
                    draft["text"] = draft["text"].replace("ß", "ss")
                    draft["title"] = draft["title"].replace("ß", "ss")

                    # Set fixed weekday
                    if version == "french":
                        for day in weekdays:
                            draft["text"] = draft["text"].replace(weekdays[day] + ". ",
                                                                  weekdays[datetime.datetime.now().weekday()] + ". ")
                    else:
                        for day in weekdays:
                            draft["text"] = draft["text"].replace(" am " + weekdays[day],
                                                                  " am " + weekdays[datetime.datetime.now().weekday()])

                    # Write draft into DB
                    if version == "french":
                        table = "management_changes_mail_fr"
                    else:
                        table = "management_changes_mail"
                    mgmt_db = utils.connect_db("management")
                    mgmt_cursor = mgmt_db.cursor()
                    sql_stmt = f"""INSERT INTO management.{table} \
                    (mail_parsing_time, mail_subject, draft_company_name, draft_company_id_bw2, draft_wire, \
                    draft_title, draft_text, original_html, original_text) \
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s);"""
                    mgmt_cursor.execute(sql_stmt, (parsing_result["timestamp"], parsing_result["subject"],
                                                   draft["company"], company["id"], company["wire"], draft["title"],
                                                   draft["text"], html, draft["original_text"]))
                    mgmt_db.commit()
                    mgmt_cursor.close()
                    mgmt_db.close()


                    # Send alert to desk
                    if version == "french":
                        alert_subject = "Article sur le changement de gestion créé"
                        alert_body = ("J'ai créé un projet d'un article sur le changement de gestion. "
                                      "Tu le trouveras dans l'app shiny.\n\nAWP Robot")
                    else:
                        alert_subject = "Personalienmeldung erstellt"
                        alert_body = ("Ich habe einen Entwurf für die Personalienmeldung erstellt. "
                                      "Du findest diesen in der Shiny-App.\n\nAWP Robot")
                    utils.send_notification(alert_subject, alert_body, alert_recipients)


                except Exception as e:
                    logging.error("Processing of draft failed with error " + str(e))
                    send_error_mail = True


            if send_error_mail:

                # Send mail to inform about failure
                if version == "french":
                    alert_subject = "Article sur le changement de gestion n'a pas pu être créé"
                    alert_body = ("Malheureusement, je n'ai pas pu créer un projet d'un article sur le changement "
                                  "de gestion. Veuillez écrire le message vous-même.\n\nAWP Robot")
                else:
                    alert_subject = "Personalienmeldung konnte nicht erstellt werden"
                    alert_body = ("Leider konnte ich keinen Entwurf einer Personalienmeldung erstellen. "
                                  "Bitte schreibe die Meldung von Hand.\n\nAWP Robot")
                utils.send_notification(alert_subject, alert_body, alert_recipients)

        if datetime.datetime.now().hour > current_hour:
            current_hour = datetime.datetime.now().hour
            logging.info("New hour: " + str(current_hour))

    except Exception as e:
        logging.error("mail_processing loop failed with excecption: " + str(e))

logging.info("Stopped checking " + mail_user + " on " + mail_server)
