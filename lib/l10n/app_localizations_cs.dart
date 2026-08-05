// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appTitle => 'Chromis';

  @override
  String get back => 'Zpět';

  @override
  String get cancel => 'Zrušit';

  @override
  String get save => 'Uložit';

  @override
  String get done => 'Hotovo';

  @override
  String get delete => 'Smazat';

  @override
  String get rename => 'Přejmenovat';

  @override
  String get duplicate => 'Duplikovat';

  @override
  String get open => 'Otevřít';

  @override
  String get close => 'Zavřít';

  @override
  String get reset => 'Resetovat';

  @override
  String get apply => 'Použít';

  @override
  String get add => 'Přidat';

  @override
  String get remove => 'Odebrat';

  @override
  String get menu => 'Nabídka';

  @override
  String get settings => 'Nastavení';

  @override
  String get about => 'O aplikaci';

  @override
  String get licenses => 'Licence';

  @override
  String get nameHint => 'Název';

  @override
  String get cannotBeUndone => 'Tohle nejde vzít zpět.';

  @override
  String get tryAgainInAMoment => 'Zkus to za chvíli.';

  @override
  String get appLogo => 'Logo Chromis';

  @override
  String get pleaseTryAgain => 'zkus to prosím znovu';

  @override
  String get homeTitle => 'Tvoje projekty';

  @override
  String get homeTagline => 'Chromis · Fotoeditor s AI výřezem';

  @override
  String get homeRecent => 'NEDÁVNÉ';

  @override
  String get homeJoinDiscord => 'Přidej se na Discord';

  @override
  String get homeEmptyHint => 'Klepni na Nový projekt a naimportuj fotku.';

  @override
  String get noProjectsYet => 'Zatím žádné projekty';

  @override
  String get newProject => 'Nový projekt';

  @override
  String get homeNewProjectSubtitle => 'Prázdné plátno nebo mřížka fotek';

  @override
  String get homeOpenPhoto => 'Otevřít fotku';

  @override
  String get homeOpenPhotoSubtitle => 'Plátno převezme velikost fotky';

  @override
  String projectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count projektů',
      few: '$count projekty',
      one: '1 projekt',
    );
    return '$_temp0';
  }

  @override
  String layerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vrstev',
      few: '$count vrstvy',
      one: '1 vrstva',
    );
    return '$_temp0';
  }

  @override
  String get renameProject => 'Přejmenovat projekt';

  @override
  String get projectNameHint => 'Název projektu';

  @override
  String get copySuffix => '(kopie)';

  @override
  String deleteProjectTitle(String name) {
    return 'Smazat „$name“?';
  }

  @override
  String get allProjects => 'Všechny projekty';

  @override
  String get searchProjects => 'Hledej v projektech';

  @override
  String get projectsLoadFailed => 'Projekty se nepodařilo načíst';

  @override
  String get allProjectsEmptyHint =>
      'Vytvoř nějaký na domovské obrazovce a objeví se tady.';

  @override
  String get noMatches => 'Žádné výsledky';

  @override
  String noMatchesFor(String query) {
    return 'Nic neodpovídá „$query“.';
  }

  @override
  String get newProjectQuestion => 'Co budeš tvořit?';

  @override
  String get blankCanvas => 'Prázdné plátno';

  @override
  String get blankCanvasSubtitle =>
      'Jedno plátno, fotky a vrstvy přidávej volně';

  @override
  String get photoGrid => 'Mřížka fotek';

  @override
  String get photoGridSubtitle => 'Koláž ze 2 až 5 fotek v rozvržení';

  @override
  String get drawerHome => 'Domů a projekty';

  @override
  String drawerSubtitle(String version) {
    return 'Fotoeditor · v$version';
  }

  @override
  String get appearance => 'Vzhled';

  @override
  String get appearanceSystem => 'Výchozí nastavení systému';

  @override
  String get appearanceSystemSub =>
      'Podle světlého nebo tmavého režimu telefonu';

  @override
  String get appearanceLight => 'Světlý';

  @override
  String get appearanceLightSub => 'Lépe čitelný venku a na LCD displejích';

  @override
  String get appearanceDark => 'Tmavý';

  @override
  String get appearanceDarkSub =>
      'Čistá černá, kterou OLED displeje vůbec nerozsvítí';

  @override
  String get appearanceNote =>
      'Chromis se řídí telefonem, dokud si tu něco nevybereš. Tvoje volba se zapamatuje.';

  @override
  String get language => 'Jazyk';

  @override
  String get languageSystem => 'Jazyk systému';

  @override
  String get languageSystemSub =>
      'Použije jazyk, který máš nastavený v telefonu';

  @override
  String get languageNote =>
      'Chromis je v angličtině, pokud telefon nemáš nastavený na jazyk, do kterého je přeložený. Tvoji volbu si zapamatujeme.';

  @override
  String get skip => 'Přeskočit';

  @override
  String get next => 'Další';

  @override
  String get getStarted => 'Začít';

  @override
  String get onboardStartTitle => 'Začni fotkou';

  @override
  String get onboardStartBody =>
      'Otevři libovolnou fotku nebo prázdné plátno v té velikosti, kterou potřebuješ. Přidávej vrstvy, text a komiksové bubliny.';

  @override
  String get onboardCutoutTitle => 'Odstraň pozadí';

  @override
  String get onboardCutoutBody =>
      'Odděl motiv od pozadí jediným klepnutím, nebo maž objekty – všechno v zařízení, takže tvoje fotky nikdy neopustí telefon.';

  @override
  String get onboardExportTitle => 'Export a sdílení';

  @override
  String get onboardExportBody =>
      'Ulož průhledné PNG, JPG nebo WebP v libovolném rozlišení a sdílej ho kamkoli.';

  @override
  String get privacyTitle => 'Soukromí a cookies';

  @override
  String get privacyRowSub => 'Úpravy v zařízení · jak fungují reklamy';

  @override
  String get privacyBanner =>
      'Tvoje fotky zůstávají v tvém zařízení. Reklamy jsou jediná výjimka – vysvětlujeme ji níže.';

  @override
  String get privacyOnDevice =>
      'Fotky se upravují výhradně v tvém zařízení – nic se nikam nenahrává.';

  @override
  String get privacyAiLocal =>
      'Odstranění pozadí i objektů pomocí AI běží lokálně; fotky nikdy neopustí tvůj telefon.';

  @override
  String get privacyNoAccounts =>
      'Žádné účty, žádné přihlašování, žádné nahrávání fotek.';

  @override
  String get privacyAds =>
      'Bezplatná aplikace zobrazuje reklamy (Google AdMob), které používají reklamní ID.';

  @override
  String get privacyConsent =>
      'Tam, kde je to vyžadováno, ti výzva k souhlasu (UMP) dá na výběr mezi personalizovanými a nepersonalizovanými reklamami.';

  @override
  String get privacyWithdraw =>
      'Souhlas můžeš kdykoli změnit nebo odvolat – volba „Nastavení soukromí reklam“ níže formulář znovu otevře.';

  @override
  String get privacyPro =>
      'Jednorázové vylepšení na Pro odstraní všechny reklamy – a s nimi i reklamní ID.';

  @override
  String get fullPrivacyPolicy => 'Celé zásady ochrany soukromí';

  @override
  String get questions => 'Máš dotaz?';

  @override
  String get openSourceLicenses => 'Open-source licence';

  @override
  String get licensesRowSub => 'Skvělá práce, na které stavíme';

  @override
  String get licensesIntro =>
      'Chromis stojí na skvělé open-source práci. Díky všem, kdo ji vytvořili.';

  @override
  String get viewFullLicenseTexts => 'Zobrazit plná znění licencí';

  @override
  String get licenseCategoryFonts => 'Písma';

  @override
  String get licenseCategoryAi => 'AI v zařízení';

  @override
  String get licenseCategoryEncoding => 'Kódování médií';

  @override
  String get licenseCategoryMonetization => 'Monetizace';

  @override
  String get licenseCategoryFramework => 'Framework a balíčky';

  @override
  String get licenseUseDisplayFont => 'Nadpisové písmo';

  @override
  String get licenseUseBodyFont => 'Písmo UI a textu';

  @override
  String get licenseUseComicFont => 'Komiksové písmo popisků';

  @override
  String get licenseUseCaptionFont => 'Písmo popisků';

  @override
  String get licenseUseScriptFont => 'Psané písmo popisků';

  @override
  String get licenseUseBgRemoval => 'Odstranění pozadí (Android)';

  @override
  String get licenseUseRuntime => 'Spouští přibalený záložní model';

  @override
  String get licenseUseOnDeviceAi => 'Odstranění objektů a pozadí v zařízení';

  @override
  String get licenseUseEncoding => 'Kódování PNG / JPG / WebP';

  @override
  String get licenseUseAds => 'Bannery / reklamy s odměnou + souhlas';

  @override
  String get licenseUsePurchase => 'Jednorázový nákup Pro (odstranit reklamy)';

  @override
  String get licenseUseFramework => 'Framework aplikace';

  @override
  String get licenseUsePlugins => 'Směrování, úložiště, sdílení, výběr obrázků';

  @override
  String get licenseUseState => 'Správa stavu';

  @override
  String get licenseUseClipboard => 'Vložení obrázku ze schránky';

  @override
  String get goPro => 'Získat Pro';

  @override
  String get goProRemoveAds => 'Získat Pro · bez reklam';

  @override
  String get goProRemoveAdsPlain => 'Získat Pro – bez reklam';

  @override
  String get goProRowSub => 'Jednorázové vylepšení – nikdy žádné reklamy';

  @override
  String get goProHeroTitle => 'Odstraň reklamy navždy';

  @override
  String get goProHeroBody =>
      'Jednorázový nákup. Všechny AI funkce zůstávají zdarma – bez reklam, bez sledování reklamy před spuštěním.';

  @override
  String get goProBenefitNoAds => 'Žádné bannerové ani celoobrazovkové reklamy';

  @override
  String get goProBenefitNoRewarded =>
      'AI výřez a odstranění objektů bez reklamy s odměnou';

  @override
  String get goProBenefitOneTime => 'Jednorázová platba – žádné předplatné';

  @override
  String get goProBenefitSupports =>
      'Podporuje soukromé úpravy fotek v zařízení';

  @override
  String get goProOwned => 'Máš Pro – reklamy jsou vypnuté. Děkujeme!';

  @override
  String upgradeFor(String price) {
    return 'Vylepšit – $price';
  }

  @override
  String get restorePurchase => 'Obnovit nákup';

  @override
  String get oneTimeUnavailable => 'Jednorázový nákup · dočasně nedostupný';

  @override
  String get oneTimeRestores =>
      'Jednorázový nákup · obnoví se na každém zařízení';

  @override
  String get oneTimeNoSubscription => 'Jednorázový nákup. Žádné předplatné.';

  @override
  String get purchasesUnavailable =>
      'Nákupy jsou dočasně nedostupné – zkus to prosím později.';

  @override
  String get purchaseStartFailed =>
      'Nákup se nepodařilo zahájit – zkus to prosím znovu.';

  @override
  String get purchaseStartFailedOwned =>
      'Nákup se nepodařilo zahájit – pokud už Pro máš, klepni na Obnovit nákup.';

  @override
  String get checkingPreviousPurchase => 'Hledáme dřívější nákup…';

  @override
  String get playUnreachable =>
      'Nepodařilo se spojit s Google Play – zkontroluj připojení a zkus to znovu.';

  @override
  String get purchaseFailedGeneric => 'Nákup se nepodařilo dokončit';

  @override
  String get removeAdsArrow => 'Odstranit reklamy →';

  @override
  String get adsDeclinedExplainer =>
      'Reklamy nemáš povolené, takže není co sledovat – a přitom právě díky reklamám je Chromis zdarma.\n\nPovol reklamy a pokračuj zdarma, nebo přejdi na Pro a používej vše úplně bez reklam.';

  @override
  String get reviewAdConsent => 'Zkontrolovat souhlas s reklamami';

  @override
  String get adPrivacyChoices => 'Nastavení soukromí reklam';

  @override
  String get adPrivacyChoicesSub =>
      'Změň souhlas s personalizovanými reklamami';

  @override
  String adSettingsFailed(String error) {
    return 'Nepodařilo se otevřít nastavení reklam: $error';
  }

  @override
  String get untitledProject => 'Bez názvu';

  @override
  String get photoLayerDefault => 'Fotka';

  @override
  String get textLayerDefault => 'Text';

  @override
  String get mergedLayerName => 'Sloučeno';

  @override
  String get mergedLayerSuffix => 'po sloučení';

  @override
  String get saveRetrying =>
      'Uložení selhalo – úpravy jsou v bezpečí, zkoušíme dál';

  @override
  String get speed => 'Rychlost';

  @override
  String get fillingBackground => 'Vyplňování pozadí…';

  @override
  String get findingObject => 'Hledání objektu…';

  @override
  String get mergingLayers => 'Slučování vrstev…';

  @override
  String get removingBackground => 'Odstraňování pozadí…';

  @override
  String get hideToolPanel => 'Skrýt panel nástrojů';

  @override
  String get showToolPanel => 'Zobrazit panel nástrojů';

  @override
  String get cropOpenFailed => 'Fotku se nepodařilo otevřít k oříznutí';

  @override
  String get photoCropped => 'Fotka oříznuta';

  @override
  String get editCrop => 'Upravit ořez';

  @override
  String get cropPhoto => 'Oříznout fotku';

  @override
  String get resetCrop => 'Resetovat ořez';

  @override
  String get crop => 'Oříznout';

  @override
  String get cancelCrop => 'Zrušit ořez';

  @override
  String get previewUnavailable => 'Náhled není dostupný';

  @override
  String get cropToRatio => 'Oříznout na poměr';

  @override
  String get cropSheetHint =>
      'Vytáhni volný rámeček, nebo ořízni na poměr od středu';

  @override
  String get freeformCrop => 'Volný ořez';

  @override
  String get ratiosSection => 'POMĚRY';

  @override
  String croppedTo(int width, int height) {
    return 'Oříznuto na $width×$height';
  }

  @override
  String get snap => 'Přichytávání';

  @override
  String get snapHint =>
      'Vrstvy se zarovnávají k okrajům a středům ostatních a zastaví se na jejich velikosti.';

  @override
  String get scale => 'Měřítko';

  @override
  String get rotation => 'Otočení';

  @override
  String get horizontal => 'Vodorovně';

  @override
  String get vertical => 'Svisle';

  @override
  String get brightness => 'Jas';

  @override
  String get contrast => 'Kontrast';

  @override
  String get saturation => 'Sytost';

  @override
  String get hue => 'Odstín';

  @override
  String get opacity => 'Krytí';

  @override
  String get size => 'Velikost';

  @override
  String get color => 'Barva';

  @override
  String get off => 'Vyp.';

  @override
  String get adjustEmptyHint =>
      'Vyber vrstvu, kterou chceš zvětšit, otočit nebo upravit.\nNebo klepni na Přidat a naimportuj fotku.';

  @override
  String get effectsLink => 'Filtry, HDR, vinětace, stín…';

  @override
  String get effectsLinkLayer => 'Prolnutí, stín, obrys…';

  @override
  String get textEmptyHint => 'Vyber textovou vrstvu, nebo nějakou přidej.';

  @override
  String get addText => 'Přidat text';

  @override
  String get tapFontToPreview => 'Klepni na písmo pro náhled';

  @override
  String get typeYourCaption => 'Napiš popisek…';

  @override
  String get outlineSection => 'OBRYS';

  @override
  String get cutoutOutlineSection => 'OBRYS VÝŘEZU';

  @override
  String get autoColor => 'Automatická barva';

  @override
  String get thickness => 'Tloušťka';

  @override
  String get outlineOpacity => 'Krytí obrysu';

  @override
  String get font => 'Písmo';

  @override
  String fontAdded(String family) {
    return 'Přidáno písmo · $family';
  }

  @override
  String get comicBubble => 'Komiksová bublina';

  @override
  String get bubble => 'Bublina';

  @override
  String get bubbleTextHint => 'Text bubliny…';

  @override
  String get fill => 'Výplň';

  @override
  String get outline => 'Obrys';

  @override
  String get bubbleTailHint =>
      'Táhni za tečku na špičce ocásku a namiř ho – libovolným směrem.';

  @override
  String get addABubble => 'Přidat bublinu';

  @override
  String get addABubbleHint =>
      'Vyber formát. Text, barvy i ocásek se pak dají upravit – a formát taky.';

  @override
  String get addBubble => 'Přidat bublinu';

  @override
  String bubbleAdded(String format) {
    return 'Bublina „$format“ přidána – uprav ji v panelu';
  }

  @override
  String bubbleTileSemantics(String format, String description) {
    return 'Bublina „$format“ – $description';
  }

  @override
  String get bubbleSpeech => 'Promluva';

  @override
  String get bubbleThought => 'Myšlenka';

  @override
  String get bubbleShout => 'Výkřik';

  @override
  String get bubbleCaption => 'Popisek';

  @override
  String get bubbleWhisper => 'Šepot';

  @override
  String get bubbleSpeechBlurb => 'Zaoblená, s ocáskem';

  @override
  String get bubbleThoughtBlurb => 'Obláček se stopou teček';

  @override
  String get bubbleShoutBlurb => 'Špičatá hvězdice';

  @override
  String get bubbleCaptionBlurb => 'Hranatý rámeček s textem';

  @override
  String get bubbleWhisperBlurb => 'Přerušovaný obrys';

  @override
  String get notAPhotoGrid => 'Tenhle projekt není mřížka fotek.';

  @override
  String get shuffle => 'Zamíchat';

  @override
  String get photosSection => 'FOTKY';

  @override
  String get layoutSection => 'ROZVRŽENÍ';

  @override
  String get border => 'Okraj';

  @override
  String get corners => 'Rohy';

  @override
  String get effectsEmptyHint =>
      'Vyber vrstvu a dej jí vzhled.\nFiltry, HDR a vinětace pro fotky; stín, obrys a prolnutí pro cokoliv.';

  @override
  String get filterSection => 'FILTR';

  @override
  String get strength => 'Síla';

  @override
  String get hdrSection => 'HDR';

  @override
  String get toneAndDetail => 'Tón + detail';

  @override
  String get vignetteSection => 'VINĚTACE';

  @override
  String get amount => 'Míra';

  @override
  String get softness => 'Měkkost';

  @override
  String get shadowSection => 'STÍN';

  @override
  String get direction => 'Směr';

  @override
  String get distance => 'Vzdálenost';

  @override
  String get blur => 'Rozostření';

  @override
  String get density => 'Hustota';

  @override
  String get blendSection => 'PROLNUTÍ';

  @override
  String pixels(int count) {
    return '$count px';
  }

  @override
  String get working => 'Pracujeme…';

  @override
  String get undoRemoval => 'Vrátit odstranění';

  @override
  String get removeBackground => 'Odstranit pozadí';

  @override
  String get removeAnObject => 'Odstranit objekt';

  @override
  String get removeObject => 'Odstranit objekt';

  @override
  String get background => 'Pozadí';

  @override
  String get object => 'Objekt';

  @override
  String get erase => 'Mazat';

  @override
  String get restore => 'Obnovit';

  @override
  String get fillIn => 'Vyplnit';

  @override
  String get fillExplainer => 'Vyplnění obnoví pozadí z okolních částí fotky.';

  @override
  String get eraseExplainer => 'Mazání vymaže objekt do průhledna.';

  @override
  String get objectRemoveHint =>
      'Na fotce klepni na nechtěný objekt a odstraň ho – zatoulanou věc, druhý motiv, nepořádek. Klepnutí na hlavní motiv se bezpečně ignoruje; Zpět vrátí cokoliv.';

  @override
  String get cutoutSelectPhoto =>
      'Vyber vrstvu s fotkou, ze které chceš odstranit pozadí.';

  @override
  String get cutoutHint =>
      'Jedno klepnutí a motiv je izolovaný. Okraje najdeme automaticky – doladit je ručně můžeš v nástroji Mazání.';

  @override
  String get backgroundRestored => 'Pozadí obnoveno';

  @override
  String get aiModelSection => 'AI MODEL';

  @override
  String get whichAiModel => 'Který AI model?';

  @override
  String get segBuiltinLabel => 'Vestavěná AI';

  @override
  String get segBuiltinTagline => 'V zařízení · rychlé a soukromé';

  @override
  String get segBuiltinBlurb =>
      'Běží přímo v zařízení, takže výřezy jsou rychlé a soukromé. Skvělá na zvířata i lidi s jasnými okraji – nic neopustí tvůj telefon.';

  @override
  String get segU2netTagline => 'Open-source · ostřejší detail';

  @override
  String get segU2netBlurb =>
      'Open-source model pro hlavní objekt, přibalený v aplikaci. Funguje zcela offline a bývá ostřejší na jemné detaily jako srst, vlasy nebo vousky – jen běží o něco pomaleji.';

  @override
  String get aiGateTitle => 'Odemkni AI nástroje';

  @override
  String get aiGateMessage =>
      'Zhlédni krátkou reklamu a používej AI nástroje po zbytek této relace úprav. S Pro je máš bez reklam, navždy.';

  @override
  String get aiGateWatch => 'Zhlédnout a odemknout';

  @override
  String get aiGateNotRewarded =>
      'Zhlédni celou reklamu a používej AI, nebo přejdi na Pro a zbav se reklam';

  @override
  String get objectAiUnavailable =>
      'AI pro odstranění objektů není na tomto zařízení dostupná – použij štětec Mazání';

  @override
  String get bgRemovalUnavailable =>
      'Odstranění pozadí zatím na tomto zařízení není dostupné';

  @override
  String get layerGoneCutoutDiscarded =>
      'Ta vrstva je pryč – výřez byl zahozen';

  @override
  String get backgroundRemoved => 'Pozadí odstraněno';

  @override
  String backgroundRemovedWith(String engine) {
    return 'Pozadí odstraněno · $engine';
  }

  @override
  String get bgRemovalFailed =>
      'Pozadí se nepodařilo odstranit – zkus to znovu';

  @override
  String get selectPhotoToCutOut =>
      'Vyber vrstvu s fotkou, ze které chceš odstranit pozadí';

  @override
  String get detectingSubject =>
      'Hledáme motiv a dolaďujeme okraje · v zařízení';

  @override
  String get edgeFeather => 'Prolnutí okrajů';

  @override
  String get applyToLayer => 'Použít na vrstvu';

  @override
  String get tapObjectsToErase => 'Na fotce klepni na objekty a vymaž je';

  @override
  String get tapObjectsToRemove => 'Klepni na objekty a odstraň je';

  @override
  String get tapAnObjectToRemove =>
      'Na fotce klepni na objekt, který chceš odstranit';

  @override
  String get chooseAiEngine => 'Vyber AI engine · běží v tvém zařízení';

  @override
  String get autoRefineEdges => 'Automaticky doladit okraje';

  @override
  String get brushFailed => 'Štětec se nepodařilo použít';

  @override
  String get nothingToRemoveThere => 'Tam není co odstranit';

  @override
  String get objectRemoved => 'Objekt odstraněn – Zpět ho vrátí';

  @override
  String get objectRemoveFailed =>
      'Tohle se nepodařilo odstranit – zkus to znovu';

  @override
  String get noObjectThere => 'Na tom místě se nepodařilo najít objekt';

  @override
  String get thatLooksLikeSubject =>
      'Vypadá to jako tvůj hlavní motiv – na jemné úpravy použij Mazání';

  @override
  String get fillUnavailable =>
      'Tuto oblast se nepodařilo obnovit – objekt byl vymazán';

  @override
  String get objectFilled => 'Objekt vyplněn – Zpět to vrátí';

  @override
  String get eraseEmptyHint =>
      'Vyber vrstvu s fotkou, na které chceš mazat, nebo přidej fotku.';

  @override
  String get brushOverCanvas => 'Přejeď štětcem po plátně';

  @override
  String get brushSize => 'Velikost štětce';

  @override
  String get softEdges => 'Měkké okraje';

  @override
  String get play => 'Přehrát';

  @override
  String get pause => 'Pozastavit';

  @override
  String get newLayersToAllFrames => 'Nové vrstvy do všech snímků';

  @override
  String get onionSkin => 'Cibulová slupka (náhled předchozího)';

  @override
  String get duplicateFrame => 'Duplikovat snímek';

  @override
  String get moveLeft => 'Posunout doleva';

  @override
  String get moveRight => 'Posunout doprava';

  @override
  String get deleteFrame => 'Smazat snímek';

  @override
  String frameOf(int current, int total) {
    return 'Snímek $current / $total';
  }

  @override
  String get mergeDown => 'Sloučit dolů';

  @override
  String get flatten => 'Sloučit vše';

  @override
  String get layersEmptyHint =>
      'Zatím žádné vrstvy. Klepni na Přidat a naimportuj fotku nebo přidej text.';

  @override
  String get mergedTwoLayers => 'Sloučeny 2 vrstvy';

  @override
  String flattenedLayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sloučeno $count vrstev',
      few: 'Sloučeny $count vrstvy',
      one: 'Sloučena 1 vrstva',
    );
    return '$_temp0';
  }

  @override
  String get mergeFailed => 'Tyto vrstvy se nepodařilo sloučit';

  @override
  String get importPhotoFailed => 'Fotku se nepodařilo naimportovat';

  @override
  String get noImageInClipboard => 'Ve schránce není žádný obrázek';

  @override
  String get pasteFailed => 'Obrázek se nepodařilo vložit';

  @override
  String get takePhoto => 'Vyfotit';

  @override
  String get choosePhoto => 'Vybrat fotku';

  @override
  String get pasteImage => 'Vložit obrázek';

  @override
  String get renameLayer => 'Přejmenovat vrstvu';

  @override
  String get canvasSize => 'Velikost plátna';

  @override
  String get addLayer => 'Fotka';

  @override
  String get aiCut => 'AI výřez';

  @override
  String get seeThePrice => 'Zobrazit cenu';

  @override
  String get notNow => 'Teď ne';

  @override
  String get oneTimeNoSubscriptionShort =>
      'Jednorázový nákup, žádné předplatné';

  @override
  String get proBenefitNoAdsTitle => 'Žádné reklamy, nikde';

  @override
  String get proBenefitNoAdsBody =>
      'Banner na domovské obrazovce i celoobrazovkové reklamy zmizí navždy.';

  @override
  String get proBenefitAiTitle => 'AI bez čekání';

  @override
  String get proBenefitAiBody =>
      'Odstranění pozadí i mazání objektů proběhne hned – bez reklamy s odměnou.';

  @override
  String get proBenefitExportTitle => 'Exportuj a sdílej bez omezení';

  @override
  String get proBenefitExportBody =>
      'Ulož nebo sdílej v jakékoli velikosti bez sledování reklam.';

  @override
  String get proBenefitLocalTitle => 'Pořád ve tvém zařízení';

  @override
  String get proBenefitLocalBody =>
      'Verze Pro nemění nic na tvých fotkách: každá úprava zůstává v zařízení, jako vždycky.';

  @override
  String get textLayer => 'Textová vrstva';

  @override
  String get bubbleLayer => 'Vrstva s bublinou';

  @override
  String get imageLayer => 'Obrázková vrstva';

  @override
  String get imageLayerCutOut => 'Obrázková vrstva · výřez';

  @override
  String dragToReorder(String name) {
    return 'Přetažením změníš pořadí: $name';
  }

  @override
  String get hideLayer => 'Skrýt vrstvu';

  @override
  String get showLayer => 'Zobrazit vrstvu';

  @override
  String get duplicateLayer => 'Duplikovat vrstvu';

  @override
  String get deleteLayer => 'Smazat vrstvu';

  @override
  String deleteLayerNamed(String name) {
    return 'Smazat vrstvu $name';
  }

  @override
  String get cutOut => 'Výřez';

  @override
  String get tapToAddPhoto => 'Klepnutím přidáš fotku';

  @override
  String get undo => 'Zpět';

  @override
  String get redo => 'Znovu';

  @override
  String get export => 'Exportovat';

  @override
  String get customPixels => 'VLASTNÍ (PIXELY)';

  @override
  String get width => 'Šířka';

  @override
  String get height => 'Výška';

  @override
  String get create => 'Vytvořit';

  @override
  String get scaleLayersToFit => 'Přizpůsobit vrstvy velikosti';

  @override
  String get scaleLayersToFitSub =>
      'Přepočítat celou kompozici na novou velikost';

  @override
  String get presetSquare => 'Čtverec';

  @override
  String get presetPortrait => 'Na výšku';

  @override
  String get presetStory => 'Story';

  @override
  String get presetLandscape => 'Na šířku';

  @override
  String get presetWide => 'Široké';

  @override
  String get presetSmall => 'Malé';

  @override
  String layersAutoSaved(String layers) {
    return '$layers · automaticky uloženo';
  }

  @override
  String engineWorking(String engine) {
    return '$engine pracuje…';
  }

  @override
  String get toolLayers => 'Vrstvy';

  @override
  String get toolAdjust => 'Úpravy';

  @override
  String get toolEffects => 'Efekty';

  @override
  String get toolText => 'Text';

  @override
  String get toolErase => 'Mazání';

  @override
  String get toolErasePanel => 'Ruční mazání';

  @override
  String get toolCutout => 'Výřez';

  @override
  String get toolCutoutPanel => 'AI odstranění pozadí';

  @override
  String get toolFrames => 'Snímky';

  @override
  String get toolFramesPanel => 'Snímky animace';

  @override
  String get toolGrid => 'Mřížka';

  @override
  String get toolGridPanel => 'Mřížka fotek';

  @override
  String get filterOriginal => 'Originál';

  @override
  String get filterVivid => 'Živé';

  @override
  String get filterPunch => 'Výrazné';

  @override
  String get filterChrome => 'Chrom';

  @override
  String get filterWarm => 'Teplé';

  @override
  String get filterCool => 'Studené';

  @override
  String get filterSunset => 'Západ';

  @override
  String get filterDawn => 'Úsvit';

  @override
  String get filterDusk => 'Soumrak';

  @override
  String get filterFade => 'Vybledlé';

  @override
  String get filterMatte => 'Matné';

  @override
  String get filterRetro => 'Retro';

  @override
  String get filterSepia => 'Sépie';

  @override
  String get filterMono => 'Mono';

  @override
  String get filterNoir => 'Noir';

  @override
  String get blendNormal => 'Normální';

  @override
  String get blendMultiply => 'Násobit';

  @override
  String get blendScreen => 'Závoj';

  @override
  String get blendOverlay => 'Překrýt';

  @override
  String get blendDarken => 'Ztmavit';

  @override
  String get blendLighten => 'Zesvětlit';

  @override
  String get blendDodge => 'Zesvětlit barvy';

  @override
  String get blendBurn => 'Ztmavit barvy';

  @override
  String get blendHardLight => 'Tvrdé světlo';

  @override
  String get blendSoftLight => 'Měkké světlo';

  @override
  String get blendDifference => 'Rozdíl';

  @override
  String get blendExclusion => 'Vyloučení';

  @override
  String get blendHue => 'Odstín';

  @override
  String get blendSaturation => 'Sytost';

  @override
  String get blendColor => 'Barva';

  @override
  String get blendLuminosity => 'Světlost';

  @override
  String get gridHowManyPhotos => 'KOLIK FOTEK?';

  @override
  String get gridLayoutLabel => 'ROZVRŽENÍ';

  @override
  String get gridSizeLabel => 'VELIKOST';

  @override
  String get gridSetupHint =>
      'Fotky vybereš hned potom – rozvržení, počet i okraj můžeš kdykoli změnit.';

  @override
  String photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotek',
      few: '$count fotky',
      one: '1 fotka',
    );
    return '$_temp0';
  }

  @override
  String gridLayoutNamed(String name) {
    return 'Rozvržení $name';
  }

  @override
  String get gridSideBySide => 'Vedle sebe';

  @override
  String get gridStacked => 'Nad sebou';

  @override
  String get gridWideLeft => 'Široká vlevo';

  @override
  String get gridTallTop => 'Vysoká nahoře';

  @override
  String get gridColumns => 'Sloupce';

  @override
  String get gridRows => 'Řádky';

  @override
  String get gridBigLeft => 'Velká vlevo';

  @override
  String get gridBigTop => 'Velká nahoře';

  @override
  String get gridTwoByTwo => '2 x 2';

  @override
  String get gridTwoOverThree => '2 nad 3';

  @override
  String get gridThreeOverTwo => '3 nad 2';

  @override
  String get gridTwoLeftThreeRight => '2 vedle 3';

  @override
  String get exportTitle => 'Export a sdílení';

  @override
  String get formatLabel => 'FORMÁT';

  @override
  String get formatPngSub => 'průhledné';

  @override
  String get formatJpgSub => 'bez průhlednosti';

  @override
  String get formatWebpSub => 'menší';

  @override
  String get resolutionLabel => 'ROZLIŠENÍ';

  @override
  String exportOutput(
    int width,
    int height,
    String format,
    String transparent,
  ) {
    return 'Výstup · $width × $height px · $format$transparent';
  }

  @override
  String get transparentParenthetical => '(průhledné)';

  @override
  String get saveToDevice => 'Uložit do zařízení';

  @override
  String get share => 'Sdílet';

  @override
  String savedTo(String location) {
    return 'Uloženo · $location';
  }

  @override
  String get storageDenied =>
      'Povol přístup k úložišti, aby šlo ukládat do galerie';

  @override
  String get saveFailed => 'Obrázek se nepodařilo uložit';

  @override
  String get exportFailed => 'Export selhal – zkus to znovu';

  @override
  String get shareFailed => 'Sdílení selhalo – zkus to znovu';

  @override
  String get exportGateTitle => 'Zhlédni krátkou reklamu a exportuj';

  @override
  String get exportGateMessage =>
      'Bezplatné exporty podporuje krátká reklama. Přejdi na Pro a exportuj bez reklam, navždy.';

  @override
  String get exportGateWatch => 'Zhlédnout a exportovat';

  @override
  String get swatchWhite => 'bílá';

  @override
  String get swatchBlack => 'černá';

  @override
  String get swatchPink => 'růžová';

  @override
  String get swatchAmber => 'jantarová';

  @override
  String get swatchGreen => 'zelená';

  @override
  String get swatchCyan => 'azurová';

  @override
  String get swatchViolet => 'fialová';

  @override
  String get swatchRose => 'světle růžová';

  @override
  String get swatchOrange => 'oranžová';
}
