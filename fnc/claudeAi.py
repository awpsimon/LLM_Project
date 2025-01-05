import anthropic

prompt_check_press_release = 'Handelt es sich beim folgenden Text um eine Medienmitteilung? Bitte antworte nur mit ' \
                            'einem Wort (entweder "JA" oder "NEIN"). Hier der Text: % s'

prompt_check_german = 'Ist der folgende Text in deutscher Sprache verfasst? Bitte antworte nur mit ' \
                            'einem Wort (entweder "JA" oder "NEIN"). Hier der Text: % s'

prompt_check_french = 'Ist der folgende Text in französischer Sprache verfasst? Bitte antworte nur mit ' \
                            'einem Wort (entweder "JA" oder "NEIN"). Hier der Text: % s'

prompt_create_message_draft_german = '''Ich bin Redaktor in einer Agentur für Wirtschaftsnachrichten und muss aus 
einer Medienmitteilung eine kurze journalistische Nachricht zu Änderungen im Management schreiben.
Beim Schreiben der Nachricht gelten folgende Regeln:
- Im Titel darf kein Doppelpunkt vorkommen
- Der Nachrichtentext muss in sinnvolle Abschnitte unterteilt werden. Ein Abschnitt muss mehrere Sätze enthalten
- Im Text muss die Quelle der Informationen am Ende des ersten Abschnittes in einem nachgestellten Nebensatz stehen
- Ist die Quelle eine Medienmitteilung, muss gesagt werden, an welchem Wochentag diese veröffentlicht wurde
- Abkürzungen sollen ausgeschrieben werden (also zum Beispiel "Verwaltungsratspräsident" statt "VR-Präsident")
- Die englische Abkürzung "CIO" darf nie übersetzt werden. Ausnahmsweise darf hier die Abkürzung verwendet werden
- Wörtliche Zitate dürfen nicht benützt werden
- Die Nachricht soll keine Basis-Informationen zum betroffenen Unternehmen enthalten

Bitte markiere im Output den Titel mit dem Stichwort "AWP_Titel" und den Nachrichtentext mit dem Stichwort "AWP_Text".
Hier ist die Medienmitteilung: % s'''

prompt_create_message_draft_french = '''Je suis rédacteur dans une agence de presse économique. Je dois écrire 
je dois écrire un court article sur le changement de direction d'une entreprise. 
La base de ce texte est un communiqué de presse.
Les règles suivantes s'appliquent à la rédaction de l'article :
- Le titre ne doit pas comporter de double points.
- Le texte de l'article doit être divisé en sections significatives. Un paragraphe doit contenir plusieurs phrases
- Dans le texte, la source de l'information doit figurer à la fin du premier paragraphe 
  dans une  proposition subordonnée conjonctive
- Si la source est un communiqué de presse, il faut préciser le jour de la semaine où il a été publié.
- Les abréviations doivent être écrites en toutes lettres
  (donc par exemple « président du conseil d'administration » au lieu de « président du CA »).
- L'abréviation anglaise « CIO » ne doit jamais être traduite. Exceptionnellement, l'abréviation peut être utilisée ici.
- Les citations littérales ne doivent pas être utilisées.
- L'article ne doit pas comporter d'intertitres
- Le message ne doit pas contenir d'informations de base sur l'entreprise concernée.

Dans l'output, veuillez marquer le titre avec le mot-clé « AWP_Titel » et le texte du message 
avec le mot-clé « AWP_Text ».
Voici le communiqué de presse : % s'''

prompt_extract_company = 'Bitte extrahiere den Firmennamen aus der folgenden Medienmitteilung. Markiere im ' \
                         'Output den Firmennamen mit dem Stichwort "AWP_Firma". Füge in deiner Antwort nach dem ' \
                         'Firmennamen keinen weiteren Text mehr hinzu. ' \
                         'Hier der Text der Medienmitteilung : % s'

class ClaudeAi:

    def __init__(self, api_key, output_language="german"):
        self.api_key = api_key
        self.output_language = output_language

    def __ask_claude(self, client, prompt):

        response = None

        try:
            message = client.messages.create(
                model="claude-3-5-sonnet-20240620",
                max_tokens=1024,
                temperature=0,
                messages=[
                    {"role": "user",
                     "content": prompt.replace("\n", "")}
                ]
            )
            response = message.content[0].text

        except Exception as e:
            print("Error while asking Claude:", e)

        return response

    def __create_draft_parts(self, client, text):

        draft = {}

        # Create draft title and text
        if self.output_language == "french":
            res = self.__ask_claude(client, prompt_create_message_draft_french % text[0])
        else:
            res = self.__ask_claude(client, prompt_create_message_draft_german % text[0])
        if res:
            res = "dummy text" + res  # Make sur that split doesn't fail
            try:
                draft["title"] = res.split("AWP_Titel")[1].split("AWP_Text")[0].strip(":").strip()
            except:
                draft["title"] = ""
            try:
                draft["text"] = res.split("AWP_Text")[1].strip(":").strip()
            except:
                draft["text"] = ""

            # Extract company name
            res = self.__ask_claude(client, prompt_extract_company % text[0])
            if res:
                try:
                    draft["company"] = res.split("AWP_Firma")[1].strip(":").strip()
                except:
                    draft["company"] = ""

                    # Add original text and filepath to draft
                draft["original_text"] = text[0]
                draft["original_filepath"] = text[1]

        return draft


    #######################
    ## Function purpose: create msg draft from a range of possible original texts
    ##
    ## Input
    ## texts: prioritized list. each entry contains text and filepath to original document
    ##
    ## Return
    ## draft: dict with draft title, draft text, company, original text and filepath
    ##        (or empty dict if draft creation failed)
    ########################
    def create_message_draft(self, texts):

        # create anthropic client
        client = anthropic.Anthropic(
            api_key=self.api_key,
        )

        draft = {}
        press_releases = []  # list of texts to be used if no german press release found

        for text in texts:

            # Check if text is a press release
            res = self.__ask_claude(client, prompt_check_press_release % text[0])
            if res and res.lower().__contains__("ja"):

                # Check if text is in output language
                if self.output_language == "french":
                    res = self.__ask_claude(client, prompt_check_french % text[0])
                else:
                    res = self.__ask_claude(client, prompt_check_german % text[0])
                if res and res.lower().__contains__("nein"):

                    # Add text to list of press releases for possible later use
                    press_releases.append(text)

                else:

                    # Create draft and stop loop
                    draft = self.__create_draft_parts(client, text)
                    if draft:
                        break

        if not draft and press_releases:  # no german press release found, use first text in other languages
            draft = self.__create_draft_parts(client, press_releases[0])

        # close client
        client.close()

        return draft
