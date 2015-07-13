import time
import os
import yaml
from selenium import webdriver

# Config values
config = yaml.safe_load(open("config.yml", "r"))

# ChromeDriver setup
chromedriver = config['DRIVER']
os.environ["webdriver.chrome.driver"] = chromedriver
browser = webdriver.Chrome(chromedriver)

# People to search are held in people.txt
# Put the people into an array
people = []
with open("people.txt", "r") as f:
    for line in f:
        people.append(line)

# Store results in results.txt
# eg. Elon Musk:560
with open("results.txt", "w") as results:
    # Do this for each person
    for person in people:
        # Format from Elon Musk to Elon%20Musk for the search
        formattedName = person.replace(" ", "%20")
        # Changes URL to include formattedName
        browser.get(config['URL'].format(formattedName))
        try:
            # Selects number of tweets by xpath
            select = browser.find_element_by_xpath(config['XPATH'])
            res = (select.text)
        except:
            # If element not found, loop continues
            continue
        # Handles searches with 0 results
        if res == "":
            res = "0"
        # Writes to results.txt file
        results.write(person.replace("\n", "") + ":" + res + "\n")

# Browser is quit when all searches are complete
browser.quit()
