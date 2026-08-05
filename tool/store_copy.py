#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""The words drawn ON the Play graphics and the Google Ads assets, in every
language we ship.

    python tool/store_copy.py          # check every line fits every format

`assets/store/<locale>/details.md` holds the text Play renders itself - title,
short and long description. This file holds the other half: the captions
painted into the screenshots, the pitch on the 1024x500 feature graphic, and
the claims on the Google Ads image and video assets (`ADS` / `ADS_BEATS`).
Those are pictures, so nothing wraps and nothing ellipsizes - a line that is
too long simply runs off the edge, or into the phone next to it, and the only
way to know is to measure it.

So this module measures. Same method as `tool/measure_labels.py`, and for the
same reason: flutter_test's font substitution and PIL's own layout both lie,
while summing advance widths out of the real TTF at the real size matches what
gets drawn. The four formats have very different room, and the phone portrait
one - a centred caption above a whole device - is by far the tightest.

Every claim in here is checked against the source by
`tool/check_store_listings.py`; keep the two in step when a count changes.
"""
from __future__ import annotations

import sys

DISPLAY = "assets/fonts/SpaceGrotesk-Variable.ttf"
BODY = "assets/fonts/Manrope-Variable.ttf"

LOCALES = ["en", "pl", "de", "es", "fr", "cs"]

# Play's locale code per app language. The app's ARB codes are bare languages;
# Play wants a region, and picks the listing by exact tag.
PLAY = {"en": "en-US", "pl": "pl-PL", "de": "de-DE",
        "es": "es-ES", "fr": "fr-FR", "cs": "cs-CZ"}

# The accent bar under each headline. Not localized - it is the shot's colour,
# keyed by name so the caption table below stays pure text.
ACCENT = {
    "cutout_result": (23, 182, 214),
    "sticker": (120, 210, 160),
    "effects": (240, 196, 90),
    "layers": (150, 160, 255),
    "grid": (120, 210, 160),
    "objremove_panel": (23, 182, 214),
    "bubble": (240, 140, 170),
    "home": (240, 196, 90),
}

# Order is the pitch, not a menu: the two AI shots lead because they are the
# reason to pick this app over the one already on the phone, breadth follows,
# and "free, no account" closes. Play renders the first three largest.
ORDER = ["cutout_result", "sticker", "effects", "layers",
         "grid", "objremove_panel", "bubble", "home"]

# locale -> shot -> (headline, supporting line). The \n is a hard break: the
# phone frames are narrow enough that letting the renderer choose would put the
# fold in a different place in every language.
CAPTIONS = {
    "en": {
        "cutout_result": ("Cut the background\nout with AI",
                          "Two on-device models, no upload and no account.\nEdge feather included."),
        "sticker": ("Turn any photo\ninto a sticker",
                    "Contour outline and drop shadow, both adjustable,\nexported as transparent PNG."),
        "effects": ("14 one-tap looks,\nHDR and vignette",
                    "Every look has a strength slider, and they stack\nwith the colour adjustments."),
        "layers": ("Real layers, with\n16 blend modes",
                   "Reorder by dragging, hide, duplicate, merge down\nor flatten the whole stack."),
        "grid": ("Photo grids in\n18 layouts",
                 "Drag the dividers to reweigh the cells. Every tool\nstill works inside one."),
        "objremove_panel": ("Tap an object\nto remove it",
                            "Fill in rebuilds the background behind it,\nor erase it to transparency."),
        "bubble": ("Captions and\ncomic bubbles",
                   "Speech, thought, shout and caption shapes,\nfive display fonts, outlines and colour."),
        # NOT "no export limit": the free tier gates an export behind a
        # rewarded ad, and next to "free" that line reads as "no ads", which
        # is a claim this app cannot make.
        "home": ("Free, and it stays\non your phone",
                 "No account and no watermark. Every edit is\nprocessed on the device, never uploaded."),
    },
    "pl": {
        "cutout_result": ("Wytnij tło\nza pomocą AI",
                          "Dwa modele na urządzeniu, bez wysyłania i bez konta.\nZ wygładzaniem krawędzi."),
        "sticker": ("Zamień zdjęcie\nw naklejkę",
                    "Obrys konturu i cień, oba regulowane,\neksport do przezroczystego PNG."),
        "effects": ("14 filtrów,\nHDR i winieta",
                    "Każdy filtr ma suwak siły i łączy się\nz korektą kolorów."),
        "layers": ("Prawdziwe warstwy,\n16 trybów mieszania",
                   "Zmieniaj kolejność, ukrywaj, powielaj, scalaj w dół\nalbo spłaszcz cały stos."),
        "grid": ("Kolaże zdjęć\nw 18 układach",
                 "Przeciągaj podziały, by zmienić proporcje komórek.\nKażde narzędzie działa w środku."),
        "objremove_panel": ("Dotknij obiekt,\naby go usunąć",
                            "Wypełnij odtwarza tło za nim,\nalbo wymaż go do przezroczystości."),
        "bubble": ("Napisy i dymki\nkomiksowe",
                   "Kształty: mowa, myśl, krzyk i narracja,\npięć krojów ozdobnych, obrys i kolor."),
        "home": ("Za darmo i zostaje\nna Twoim telefonie",
                 "Bez konta i bez znaku wodnego. Każda zmiana\njest liczona na urządzeniu, nic nie wychodzi."),
    },
    "de": {
        "cutout_result": ("Hintergrund weg,\nper KI",
                          "Zwei Modelle auf dem Gerät, kein Upload, kein Konto.\nMit weicher Schnittkante."),
        "sticker": ("Jedes Foto wird\nzum Sticker",
                    "Kontur und Schlagschatten, beide regelbar,\nals transparentes PNG exportiert."),
        "effects": ("14 Looks, HDR\nund Vignette",
                    "Jeder Look hat einen Stärkeregler und stapelt\nsich mit den Farbanpassungen."),
        "layers": ("Echte Ebenen, mit\n16 Mischmodi",
                   "Umsortieren, ausblenden, duplizieren, nach unten\nzusammenführen oder alles reduzieren."),
        "grid": ("Fotoraster in\n18 Layouts",
                 "Zieh die Trennlinien und gewichte die Zellen um.\nJedes Werkzeug arbeitet darin weiter."),
        "objremove_panel": ("Objekt antippen,\nund es ist weg",
                            "Füllen baut den Hintergrund dahinter neu auf,\noder radiere es auf Transparenz."),
        "bubble": ("Texte und\nComic-Blasen",
                   "Sprech-, Denk-, Ruf- und Textkastenformen,\nfünf Display-Schriften, Kontur und Farbe."),
        "home": ("Kostenlos, und es\nbleibt auf dem Gerät",
                 "Kein Konto, kein Wasserzeichen. Jede Bearbeitung\nläuft auf dem Gerät, nichts geht hoch."),
    },
    "es": {
        "cutout_result": ("Quita el fondo\ncon IA",
                          "Dos modelos en el móvil, sin subida y sin cuenta.\nCon suavizado de borde."),
        "sticker": ("Convierte una foto\nen pegatina",
                    "Contorno y sombra paralela, ambos ajustables,\nexportado como PNG transparente."),
        "effects": ("14 estilos,\nHDR y viñeta",
                    "Cada estilo tiene control de intensidad y se suma\na los ajustes de color."),
        "layers": ("Capas de verdad,\n16 modos de fusión",
                   "Reordena, oculta, duplica, combina hacia abajo\no aplana toda la pila."),
        "grid": ("Collages de fotos\nen 18 diseños",
                 "Arrastra los divisores y repesa las celdas.\nCada herramienta sigue funcionando dentro."),
        "objremove_panel": ("Toca un objeto\npara quitarlo",
                            "Rellenar reconstruye el fondo detrás,\no bórralo y queda transparente."),
        "bubble": ("Textos y\nbocadillos de cómic",
                   "Formas de diálogo, pensamiento, grito y narración,\ncinco tipografías, contorno y color."),
        "home": ("Gratis, y se queda\nen tu móvil",
                 "Sin cuenta y sin marca de agua. Todo se procesa\nen el dispositivo, nunca se sube."),
    },
    "fr": {
        "cutout_result": ("Détourez\navec l'IA",
                          "Deux modèles sur l'appareil, sans envoi ni compte.\nBord adouci inclus."),
        "sticker": ("Une photo\ndevient un sticker",
                    "Contour et ombre portée, tous deux réglables,\nexportés en PNG transparent."),
        "effects": ("14 rendus, HDR\net vignettage",
                    "Chaque rendu a son curseur d'intensité et se cumule\navec les réglages de couleur."),
        "layers": ("De vrais calques,\n16 modes de fusion",
                   "Réordonnez, masquez, dupliquez, fusionnez vers\nle bas ou aplatissez toute la pile."),
        "grid": ("Collages photo,\n18 dispositions",
                 "Tirez les séparations pour repondérer les cellules.\nChaque outil y fonctionne encore."),
        "objremove_panel": ("Touchez un objet\npour l'effacer",
                            "Remplir reconstruit l\'arrière-plan derrière,\nou effacez-le en transparence."),
        "bubble": ("Légendes et\nbulles de BD",
                   "Formes dialogue, pensée, cri et cartouche,\ncinq polices d'affichage, contour et couleur."),
        "home": ("Gratuit, et tout\nreste sur l'appareil",
                 "Aucun compte, aucun filigrane. Tout est traité\nsur l'appareil, rien n'est envoyé."),
    },
    "cs": {
        "cutout_result": ("Odstraňte pozadí\npomocí AI",
                          "Dva modely přímo v zařízení, bez odesílání a bez účtu.\nVčetně změkčení okraje."),
        "sticker": ("Z fotky udělejte\nnálepku",
                    "Obrys kontury a vržený stín, oba nastavitelné,\nexport do průhledného PNG."),
        "effects": ("14 filtrů,\nHDR a vinětace",
                    "Každý filtr má posuvník síly a skládá se\ns barevnými úpravami."),
        "layers": ("Opravdové vrstvy,\n16 režimů prolnutí",
                   "Měňte pořadí, skryjte, duplikujte, slučte dolů\nnebo sloučte celý štos."),
        "grid": ("Fotokoláže\nv 18 rozvrženích",
                 "Přetažením předělů změníte váhu buněk.\nKaždý nástroj uvnitř dál funguje."),
        "objremove_panel": ("Klepněte na objekt\na zmizí",
                            "Vyplnit obnoví pozadí za ním,\nnebo jej vymažte do průhledna."),
        "bubble": ("Popisky a\nkomiksové bubliny",
                   "Tvary promluva, myšlenka, výkřik a popisek,\npět ozdobných písem, obrys a barva."),
        "home": ("Zdarma a zůstane\nve vašem telefonu",
                 "Bez účtu a bez vodoznaku. Vše se zpracuje\nv zařízení, nic se neodesílá."),
    },
}

# The 1024x500 feature graphic: two headline lines and two supporting lines,
# left of the fanned cards. Deliberately a general claim - this is a photo
# editor that happens to have AI cut-out, not an AI cut-out app that crops.
GRAPHIC = {
    "en": (["A real photo editor", "that runs on your phone"],
           ["Layers, 14 filters, HDR, collages, text",
            "and AI cut-out. Free, and no account."]),
    "pl": (["Prawdziwy edytor zdjęć,", "który działa w telefonie"],
           ["Warstwy, 14 filtrów, HDR, kolaże, tekst",
            "i wycinanie AI. Za darmo, bez konta."]),
    "de": (["Ein echter Fotoeditor,", "der auf dem Handy läuft"],
           ["Ebenen, 14 Filter, HDR, Collagen, Text",
            "und KI-Freisteller. Gratis, ohne Konto."]),
    # The break falls after "que" on purpose: "que funciona en tu móvil" is
    # 479px against a 477px column, and moving one word is cheaper than
    # rewording a claim that is already the right one.
    "es": (["Un editor de fotos que", "funciona en tu móvil"],
           ["Capas, 14 filtros, HDR, collages, texto",
            "y recorte con IA. Gratis y sin cuenta."]),
    "fr": (["Un vrai éditeur photo", "qui tourne sur l'appareil"],
           ["Calques, 14 filtres, HDR, collages, texte",
            "et détourage IA. Gratuit, sans compte."]),
    "cs": (["Opravdový editor fotek,", "který běží v telefonu"],
           ["Vrstvy, 14 filtrů, HDR, koláže, text",
            "a výřez s AI. Zdarma a bez účtu."]),
}


# ------------------------------------------------------------------ Google Ads
#
# Five concepts, each rendered as an image in all three App-campaign ratios and
# as a video. The wording is deliberately the SAME claim set as the Play
# listing above rather than a fresh pitch: a user who taps the ad lands on the
# listing, and an ad promising something the listing does not repeat is the
# classic app-campaign disapproval.
#
# ADS_CONCEPTS is the order they are numbered in, which is also the order to
# upload them - Google Ads shows no preference, but a stable numbering makes
# "swap asset 03" mean something.
ADS_CONCEPTS = ["cutout", "objremove", "editor", "bubbles", "free"]

# concept -> the captures it is built from, front-most FIRST. The image
# layouts use two (landscape) or three (square, portrait) of them; the video
# uses all three as its beats, in this order.
ADS_CAPTURES = {
    "cutout": ["cutout_result", "sticker", "objremove_panel"],
    "objremove": ["objremove_panel", "cutout_result", "grid"],
    "editor": ["effects", "grid", "layers"],
    "bubbles": ["bubble", "sticker", "layers"],
    "free": ["home", "effects", "grid"],
}

# The accent rule under each headline, keyed to the front capture's colour so
# an ad and the store screenshot of the same feature agree.
ADS_ACCENT = {k: ACCENT[v[0]] for k, v in ADS_CAPTURES.items()}

# locale -> concept -> (headline, supporting). Same hard \n rule as CAPTIONS.
# Every claim here is one already made in CAPTIONS or GRAPHIC, so
# tool/check_store_listings.py's count checks cover these too.
ADS = {
    "en": {
        "cutout": ("Cut the background\nout with AI",
                   "Two on-device models. No upload,\nno account, no watermark."),
        "objremove": ("Tap an object\nto remove it",
                      "The segmentation model finds its\noutline. Undo brings it back."),
        "editor": ("A real photo editor\nthat runs on your phone",
                   "Layers, 14 filters, HDR, collages,\ntext and AI cut-out."),
        "bubbles": ("Captions and\ncomic bubbles",
                    "Speech, thought, shout and caption\nshapes. Five display fonts."),
        "free": ("Free, and it stays\non your phone",
                 "No account, no watermark. Every edit\nis processed on the device."),
    },
    "pl": {
        "cutout": ("Wytnij tło\nza pomocą AI",
                   "Dwa modele na urządzeniu. Bez wysyłania,\nbez konta, bez znaku wodnego."),
        "objremove": ("Dotknij obiektu,\naby go usunąć",
                      "Model segmentacji sam znajdzie jego\nkontur. Cofnięcie go przywraca."),
        "editor": ("Prawdziwy edytor zdjęć,\nktóry działa w telefonie",
                   "Warstwy, 14 filtrów, HDR, kolaże,\ntekst i wycinanie AI."),
        "bubbles": ("Napisy i dymki\nkomiksowe",
                    "Kształty: mowa, myśl, krzyk i narracja.\nPięć krojów ozdobnych."),
        "free": ("Za darmo i zostaje\nna Twoim telefonie",
                 "Bez konta i bez znaku wodnego.\nWszystko liczone jest na urządzeniu."),
    },
    "de": {
        "cutout": ("Hintergrund weg,\nper KI",
                   "Zwei Modelle auf dem Gerät. Kein Upload,\nkein Konto, kein Wasserzeichen."),
        "objremove": ("Objekt antippen,\nund es ist weg",
                      "Das Segmentierungsmodell findet seine\nKontur. Rückgängig holt es zurück."),
        "editor": ("Ein echter Fotoeditor,\nder auf dem Handy läuft",
                   "Ebenen, 14 Filter, HDR, Collagen,\nText und KI-Freisteller."),
        "bubbles": ("Texte und\nComic-Blasen",
                    "Sprech-, Denk-, Ruf- und Textkastenformen.\nFünf Display-Schriften."),
        "free": ("Kostenlos, und es\nbleibt auf dem Gerät",
                 "Kein Konto, kein Wasserzeichen. Jede\nBearbeitung läuft auf dem Gerät."),
    },
    "es": {
        "cutout": ("Quita el fondo\ncon IA",
                   "Dos modelos en el móvil. Sin subida,\nsin cuenta, sin marca de agua."),
        "objremove": ("Toca un objeto\npara quitarlo",
                      "El modelo de segmentación halla su\ncontorno. Deshacer lo devuelve."),
        "editor": ("Un editor de fotos que\nfunciona en tu móvil",
                   "Capas, 14 filtros, HDR, collages,\ntexto y recorte con IA."),
        "bubbles": ("Textos y\nbocadillos de cómic",
                    "Formas de diálogo, pensamiento, grito\ny narración. Cinco tipografías."),
        "free": ("Gratis, y se queda\nen tu móvil",
                 "Sin cuenta y sin marca de agua. Todo\nse procesa en el dispositivo."),
    },
    "fr": {
        "cutout": ("Détourez\navec l'IA",
                   "Deux modèles sur l'appareil. Sans envoi,\nsans compte, sans filigrane."),
        "objremove": ("Touchez un objet\npour l'effacer",
                      "Le modèle de segmentation trouve son\ncontour. Annuler le fait revenir."),
        "editor": ("Un vrai éditeur photo\nqui tourne sur l'appareil",
                   "Calques, 14 filtres, HDR, collages,\ntexte et détourage IA."),
        "bubbles": ("Légendes et\nbulles de BD",
                    "Formes dialogue, pensée, cri et\ncartouche. Cinq polices d'affichage."),
        "free": ("Gratuit, et tout\nreste sur l'appareil",
                 "Aucun compte, aucun filigrane. Tout\nest traité sur l'appareil."),
    },
    "cs": {
        "cutout": ("Odstraňte pozadí\npomocí AI",
                   "Dva modely přímo v zařízení. Bez odesílání,\nbez účtu, bez vodoznaku."),
        "objremove": ("Klepněte na objekt\na zmizí",
                      "Segmentační model sám najde jeho\nobrys. Zpět jej vrátí."),
        "editor": ("Opravdový editor fotek,\nkterý běží v telefonu",
                   "Vrstvy, 14 filtrů, HDR, koláže,\ntext a výřez s AI."),
        "bubbles": ("Popisky a\nkomiksové bubliny",
                    "Tvary promluva, myšlenka, výkřik\na popisek. Pět ozdobných písem."),
        "free": ("Zdarma a zůstane\nve vašem telefonu",
                 "Bez účtu a bez vodoznaku. Vše se\nzpracuje v zařízení."),
    },
}

# The video's second and third beats. Beat one is the ADS headline above; these
# two are ONE line each, because a beat holds for three seconds and a viewer
# reads a line, not a paragraph. Keyed by concept, in capture order.
ADS_BEATS = {
    "en": {
        "cutout": ["Contour outline and drop shadow", "Or tap an object to remove it"],
        "objremove": ["The same AI cuts out the whole subject", "18 collage layouts to drop it into"],
        "editor": ["Photo grids in 18 layouts", "Real layers, 16 blend modes"],
        "bubbles": ["Any photo becomes a sticker", "On real layers you can reorder"],
        "free": ["14 one-tap looks, HDR and vignette", "Photo grids in 18 layouts"],
    },
    "pl": {
        "cutout": ["Obrys konturu i cień", "Albo dotknij obiektu, by go usunąć"],
        "objremove": ["Ta sama AI wycina cały obiekt", "18 układów kolażu, by go wkleić"],
        "editor": ["Kolaże zdjęć w 18 układach", "Prawdziwe warstwy, 16 trybów mieszania"],
        "bubbles": ["Każde zdjęcie staje się naklejką", "Na warstwach, które przestawisz"],
        "free": ["14 filtrów, HDR i winieta", "Kolaże zdjęć w 18 układach"],
    },
    "de": {
        "cutout": ["Kontur und Schlagschatten", "Oder Objekt antippen und es ist weg"],
        "objremove": ["Dieselbe KI stellt das ganze Motiv frei", "18 Collagen-Layouts dafür"],
        "editor": ["Fotoraster in 18 Layouts", "Echte Ebenen, 16 Mischmodi"],
        "bubbles": ["Jedes Foto wird zum Sticker", "Auf echten, sortierbaren Ebenen"],
        "free": ["14 Looks, HDR und Vignette", "Fotoraster in 18 Layouts"],
    },
    "es": {
        "cutout": ["Contorno y sombra paralela", "O toca un objeto para quitarlo"],
        "objremove": ["La misma IA recorta todo el sujeto", "18 diseños de collage para él"],
        "editor": ["Collages de fotos en 18 diseños", "Capas de verdad, 16 modos de fusión"],
        "bubbles": ["Cualquier foto se hace pegatina", "En capas de verdad, reordenables"],
        "free": ["14 estilos, HDR y viñeta", "Collages de fotos en 18 diseños"],
    },
    "fr": {
        "cutout": ["Contour et ombre portée", "Ou touchez un objet pour l'effacer"],
        "objremove": ["La même IA détoure tout le sujet", "18 dispositions de collage"],
        "editor": ["Collages photo, 18 dispositions", "De vrais calques, 16 modes de fusion"],
        "bubbles": ["Toute photo devient un sticker", "Sur de vrais calques réordonnables"],
        "free": ["14 rendus, HDR et vignettage", "Collages photo, 18 dispositions"],
    },
    "cs": {
        "cutout": ["Obrys kontury a vržený stín", "Nebo klepněte na objekt a zmizí"],
        "objremove": ["Stejná AI vyřízne celý objekt", "18 rozvržení koláže pro něj"],
        "editor": ["Fotokoláže v 18 rozvrženích", "Opravdové vrstvy, 16 režimů prolnutí"],
        "bubbles": ["Z každé fotky je nálepka", "Na vrstvách, které přeskládáte"],
        "free": ["14 filtrů, HDR a vinětace", "Fotokoláže v 18 rozvrženích"],
    },
}

# The closing line on the video end card. Short: it shares the frame with the
# wordmark and Google Ads draws its own install button underneath.
ADS_CLOSER = {
    "en": "Free on Google Play. No account.",
    "pl": "Za darmo w Google Play. Bez konta.",
    "de": "Gratis bei Google Play. Ohne Konto.",
    "es": "Gratis en Google Play. Sin cuenta.",
    "fr": "Gratuit sur Google Play. Sans compte.",
    "cs": "Zdarma na Google Play. Bez účtu.",
}


def shots(locale):
    """[(name, headline, supporting, accent)] in pitch order."""
    table = CAPTIONS[locale]
    return [(n, table[n][0], table[n][1], ACCENT[n]) for n in ORDER]


def ads(locale):
    """[(concept, headline, supporting, accent, captures)] in upload order."""
    table = ADS[locale]
    return [
        (k, table[k][0], table[k][1], ADS_ACCENT[k], ADS_CAPTURES[k])
        for k in ADS_CONCEPTS
    ]


# --------------------------------------------------------------------- check
#
# Budgets are the drawable width in each format, in the pixels of that
# format's own canvas. Each is derived from the renderer it belongs to, so a
# layout change here is one number, not a re-measure.
#
#   landscape  1920x1080  phone on one side, caption on the other. The phone is
#              936 tall at aspect 1280/2856 = 419 wide; margin 96 a side, and
#              84 of gap when the caption is on the right. Worst case 1225.
#   portrait   1080x1920  centred caption above a whole device, 72 a side.
#   tab10      2560x1440  headline left and supporting right ON ONE LINE, so
#              the budget is shared: 2560 - 220 of margin - 60 of gap.
#   tab7       1920x1080  the same layout at 0.75.
#
# The tablet renderer already falls back to a two-line supporting block when
# the pair will not fit, so its budget is a warning, not a hard stop; the two
# phone budgets are hard.
BUDGETS = [
    ("landscape head", DISPLAY, 92, "Bold", 1225, "headline"),
    ("landscape sub", BODY, 36, "Medium", 1225, "sub"),
    ("portrait head", DISPLAY, 58, "Bold", 936, "headline"),
    ("portrait sub", BODY, 27, "Medium", 936, "sub"),
]
# (name, head size, sub size, shared budget) - measured joined, one line each.
TABLET_BUDGETS = [("tablet-10in", 54, 30, 2560 - 220 - 60),
                  ("tablet-7in", 40, 22, 1920 - 165 - 45)]

# The Google Ads assets. Same rule, tighter rooms - see tool/gen_ads_assets.py
# (COPY) and tool/gen_ads_video.py (FORMATS) for where each width comes from.
#
# The image columns are narrower than the canvas twice over: Google crops these
# to placements it does not name in advance and asks for the important content
# in the centre 80%, so the copy starts a tenth of the way in, and the device
# art takes what is left. gen_ads_assets.check_safe_area asserts the rendered
# result, in every language; these budgets stop a line reaching the phone
# beside it first.
#
#   ads-landscape  1200x628   one phone right, copy left: 120 to 810.
#   ads-square     1200x1200  copy across the top, fan below: 1200 - 2*120.
#   ads-portrait   1200x1500  the same.
#   vid-landscape  1920x1080  one phone right, copy left: 160 to 1300.
#   vid-square     1080x1080  copy top, phone below: 1080 - 2*96.
#   vid-portrait   1080x1920  the same.
ADS_BUDGETS = [
    ("ads-landscape head", DISPLAY, 46, "Bold", 690, "head"),
    ("ads-landscape sub", BODY, 21, "Medium", 690, "sub"),
    ("ads-square head", DISPLAY, 64, "Bold", 960, "head"),
    ("ads-square sub", BODY, 28, "Medium", 960, "sub"),
    ("ads-portrait head", DISPLAY, 70, "Bold", 960, "head"),
    ("ads-portrait sub", BODY, 31, "Medium", 960, "sub"),
    ("vid-landscape head", DISPLAY, 78, "Bold", 1140, "head"),
    ("vid-landscape sub", BODY, 34, "Medium", 1140, "sub"),
    ("vid-square head", DISPLAY, 56, "Bold", 888, "head"),
    ("vid-square sub", BODY, 25, "Medium", 888, "sub"),
    ("vid-portrait head", DISPLAY, 62, "Bold", 888, "head"),
    ("vid-portrait sub", BODY, 27, "Medium", 888, "sub"),
]
# The one-line beat captions, drawn in the display face at the size the beat
# uses, into the same column.
ADS_BEAT_BUDGETS = [
    ("vid-landscape beat", DISPLAY, 46, "Bold", 1140),
    ("vid-square beat", DISPLAY, 34, "Bold", 888),
    ("vid-portrait beat", DISPLAY, 38, "Bold", 888),
]
# The end card's closing line, centred in the frame with the wordmark above it.
ADS_CLOSER_BUDGETS = [
    ("vid-landscape closer", BODY, 40, "Medium", 1400),
    ("vid-square closer", BODY, 29, "Medium", 900),
    ("vid-portrait closer", BODY, 31, "Medium", 900),
]


def _widths(path, size, weight):
    from fontTools.ttLib import TTFont
    from fontTools.varLib.instancer import instantiateVariableFont
    font = TTFont(path)
    axis = {"Bold": 700, "Medium": 500}[weight]
    try:
        font = instantiateVariableFont(font, {"wght": axis}, inplace=False)
    except Exception:
        pass
    upem = font["head"].unitsPerEm
    cmap = font.getBestCmap()
    hmtx = font["hmtx"]
    known = set(font.getGlyphOrder())

    def width(text):
        total = 0
        for ch in text:
            name = cmap.get(ord(ch))
            total += hmtx[name if name in known else ".notdef"][0]
        return total / upem * size

    return width


def main():
    over, warn = [], []
    for label, font_path, size, weight, budget, which in BUDGETS:
        width = _widths(font_path, size, weight)
        for loc in LOCALES:
            for name, head, sub, _ in shots(loc):
                text = head if which == "headline" else sub
                for line in text.split("\n"):
                    w = width(line)
                    if w > budget:
                        over.append((label, loc, name, line, w, budget))
    # The feature graphic's own block: 40px display, 19px body, from SAFE_X=64
    # to the back-left card's leading edge at x=541.
    head_w, sub_w = _widths(DISPLAY, 40, "Bold"), _widths(BODY, 19, "Medium")
    for loc in LOCALES:
        heads, subs = GRAPHIC[loc]
        for line in heads:
            if head_w(line) > 477:
                over.append(("graphic head", loc, "-", line, head_w(line), 477))
        for line in subs:
            if sub_w(line) > 477:
                over.append(("graphic sub", loc, "-", line, sub_w(line), 477))
    # ---- Google Ads: headlines and supporting lines, then the video's own
    # one-line beats and closer.
    for label, font_path, size, weight, budget, which in ADS_BUDGETS:
        width = _widths(font_path, size, weight)
        for loc in LOCALES:
            for concept, head, sub, _accent, _caps in ads(loc):
                text = head if which == "head" else sub
                for line in text.split("\n"):
                    if width(line) > budget:
                        over.append((label, loc, concept, line, width(line), budget))
    for label, font_path, size, weight, budget in ADS_BEAT_BUDGETS:
        width = _widths(font_path, size, weight)
        for loc in LOCALES:
            for concept in ADS_CONCEPTS:
                for line in ADS_BEATS[loc][concept]:
                    if width(line) > budget:
                        over.append((label, loc, concept, line, width(line), budget))
    for label, font_path, size, weight, budget in ADS_CLOSER_BUDGETS:
        width = _widths(font_path, size, weight)
        for loc in LOCALES:
            line = ADS_CLOSER[loc]
            if width(line) > budget:
                over.append((label, loc, "closer", line, width(line), budget))

    for label, hs, ss, budget in TABLET_BUDGETS:
        head_w, sub_w = _widths(DISPLAY, hs, "Bold"), _widths(BODY, ss, "Medium")
        for loc in LOCALES:
            for name, head, sub, _ in shots(loc):
                joined = head_w(head.replace("\n", " ")) + sub_w(sub.replace("\n", " "))
                if joined > budget:
                    warn.append((label, loc, name, joined, budget))

    for label, loc, name, joined, budget in warn:
        print("  %-11s %s %-16s %.0f/%.0f - supporting line wraps to two"
              % (label, loc, name, joined, budget))
    if warn:
        print()
    if not over:
        print("every caption line fits every format")
        return 0
    print("OVER BUDGET: %d" % len(over))
    for label, loc, name, line, w, budget in sorted(over, key=lambda r: -r[4]):
        print("  %-14s %s %-16s %.0f/%.0f  %r" % (label, loc, name, w, budget, line))
    return 1


if __name__ == "__main__":
    sys.exit(main())
