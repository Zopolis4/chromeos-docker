#!/bin/bash

# Cronjob to run monthly (midnight first day of every month): 0 0 1 * *

# Update devices.csv

# https://github.com/flother/htmltab
htmltab --select 3 https://www.chromium.org/chromium-os/developer-information-for-chrome-os-devices/ > devices.csv
