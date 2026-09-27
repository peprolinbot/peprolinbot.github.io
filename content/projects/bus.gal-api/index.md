---
title: "bus.gal-api"
date: 2021-05-28T00:11:52+02:00
description: "Python API wrapper for the galician public transport"
tags: ["python"]
---

{{< github repo="peprolinbot/bus.gal-api" >}}

Python API wrapper for the galician public transport which uses the associated
app's API to get the inforamtion about buses, your card and your user account.

> [!NOTE] Note from the present (2026)
>
> I would structure the python interface a bit different if I were to make this
> today, but it still works so I'm not going to bother suffering until the
> public transport itself is better.

## Reverse engineering

I used [mitmproxy](https://mitmproxy.org/) first, to get the basic HTTPS
requests the app made. The app has certificate pinning, so I circumvented that
on a rooted phone with [frida](https://frida.re) and
[github.com/httptoolkit/frida-interception-and-unpinning](https://github.com/httptoolkit/frida-interception-and-unpinning).

This was enough to get all the routing and cards functionality working (the
simple requests), but when I decided to implement the logic for the QR codes
used to get on the bus I had to inspect the decompiled code of the application
using [JADX](https://github.com/skylot/jadx) to understand how the QR code was
generated.

Turns out this was a pretty insecure thing (which I reported as soon as I found
out), where the app always logs in as an administrator with a **hardcoded
username and password**; when it generates a QR the servers returns some data
for the code, but the most important one is an integer that represents an index
in a hardcoded array in the app code which contains a list of keys (it calls
them "public keys" in the code, which does not make sense in DES) used to
encrypt/sign the date included in the QR using **DES ECB**, the rest of the data
is just encoded with different methods, but no encryption.

So yeah, you could do a lot of nasty things with this, the app was very poorly
designed security-wise. Check the python code on the GitHub repo if you want to
**learn** more (I'm not responsible of the use you make of this information, all
of this issued have been reported to the app maintainers several years ago from
this being written and are laid out here for educational purposes).

## 📜 Documentation

Documentation can be found [here](https://peprolinbot.github.io/bus.gal-api).
There are two main submodules: `busGal_api.transport` and `busGal_api.accounts`,
the first one has all the functions related to transportation and the second one
allows you to manage cards and accounts, as the name implies.

## 👀 Stuff you can do

This is just a simple command-line "client" which shows the transport submodule
in action by showing a simple timetable for the buses of the trip you specify:

> [!TIP]
>
> This is also this submodule's `__main__.py`, therefore you can
> `python -m busGal_api.transport` to try it out.

```python
from busGal_api import transport as api
from datetime import date, datetime

NUM_RESULTS=8

def stop_search_menu(prompt):
    query = input(prompt)
    results = api.stops.search_stops(query=query, num_results=NUM_RESULTS)

    for i, result in enumerate(results):
        print(f"{i} -- {result.name}")

    selection = int(input("Which number do you want? >>> "))

    return results[selection]

origin = stop_search_menu("Where do you want to start your trip? >>> ")
destination = stop_search_menu("And where do you want to go? >>> ")

date_str = input("And when? (dd-mm-yy) (defaults to today) >>> ")
date = datetime.strptime(date_str, "%d-%m-%Y") if date_str else date.today()

expeditions = api.expeditions.search_expeditions(origin=origin, destination=destination, date=date)

if expeditions == None:
    print("No results")
    exit()

print("\nORIGIN  |  DEPARTURE  |  DESTINATION  |  ARRIVAL\n")
for expedition in expeditions:
    print(expedition)
```

This one shows your cards and makes you rename them:

```python
from busGal_api import accounts as api

print("Please login to continue")
account=api.Account(input("Email: "), input("Password: "))

print("Here are your cards. You are going to rename each of them")
cards=account.get_cards()
for card in cards:
    print(card)
    card.rename(input("New name: "))
```

Now, for XenteNovaQr, here is the most typical use case, generating a QR to pay
in the bus:

```python
from busGal_api import accounts as api
import qrcode
from time import sleep

print("Please login to continue")
tpgal_account = api.Account(input("Email: "), input("Password: "))
xn_account = api.xentenovaqr.Account(tpgal_account.user_id) # This will only work if you have already registered for this service. You do so on the app or using the function for that purpose (not tested nor recommended)

qr_entity = xn_account.create_qr()
qr = qrcode.QRCode()
while True:
    qr.add_data(qr_entity.qr_string)
    print("Scan this code fast, it will refresh in 30s!")
    qr.print_ascii()
    sleep(30)
    qr_entity.refresh_qr_string() # This is done offline
    qr.clear()
```

> [!WARNING] Disclaimer (just in case)
>
> This project is not endorsed by, directly affiliated with, maintained by,
> sponsored by or in any way officially related with la Xunta de Galicia, the
> bus operators or any of the companies involved in the bus.gal website and the
> app. This software is provided 'as is' without any warranty of any kind. The
> user of this software assumes all responsibility and risk for its use. I shall
> not be liable for any damages or misuse of this software. Please use the code
> and information in this repo responsibly.
