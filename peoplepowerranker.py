import time
import os
from selenium import webdriver

# ChromeDriver setup
chromedriver = "../chromedriver"
os.environ["webdriver.chrome.driver"] = chromedriver
browser = webdriver.Chrome(chromedriver)

# People to search are held in people.txt file
f = open("people.txt", "r")

# Put the people into an array
people = []
for line in f:
    people.append(line)
f.close()

# Where we put the results
# eg. Elon Musk:560
result = open("results.txt", "w")
# Do this for each person
for person in people:
    # Format from Elon Musk to Elon%20Musk for the search
    formattedName = person.replace(" ", "%20")
    # Changes URL to include formattedName
    browser.get("INSERT URL HERE".format(formattedName))
    try:
        # Selects number of tweets by xpath
        select = browser.find_element_by_xpath('INSERT XPATH HERE')
        res = (select.text)
    except:
        # If element not found, loop continues
        continue
    # Handles searches with 0 results
    if res == "":
        res = "0"
    # Writes to results.txt file
    result.write(person.replace("\n", "") + ":" + res + "\n")
result.close()

# Browser is quit when all searches are complete
browser.quit()
