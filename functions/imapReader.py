import imaplib  # standard lib
import email  # standard lib
from email.header import decode_header
import os
import datetime
from bs4 import BeautifulSoup  # HTML parser
from urllib.request import urlretrieve  # File downloader
from pypdf import PdfReader
import re


class InboxParser:

    def __init__(self, user, password, server, port=993, timeout=20, allowed_sender_domain=None, move_to_folder=None):
        self.user = user
        self.password = password
        self.server = server
        self.port = port
        self.timeout = timeout
        self.allowed_sender_domain = allowed_sender_domain
        self.imap_processed_folder = move_to_folder
        self.unsubscribe_texts = ["unsubscribe", "abmelden", "newsletter", "abbestellen", "kündigen"]

    def __write_plain_text(self, mail_timestamp, body):
        plain_folder = os.path.join(os.getcwd(), mail_timestamp, "plain")
        if not os.path.isdir(plain_folder):
            # make a folder for this email
            os.mkdir(plain_folder)
        filename = "mail.txt"
        filepath = os.path.join(plain_folder, filename)
        # write the file
        open(filepath, "w").write(body)
        return [body, filepath]

    def __write_html(self, mail_timestamp, body):
        html_folder = os.path.join(os.getcwd(), mail_timestamp, "html")
        # if it's HTML, create a new HTML file
        if not os.path.isdir(html_folder):
            # make a folder for this email
            os.mkdir(html_folder)
        filename = "mail.html"
        filepath = os.path.join(html_folder, filename)
        # write the file
        open(filepath, "w").write(body)
        # return text
        soup = BeautifulSoup(body, 'html.parser')
        return [soup.get_text(strip=True), filepath]

    def __extract_external_pdfs(self, mail_timestamp, html):

        # Init output
        parsed_texts = []

        # Get links
        links = []
        soup = BeautifulSoup(html, 'html.parser')
        link_elements = soup.find_all('a')
        for element in link_elements:
            link = element.get('href', None)
            if link is not None:
                link_descr = element.text
                is_unsubscribe = False
                for unsubscribe_text in self.unsubscribe_texts:
                    if unsubscribe_text in link_descr.lower():
                        is_unsubscribe = True
                if not is_unsubscribe:
                    links.append(link)

        # Download link destination if it's a PDF
        for index, link in enumerate(links, start=1):
            try:
                res = urlretrieve(link)
                temp_file = res[0]
                http_header = res[1]
                if http_header.get_content_type() == "application/pdf":
                    # Move temp file
                    ext_pdf_folder = os.path.join(os.getcwd(), mail_timestamp, "pdf_downloaded")
                    if not os.path.isdir(ext_pdf_folder):
                        os.mkdir(ext_pdf_folder)
                    filename = "doc_" + str(index) + ".pdf"
                    filepath = os.path.join(ext_pdf_folder, filename)
                    os.replace(temp_file, filepath)
                    # Parse text
                    reader = PdfReader(filepath)
                    text = ""
                    for page in reader.pages:
                        text += page.extract_text()
                    parsed_texts.append([text, filepath])
                else:
                    # Delete temp file
                    os.remove(temp_file)
            except:
                pass

        return parsed_texts

    def parse_latest_mail(self):

        # init return values
        mail_parsed = False
        timestamp_mail = None
        subject = ""
        sender_address = ""
        plain_text = []
        html_text = []
        pdf_attached_texts = []
        pdf_downloaded_texts = []

        # create an IMAP4 class with SSL
        imap_client = imaplib.IMAP4_SSL(host=self.server, port=self.port, timeout=self.timeout)

        # authenticate
        imap_client.login(self.user, self.password)

        # get id of last mail in inbox
        imap_status, mails = imap_client.select("INBOX")
        mail_id = int(mails[0])

        if mail_id > 0:

            # fetch the email message by ID
            res, msg = imap_client.fetch(str(mail_id), "(RFC822)")
            for response in msg:

                if isinstance(response, tuple):

                    # parse a bytes email into a message object
                    msg = email.message_from_bytes(response[1])

                    # decode the email subject
                    subject, encoding = decode_header(msg["Subject"])[0]

                    if isinstance(subject, bytes):
                        # if it's a bytes, decode to str
                        subject = subject.decode(encoding)

                    # decode email sender
                    sender_address, encoding = decode_header(msg.get("From"))[0]
                    if isinstance(sender_address, bytes):
                        sender_address = sender_address.decode(encoding)
                    search_res = re.search('<(.*)>', sender_address)
                    if search_res:
                        sender_address = search_res.group(1)

                    # print("Subject:", subject)
                    # print("From:", sender_address)

                    # Extract sender domain
                    sender_domain = sender_address.split("@")[1]
                    # print("From domain:", sender_domain)

                    # sender must be in list of allowed senders OR allowed senders must be undefined
                    if not self.allowed_sender_domain or sender_domain in self.allowed_sender_domain:

                        # Create Timestamp as key for this mail
                        timestamp_mail = datetime.datetime.now()
                        timestamp_folder = timestamp_mail.strftime("%Y%m%d_%H%M%S")

                        # Create folder for this mail
                        os.mkdir(timestamp_folder)

                        # if the email message is multipart
                        if msg.is_multipart():
                            # iterate over email parts
                            for part in msg.walk():
                                # extract content type of email
                                content_type = part.get_content_type()
                                content_disposition = str(part.get("Content-Disposition"))
                                try:
                                    # get the email body
                                    body = part.get_payload(decode=True).decode()
                                except:
                                    pass
                                if content_type == "text/plain" and "attachment" not in content_disposition:
                                    # print text/plain emails and skip attachments
                                    try:
                                        # print(body)
                                        plain_text = self.__write_plain_text(timestamp_folder, body)
                                    except:
                                        pass
                                if content_type == "text/html":
                                    try:
                                        # print(body)
                                        html_text = self.__write_html(timestamp_folder, body)
                                        pdf_downloaded_texts = self.__extract_external_pdfs(timestamp_folder, body)
                                    except:
                                        pass
                                elif "attachment" in content_disposition:
                                    # download attachment
                                    filename = part.get_filename()
                                    if filename:
                                        if filename.endswith(".pdf"):
                                            pdf_folder = os.path.join(os.getcwd(), timestamp_folder, "pdf_attached")
                                            if not os.path.isdir(pdf_folder):
                                                # make a folder for this email
                                                os.mkdir(pdf_folder)
                                            filepath = os.path.join(pdf_folder, filename)
                                            # download attachment and save it
                                            open(filepath, "wb").write(part.get_payload(decode=True))
                                            # Parse text
                                            reader = PdfReader(filepath)
                                            text = ""
                                            for page in reader.pages:
                                                text += page.extract_text()
                                            pdf_attached_texts.append([text, filepath])
                        else:
                            # extract content type of email
                            content_type = msg.get_content_type()
                            # get the email body
                            body = msg.get_payload(decode=True).decode()
                            if content_type == "text/plain":
                                # save only text email parts
                                try:
                                    # print(body)
                                    plain_text = self.__write_plain_text(timestamp_folder, body)
                                except:
                                    pass

                        mail_parsed = True

                    # print("=" * 100)

            # Move mail to processed folder
            if self.imap_processed_folder:
                try:
                    imap_client.copy(str(mail_id), self.imap_processed_folder)
                    imap_client.store(str(mail_id), '+FLAGS', r'(\Deleted)')
                    imap_client.expunge()
                except:
                    pass
                    print("Could not move email to folder " + self.imap_processed_folder)

        # close the connection and logout
        imap_client.close()
        imap_client.logout()

        return {"mail_parsed": mail_parsed,
                "timestamp": timestamp_mail,
                "subject": subject,
                "sender_address": sender_address,
                "plain_text": plain_text,
                "html_text": html_text,
                "pdf_attached_texts": pdf_attached_texts,
                "pdf_downloaded_texts": pdf_downloaded_texts}
