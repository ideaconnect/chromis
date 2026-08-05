// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Chromis';

  @override
  String get back => 'Wstecz';

  @override
  String get cancel => 'Anuluj';

  @override
  String get save => 'Zapisz';

  @override
  String get done => 'Gotowe';

  @override
  String get delete => 'Usuń';

  @override
  String get rename => 'Zmień nazwę';

  @override
  String get duplicate => 'Duplikuj';

  @override
  String get open => 'Otwórz';

  @override
  String get close => 'Zamknij';

  @override
  String get reset => 'Resetuj';

  @override
  String get apply => 'Zastosuj';

  @override
  String get add => 'Dodaj';

  @override
  String get remove => 'Usuń';

  @override
  String get menu => 'Menu';

  @override
  String get settings => 'Ustawienia';

  @override
  String get about => 'O aplikacji';

  @override
  String get licenses => 'Licencje';

  @override
  String get nameHint => 'Nazwa';

  @override
  String get cannotBeUndone => 'Tej operacji nie można cofnąć.';

  @override
  String get tryAgainInAMoment => 'Spróbuj ponownie za chwilę.';

  @override
  String get appLogo => 'Logo Chromis';

  @override
  String get pleaseTryAgain => 'spróbuj ponownie';

  @override
  String get homeTitle => 'Twoje projekty';

  @override
  String get homeTagline => 'Chromis · Edytor zdjęć z wycinaniem AI';

  @override
  String get homeRecent => 'OSTATNIE';

  @override
  String get homeJoinDiscord => 'Dołącz do naszego Discorda';

  @override
  String get homeEmptyHint =>
      'Dotknij „Nowy projekt”, aby zaimportować zdjęcie.';

  @override
  String get noProjectsYet => 'Nie masz jeszcze projektów';

  @override
  String get newProject => 'Nowy projekt';

  @override
  String get homeNewProjectSubtitle => 'Puste płótno albo siatka zdjęć';

  @override
  String get homeOpenPhoto => 'Otwórz zdjęcie';

  @override
  String get homeOpenPhotoSubtitle => 'Płótno przyjmie rozmiar zdjęcia';

  @override
  String projectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count projektu',
      many: '$count projektów',
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
      other: '$count warstwy',
      many: '$count warstw',
      few: '$count warstwy',
      one: '1 warstwa',
    );
    return '$_temp0';
  }

  @override
  String get renameProject => 'Zmień nazwę projektu';

  @override
  String get projectNameHint => 'Nazwa projektu';

  @override
  String get copySuffix => '(kopia)';

  @override
  String deleteProjectTitle(String name) {
    return 'Usunąć „$name”?';
  }

  @override
  String get allProjects => 'Wszystkie projekty';

  @override
  String get searchProjects => 'Szukaj w projektach';

  @override
  String get projectsLoadFailed => 'Nie udało się wczytać projektów';

  @override
  String get allProjectsEmptyHint =>
      'Utwórz projekt na ekranie startowym, a pojawi się tutaj.';

  @override
  String get noMatches => 'Brak wyników';

  @override
  String noMatchesFor(String query) {
    return 'Nic nie pasuje do „$query”.';
  }

  @override
  String get newProjectQuestion => 'Co tworzysz?';

  @override
  String get blankCanvas => 'Puste płótno';

  @override
  String get blankCanvasSubtitle =>
      'Jedno płótno, dodawaj zdjęcia i warstwy dowolnie';

  @override
  String get photoGrid => 'Siatka zdjęć';

  @override
  String get photoGridSubtitle => 'Kolaż z 2–5 zdjęć w gotowym układzie';

  @override
  String get drawerHome => 'Start i projekty';

  @override
  String drawerSubtitle(String version) {
    return 'Edytor zdjęć · v$version';
  }

  @override
  String get appearance => 'Wygląd';

  @override
  String get appearanceSystem => 'Domyślne ustawienie systemu';

  @override
  String get appearanceSystemSub =>
      'Zgodnie z jasnym lub ciemnym motywem telefonu';

  @override
  String get appearanceLight => 'Jasny';

  @override
  String get appearanceLightSub =>
      'Łatwiejszy do czytania na dworze i na ekranach LCD';

  @override
  String get appearanceDark => 'Ciemny';

  @override
  String get appearanceDarkSub =>
      'Czysta czerń, której ekrany OLED w ogóle nie podświetlają';

  @override
  String get appearanceNote =>
      'Chromis dostosowuje się do telefonu, chyba że wybierzesz motyw tutaj. Twój wybór zostanie zapamiętany.';

  @override
  String get language => 'Język';

  @override
  String get languageSystem => 'Domyślny język systemu';

  @override
  String get languageSystemSub => 'Zgodnie z językiem ustawionym w telefonie';

  @override
  String get languageNote =>
      'Chromis działa po angielsku, chyba że w telefonie ustawiony jest jeden z języków, na które go przetłumaczono. Twój wybór zostanie zapamiętany.';

  @override
  String get skip => 'Pomiń';

  @override
  String get next => 'Dalej';

  @override
  String get getStarted => 'Zaczynajmy';

  @override
  String get onboardStartTitle => 'Zacznij od zdjęcia';

  @override
  String get onboardStartBody =>
      'Otwórz dowolne zdjęcie albo puste płótno w wybranym rozmiarze. Dodawaj warstwy, tekst i dymki komiksowe.';

  @override
  String get onboardCutoutTitle => 'Wytnij tło';

  @override
  String get onboardCutoutBody =>
      'Odetnij obiekt od tła jednym dotknięciem albo usuń zbędne elementy - wszystko na Twoim urządzeniu, więc zdjęcia nigdy nie opuszczają telefonu.';

  @override
  String get onboardExportTitle => 'Eksportuj i udostępniaj';

  @override
  String get onboardExportBody =>
      'Zapisz w dowolnej rozdzielczości plik PNG lub WebP z przezroczystością albo JPG i udostępnij go, gdzie chcesz.';

  @override
  String get privacyTitle => 'Prywatność i cookies';

  @override
  String get privacyRowSub => 'Edycja na urządzeniu · jak działają reklamy';

  @override
  String get privacyBanner =>
      'Twoje zdjęcia zostają na urządzeniu. Jedynym wyjątkiem są reklamy - wyjaśniamy to poniżej.';

  @override
  String get privacyOnDevice =>
      'Twoje zdjęcia są edytowane wyłącznie na Twoim urządzeniu - nic nie jest wysyłane.';

  @override
  String get privacyAiLocal =>
      'Usuwanie tła i obiektów przez AI działa lokalnie; zdjęcia nigdy nie opuszczają telefonu.';

  @override
  String get privacyNoAccounts =>
      'Bez kont, bez logowania, bez wysyłania zdjęć.';

  @override
  String get privacyAds =>
      'Darmowa aplikacja wyświetla reklamy (Google AdMob), które korzystają z identyfikatora reklamowego.';

  @override
  String get privacyConsent =>
      'Tam, gdzie jest to wymagane, okno zgody (UMP) pozwala wybrać reklamy spersonalizowane lub niespersonalizowane.';

  @override
  String get privacyWithdraw =>
      'Możesz zmienić lub wycofać tę zgodę w dowolnej chwili - „Ustawienia prywatności reklam” poniżej otwiera formularz ponownie.';

  @override
  String get privacyPro =>
      'Jednorazowy zakup Pro usuwa wszystkie reklamy - a wraz z nimi identyfikator reklamowy.';

  @override
  String get fullPrivacyPolicy => 'Pełna polityka prywatności';

  @override
  String get questions => 'Pytania?';

  @override
  String get openSourceLicenses => 'Licencje open source';

  @override
  String get licensesRowSub => 'Świetna praca, na której się opieramy';

  @override
  String get licensesIntro =>
      'Chromis powstał dzięki wspaniałej pracy społeczności open source. Dziękujemy wszystkim twórcom.';

  @override
  String get viewFullLicenseTexts => 'Zobacz pełne teksty licencji';

  @override
  String get licenseCategoryFonts => 'Czcionki';

  @override
  String get licenseCategoryAi => 'AI na urządzeniu';

  @override
  String get licenseCategoryEncoding => 'Kodowanie multimediów';

  @override
  String get licenseCategoryMonetization => 'Monetyzacja';

  @override
  String get licenseCategoryFramework => 'Framework i pakiety';

  @override
  String get licenseUseDisplayFont => 'Krój tytułowy / nagłówkowy';

  @override
  String get licenseUseBodyFont => 'Krój interfejsu / tekstu';

  @override
  String get licenseUseComicFont => 'Czcionka podpisów komiksowych';

  @override
  String get licenseUseCaptionFont => 'Czcionka podpisów';

  @override
  String get licenseUseScriptFont => 'Odręczna czcionka podpisów';

  @override
  String get licenseUseBgRemoval => 'Usuwanie tła (Android)';

  @override
  String get licenseUseRuntime => 'Uruchamia dołączony model zapasowy';

  @override
  String get licenseUseOnDeviceAi => 'Usuwanie obiektów i tła na urządzeniu';

  @override
  String get licenseUseEncoding => 'Kodowanie PNG / JPG / WebP';

  @override
  String get licenseUseAds => 'Reklamy banerowe i z nagrodą oraz zgody';

  @override
  String get licenseUsePurchase => 'Jednorazowy zakup Pro (bez reklam)';

  @override
  String get licenseUseFramework => 'Framework aplikacji';

  @override
  String get licenseUsePlugins =>
      'Nawigacja, przechowywanie, udostępnianie, wybór zdjęć';

  @override
  String get licenseUseState => 'Zarządzanie stanem';

  @override
  String get licenseUseClipboard => 'Wklejanie obrazu ze schowka';

  @override
  String get goPro => 'Kup Pro';

  @override
  String get goProRemoveAds => 'Kup Pro · bez reklam';

  @override
  String get goProRemoveAdsPlain => 'Kup Pro - bez reklam';

  @override
  String get goProRowSub => 'Jednorazowy zakup - żadnych reklam';

  @override
  String get goProHeroTitle => 'Usuń reklamy na zawsze';

  @override
  String get goProHeroBody =>
      'Zakup jednorazowy. Wszystkie funkcje AI pozostają darmowe - bez reklam i bez oglądania ich przed użyciem.';

  @override
  String get goProBenefitNoAds => 'Bez banerów i reklam pełnoekranowych';

  @override
  String get goProBenefitNoRewarded =>
      'Wycinanie AI i usuwanie obiektów bez reklamy z nagrodą';

  @override
  String get goProBenefitOneTime => 'Płatność jednorazowa - bez abonamentu';

  @override
  String get goProBenefitSupports =>
      'Wspierasz prywatną edycję zdjęć na urządzeniu';

  @override
  String get goProOwned =>
      'Masz wersję Pro - reklamy są wyłączone. Dziękujemy!';

  @override
  String upgradeFor(String price) {
    return 'Kup - $price';
  }

  @override
  String get restorePurchase => 'Przywróć zakup';

  @override
  String get oneTimeUnavailable => 'Zakup jednorazowy · chwilowo niedostępny';

  @override
  String get oneTimeRestores =>
      'Zakup jednorazowy · przywracany na każdym urządzeniu';

  @override
  String get oneTimeNoSubscription => 'Zakup jednorazowy. Bez abonamentu.';

  @override
  String get purchasesUnavailable =>
      'Zakupy są chwilowo niedostępne - spróbuj ponownie później.';

  @override
  String get purchaseStartFailed =>
      'Nie udało się rozpocząć zakupu - spróbuj ponownie.';

  @override
  String get purchaseStartFailedOwned =>
      'Nie udało się rozpocząć zakupu - jeśli masz już wersję Pro, dotknij „Przywróć zakup”.';

  @override
  String get checkingPreviousPurchase => 'Sprawdzanie wcześniejszych zakupów…';

  @override
  String get playUnreachable =>
      'Nie udało się połączyć z Google Play - sprawdź połączenie i spróbuj ponownie.';

  @override
  String get purchaseFailedGeneric => 'Nie udało się dokończyć zakupu';

  @override
  String get removeAdsArrow => 'Usuń reklamy →';

  @override
  String get adsDeclinedExplainer =>
      'Reklamy są wyłączone w Twoich ustawieniach zgody, więc nie ma czego obejrzeć - a to reklamy sprawiają, że Chromis jest darmowy.\n\nZezwól na reklamy, aby korzystać dalej za darmo, albo kup Pro i używaj wszystkiego zupełnie bez reklam.';

  @override
  String get reviewAdConsent => 'Przejrzyj zgodę na reklamy';

  @override
  String get adPrivacyChoices => 'Ustawienia prywatności reklam';

  @override
  String get adPrivacyChoicesSub => 'Zmień zgodę na reklamy spersonalizowane';

  @override
  String adSettingsFailed(String error) {
    return 'Nie udało się otworzyć ustawień reklam: $error';
  }

  @override
  String get untitledProject => 'Bez tytułu';

  @override
  String get photoLayerDefault => 'Zdjęcie';

  @override
  String get textLayerDefault => 'Tekst';

  @override
  String get mergedLayerName => 'Scalone';

  @override
  String get mergedLayerSuffix => 'po scaleniu';

  @override
  String get saveRetrying =>
      'Nie udało się zapisać - Twoje zmiany są bezpieczne, próbujemy dalej';

  @override
  String get speed => 'Prędkość';

  @override
  String get fillingBackground => 'Uzupełnianie tła…';

  @override
  String get findingObject => 'Wyszukiwanie obiektu…';

  @override
  String get mergingLayers => 'Scalanie warstw…';

  @override
  String get removingBackground => 'Usuwanie tła…';

  @override
  String get hideToolPanel => 'Ukryj panel narzędzi';

  @override
  String get showToolPanel => 'Pokaż panel narzędzi';

  @override
  String get cropOpenFailed => 'Nie udało się otworzyć zdjęcia do kadrowania';

  @override
  String get photoCropped => 'Zdjęcie wykadrowane';

  @override
  String get editCrop => 'Edytuj kadr';

  @override
  String get cropPhoto => 'Kadruj zdjęcie';

  @override
  String get resetCrop => 'Resetuj kadr';

  @override
  String get crop => 'Kadruj';

  @override
  String get cancelCrop => 'Anuluj kadrowanie';

  @override
  String get previewUnavailable => 'Podgląd niedostępny';

  @override
  String get cropToRatio => 'Kadruj do proporcji';

  @override
  String get cropSheetHint =>
      'Przeciągnij dowolny prostokąt albo wykadruj od środka do proporcji';

  @override
  String get freeformCrop => 'Kadrowanie dowolne';

  @override
  String get ratiosSection => 'PROPORCJE';

  @override
  String croppedTo(int width, int height) {
    return 'Wykadrowano do $width×$height';
  }

  @override
  String get snap => 'Przyciąganie';

  @override
  String get snapHint =>
      'Warstwy wyrównują się do swoich krawędzi i środków oraz zatrzymują się na wielkości innej warstwy.';

  @override
  String get scale => 'Skala';

  @override
  String get rotation => 'Obrót';

  @override
  String get horizontal => 'Poziomo';

  @override
  String get vertical => 'Pionowo';

  @override
  String get brightness => 'Jasność';

  @override
  String get contrast => 'Kontrast';

  @override
  String get saturation => 'Nasycenie';

  @override
  String get hue => 'Barwa';

  @override
  String get opacity => 'Krycie';

  @override
  String get size => 'Rozmiar';

  @override
  String get color => 'Kolor';

  @override
  String get off => 'Wył.';

  @override
  String get adjustEmptyHint =>
      'Wybierz warstwę, aby zmienić jej rozmiar, obrócić ją lub skorygować.\nAlbo dotknij „Dodaj”, aby zaimportować zdjęcie.';

  @override
  String get effectsLink => 'Filtry, HDR, winieta, cień…';

  @override
  String get effectsLinkLayer => 'Mieszanie, cień, obrys…';

  @override
  String get textEmptyHint => 'Wybierz warstwę tekstową albo dodaj nową.';

  @override
  String get addText => 'Dodaj tekst';

  @override
  String get tapFontToPreview => 'Dotknij dla podglądu';

  @override
  String get typeYourCaption => 'Wpisz swój tekst…';

  @override
  String get outlineSection => 'OBRYS';

  @override
  String get cutoutOutlineSection => 'OBRYS WYCINKA';

  @override
  String get autoColor => 'Kolor automatyczny';

  @override
  String get thickness => 'Grubość';

  @override
  String get outlineOpacity => 'Krycie obrysu';

  @override
  String get font => 'Czcionka';

  @override
  String fontAdded(String family) {
    return 'Dodano czcionkę · $family';
  }

  @override
  String get comicBubble => 'Dymek komiksowy';

  @override
  String get bubble => 'Dymek';

  @override
  String get bubbleTextHint => 'Tekst dymku…';

  @override
  String get fill => 'Wypełnienie';

  @override
  String get outline => 'Obrys';

  @override
  String get bubbleTailHint =>
      'Przeciągnij kropkę na końcu ogonka, aby go skierować - w dowolną stronę.';

  @override
  String get addABubble => 'Dodaj dymek';

  @override
  String get addABubbleHint =>
      'Wybierz format. Tekst, kolory i ogonek możesz zmienić później - podobnie jak sam format.';

  @override
  String get addBubble => 'Dodaj dymek';

  @override
  String bubbleAdded(String format) {
    return 'Dodano dymek: $format - edytuj go w panelu';
  }

  @override
  String bubbleTileSemantics(String format, String description) {
    return 'Dymek $format - $description';
  }

  @override
  String get bubbleSpeech => 'Mowa';

  @override
  String get bubbleThought => 'Myśl';

  @override
  String get bubbleShout => 'Krzyk';

  @override
  String get bubbleCaption => 'Narracja';

  @override
  String get bubbleWhisper => 'Szept';

  @override
  String get bubbleSpeechBlurb => 'Zaokrąglony, z ogonkiem';

  @override
  String get bubbleThoughtBlurb => 'Chmurka ze śladem kropek';

  @override
  String get bubbleShoutBlurb => 'Kolczasta gwiazda';

  @override
  String get bubbleCaptionBlurb => 'Kwadratowe pole narracji';

  @override
  String get bubbleWhisperBlurb => 'Obrys linią przerywaną';

  @override
  String get notAPhotoGrid => 'Ten projekt nie jest siatką zdjęć.';

  @override
  String get shuffle => 'Przetasuj';

  @override
  String get photosSection => 'ZDJĘCIA';

  @override
  String get layoutSection => 'UKŁAD';

  @override
  String get border => 'Ramka';

  @override
  String get corners => 'Narożniki';

  @override
  String get effectsEmptyHint =>
      'Wybierz warstwę, aby nadać jej styl.\nFiltry, HDR i winieta dla zdjęć; cień, obrys i mieszanie dla wszystkiego.';

  @override
  String get filterSection => 'FILTR';

  @override
  String get strength => 'Siła';

  @override
  String get hdrSection => 'HDR';

  @override
  String get toneAndDetail => 'Ton i szczegóły';

  @override
  String get vignetteSection => 'WINIETA';

  @override
  String get amount => 'Ilość';

  @override
  String get softness => 'Miękkość';

  @override
  String get shadowSection => 'CIEŃ';

  @override
  String get direction => 'Kierunek';

  @override
  String get distance => 'Odległość';

  @override
  String get blur => 'Rozmycie';

  @override
  String get density => 'Gęstość';

  @override
  String get blendSection => 'MIESZANIE';

  @override
  String pixels(int count) {
    return '$count px';
  }

  @override
  String get working => 'Przetwarzanie…';

  @override
  String get undoRemoval => 'Cofnij usunięcie';

  @override
  String get removeBackground => 'Usuń tło';

  @override
  String get removeAnObject => 'Usuń obiekt';

  @override
  String get removeObject => 'Usuń obiekt';

  @override
  String get background => 'Tło';

  @override
  String get object => 'Obiekt';

  @override
  String get erase => 'Wymaż';

  @override
  String get restore => 'Przywróć';

  @override
  String get fillIn => 'Wypełnij';

  @override
  String get fillExplainer =>
      'Wypełnianie odtwarza tło na podstawie reszty zdjęcia.';

  @override
  String get eraseExplainer => 'Wymazywanie wycina obiekt do przezroczystości.';

  @override
  String get objectRemoveHint =>
      'Dotknij niechciany obiekt na zdjęciu, aby go usunąć - przypadkowy przedmiot, drugą osobę, bałagan. Dotknięcie głównego obiektu jest bezpiecznie ignorowane; każde usunięcie można cofnąć.';

  @override
  String get cutoutSelectPhoto => 'Wybierz warstwę ze zdjęciem do wycięcia.';

  @override
  String get cutoutHint =>
      'Jedno dotknięcie, aby wyodrębnić główny obiekt. Krawędzie wykryjemy automatycznie - wszystko możesz dopracować ręcznie narzędziem Wymaż.';

  @override
  String get backgroundRestored => 'Tło przywrócone';

  @override
  String get aiModelSection => 'MODEL AI';

  @override
  String get whichAiModel => 'Który model AI?';

  @override
  String get segBuiltinLabel => 'Wbudowane AI';

  @override
  String get segBuiltinTagline => 'Na urządzeniu · szybkie i prywatne';

  @override
  String get segBuiltinBlurb =>
      'Działa na urządzeniu, dając szybkie i prywatne wycinki. Świetne dla zwierząt i osób o wyraźnych krawędziach - nic nie opuszcza telefonu.';

  @override
  String get segU2netTagline => 'Open source · ostrzejsze szczegóły';

  @override
  String get segU2netBlurb =>
      'Otwartoźródłowy model wykrywania głównego obiektu dołączony do aplikacji. Działa całkowicie offline i często ostrzej oddaje drobne detale, jak futro, włosy czy wąsy - jest przy tym nieco wolniejszy.';

  @override
  String get aiGateTitle => 'Odblokuj narzędzia AI';

  @override
  String get aiGateMessage =>
      'Obejrzyj krótką reklamę, aby korzystać z narzędzi AI do końca tej sesji edycji. Kup Pro, aby używać ich bez reklam na zawsze.';

  @override
  String get aiGateWatch => 'Obejrzyj i odblokuj';

  @override
  String get aiGateNotRewarded =>
      'Obejrzyj całą reklamę, aby użyć AI, albo kup Pro, by usunąć reklamy';

  @override
  String get objectAiUnavailable =>
      'AI do usuwania obiektów nie jest dostępne na tym urządzeniu - użyj pędzla Wymaż';

  @override
  String get bgRemovalUnavailable =>
      'Usuwanie tła nie jest jeszcze dostępne na tym urządzeniu';

  @override
  String get layerGoneCutoutDiscarded =>
      'Tej warstwy już nie ma - wycinek został odrzucony';

  @override
  String get backgroundRemoved => 'Tło usunięte';

  @override
  String backgroundRemovedWith(String engine) {
    return 'Tło usunięte · $engine';
  }

  @override
  String get bgRemovalFailed => 'Nie udało się usunąć tła - spróbuj ponownie';

  @override
  String get selectPhotoToCutOut => 'Wybierz warstwę ze zdjęciem do wycięcia';

  @override
  String get detectingSubject =>
      'Wykrywanie obiektu i dopracowywanie krawędzi · na urządzeniu';

  @override
  String get edgeFeather => 'Wtapianie krawędzi';

  @override
  String get applyToLayer => 'Zastosuj do warstwy';

  @override
  String get tapObjectsToErase => 'Dotykaj obiekty na zdjęciu, aby je wymazać';

  @override
  String get tapObjectsToRemove => 'Dotknij obiekty do usunięcia';

  @override
  String get tapAnObjectToRemove => 'Dotknij obiekt na zdjęciu, aby go usunąć';

  @override
  String get chooseAiEngine => 'Wybierz silnik AI · działa na Twoim urządzeniu';

  @override
  String get autoRefineEdges => 'Automatycznie dopracuj krawędzie';

  @override
  String get brushFailed => 'Nie udało się użyć pędzla';

  @override
  String get nothingToRemoveThere => 'Nie ma tam nic do usunięcia';

  @override
  String get objectRemoved => 'Obiekt usunięty - cofnij, aby go przywrócić';

  @override
  String get objectRemoveFailed =>
      'Nie udało się tego usunąć - spróbuj ponownie';

  @override
  String get noObjectThere => 'Nie znaleziono tam obiektu';

  @override
  String get thatLooksLikeSubject =>
      'To wygląda na główny obiekt - użyj narzędzia Wymaż do drobnych poprawek';

  @override
  String get fillUnavailable =>
      'Nie udało się odtworzyć tła - obiekt został wymazany';

  @override
  String get objectFilled =>
      'Obiekt zastąpiony tłem - cofnij, aby go przywrócić';

  @override
  String get eraseEmptyHint =>
      'Wybierz warstwę ze zdjęciem do wymazywania albo dodaj zdjęcie.';

  @override
  String get brushOverCanvas => 'Maluj po płótnie';

  @override
  String get brushSize => 'Rozmiar pędzla';

  @override
  String get softEdges => 'Miękkie krawędzie';

  @override
  String get play => 'Odtwórz';

  @override
  String get pause => 'Pauza';

  @override
  String get newLayersToAllFrames => 'Nowe warstwy na wszystkich klatkach';

  @override
  String get onionSkin => 'Kalka (widmo poprzedniej klatki)';

  @override
  String get duplicateFrame => 'Duplikuj klatkę';

  @override
  String get moveLeft => 'Przesuń w lewo';

  @override
  String get moveRight => 'Przesuń w prawo';

  @override
  String get deleteFrame => 'Usuń klatkę';

  @override
  String frameOf(int current, int total) {
    return 'Klatka $current / $total';
  }

  @override
  String get mergeDown => 'Scal w dół';

  @override
  String get flatten => 'Spłaszcz';

  @override
  String get layersEmptyHint =>
      'Nie ma jeszcze warstw. Dotknij „Dodaj”, aby zaimportować zdjęcie lub dodać tekst.';

  @override
  String get mergedTwoLayers => 'Scalono 2 warstwy';

  @override
  String flattenedLayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Spłaszczono $count warstwy',
      many: 'Spłaszczono $count warstw',
      few: 'Spłaszczono $count warstwy',
      one: 'Spłaszczono 1 warstwę',
    );
    return '$_temp0';
  }

  @override
  String get mergeFailed => 'Nie udało się scalić tych warstw';

  @override
  String get importPhotoFailed => 'Nie udało się zaimportować zdjęcia';

  @override
  String get noImageInClipboard => 'Brak obrazu w schowku';

  @override
  String get pasteFailed => 'Nie udało się wkleić obrazu';

  @override
  String get takePhoto => 'Zrób zdjęcie';

  @override
  String get choosePhoto => 'Wybierz zdjęcie';

  @override
  String get pasteImage => 'Wklej obraz';

  @override
  String get renameLayer => 'Zmień nazwę warstwy';

  @override
  String get canvasSize => 'Rozmiar płótna';

  @override
  String get addLayer => 'Zdjęcie';

  @override
  String get aiCut => 'Wytnij (AI)';

  @override
  String get seeThePrice => 'Zobacz cenę';

  @override
  String get notNow => 'Nie teraz';

  @override
  String get oneTimeNoSubscriptionShort => 'Zakup jednorazowy, bez abonamentu';

  @override
  String get proBenefitNoAdsTitle => 'Żadnych reklam, nigdzie';

  @override
  String get proBenefitNoAdsBody =>
      'Baner na ekranie startowym i reklamy pełnoekranowe znikają na dobre.';

  @override
  String get proBenefitAiTitle => 'AI bez czekania';

  @override
  String get proBenefitAiBody =>
      'Usuwanie tła i wymazywanie obiektów działają od razu - bez reklamy z nagrodą.';

  @override
  String get proBenefitExportTitle => 'Eksportuj i udostępniaj swobodnie';

  @override
  String get proBenefitExportBody =>
      'Zapisuj i udostępniaj w dowolnym rozmiarze, bez oglądania reklam.';

  @override
  String get proBenefitLocalTitle => 'Nadal na Twoim urządzeniu';

  @override
  String get proBenefitLocalBody =>
      'Pro nic nie zmienia w kwestii zdjęć: każda edycja pozostaje lokalna, tak jak dotąd.';

  @override
  String get textLayer => 'Warstwa tekstowa';

  @override
  String get bubbleLayer => 'Warstwa dymku';

  @override
  String get imageLayer => 'Warstwa obrazu';

  @override
  String get imageLayerCutOut => 'Warstwa obrazu · wycięta';

  @override
  String dragToReorder(String name) {
    return 'Przeciągnij, aby zmienić kolejność: $name';
  }

  @override
  String get hideLayer => 'Ukryj warstwę';

  @override
  String get showLayer => 'Pokaż warstwę';

  @override
  String get duplicateLayer => 'Duplikuj warstwę';

  @override
  String get deleteLayer => 'Usuń warstwę';

  @override
  String deleteLayerNamed(String name) {
    return 'Usuń warstwę $name';
  }

  @override
  String get cutOut => 'Wycięte';

  @override
  String get tapToAddPhoto => 'Dotknij, aby dodać zdjęcie';

  @override
  String get undo => 'Cofnij';

  @override
  String get redo => 'Ponów';

  @override
  String get export => 'Eksportuj';

  @override
  String get customPixels => 'WŁASNY (PIKSELE)';

  @override
  String get width => 'Szerokość';

  @override
  String get height => 'Wysokość';

  @override
  String get create => 'Utwórz';

  @override
  String get scaleLayersToFit => 'Dopasuj warstwy do nowego rozmiaru';

  @override
  String get scaleLayersToFitSub => 'Przelicz całą kompozycję na nowy rozmiar';

  @override
  String get presetSquare => 'Kwadrat';

  @override
  String get presetPortrait => 'Pion';

  @override
  String get presetStory => 'Story';

  @override
  String get presetLandscape => 'Poziom';

  @override
  String get presetWide => 'Szeroki';

  @override
  String get presetSmall => 'Mały';

  @override
  String layersAutoSaved(String layers) {
    return '$layers · zapisano automatycznie';
  }

  @override
  String engineWorking(String engine) {
    return '$engine pracuje…';
  }

  @override
  String get toolLayers => 'Warstwy';

  @override
  String get toolAdjust => 'Korekta';

  @override
  String get toolEffects => 'Efekty';

  @override
  String get toolText => 'Tekst';

  @override
  String get toolErase => 'Wymaż';

  @override
  String get toolErasePanel => 'Ręczne wymazywanie';

  @override
  String get toolCutout => 'Wytnij';

  @override
  String get toolCutoutPanel => 'Usuwanie tła przez AI';

  @override
  String get toolFrames => 'Klatki';

  @override
  String get toolFramesPanel => 'Klatki animacji';

  @override
  String get toolGrid => 'Siatka';

  @override
  String get toolGridPanel => 'Siatka zdjęć';

  @override
  String get filterOriginal => 'Oryginał';

  @override
  String get filterVivid => 'Żywy';

  @override
  String get filterPunch => 'Mocny';

  @override
  String get filterChrome => 'Chrom';

  @override
  String get filterWarm => 'Ciepły';

  @override
  String get filterCool => 'Chłodny';

  @override
  String get filterSunset => 'Zachód';

  @override
  String get filterDawn => 'Świt';

  @override
  String get filterDusk => 'Zmierzch';

  @override
  String get filterFade => 'Wyblakły';

  @override
  String get filterMatte => 'Matowy';

  @override
  String get filterRetro => 'Retro';

  @override
  String get filterSepia => 'Sepia';

  @override
  String get filterMono => 'Mono';

  @override
  String get filterNoir => 'Noir';

  @override
  String get blendNormal => 'Zwykły';

  @override
  String get blendMultiply => 'Mnożenie';

  @override
  String get blendScreen => 'Mnożenie odwrotności';

  @override
  String get blendOverlay => 'Nakładka';

  @override
  String get blendDarken => 'Ciemniej';

  @override
  String get blendLighten => 'Jaśniej';

  @override
  String get blendDodge => 'Rozjaśnianie';

  @override
  String get blendBurn => 'Ściemnianie';

  @override
  String get blendHardLight => 'Ostre światło';

  @override
  String get blendSoftLight => 'Łagodne światło';

  @override
  String get blendDifference => 'Różnica';

  @override
  String get blendExclusion => 'Wyłączenie';

  @override
  String get blendHue => 'Barwa';

  @override
  String get blendSaturation => 'Nasycenie';

  @override
  String get blendColor => 'Kolor';

  @override
  String get blendLuminosity => 'Jasność';

  @override
  String get gridHowManyPhotos => 'ILE ZDJĘĆ?';

  @override
  String get gridLayoutLabel => 'UKŁAD';

  @override
  String get gridSizeLabel => 'ROZMIAR';

  @override
  String get gridSetupHint =>
      'Za chwilę wybierzesz zdjęcia - układ, liczbę i ramkę możesz zmienić w każdej chwili.';

  @override
  String photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zdjęcia',
      many: '$count zdjęć',
      few: '$count zdjęcia',
      one: '1 zdjęcie',
    );
    return '$_temp0';
  }

  @override
  String gridLayoutNamed(String name) {
    return 'Układ $name';
  }

  @override
  String get gridSideBySide => 'Obok siebie';

  @override
  String get gridStacked => 'Nad sobą';

  @override
  String get gridWideLeft => 'Szersze z lewej';

  @override
  String get gridTallTop => 'Wysokie u góry';

  @override
  String get gridColumns => 'Kolumny';

  @override
  String get gridRows => 'Wiersze';

  @override
  String get gridBigLeft => 'Duże z lewej';

  @override
  String get gridBigTop => 'Duże u góry';

  @override
  String get gridTwoByTwo => '2 x 2';

  @override
  String get gridTwoOverThree => '2 nad 3';

  @override
  String get gridThreeOverTwo => '3 nad 2';

  @override
  String get gridTwoLeftThreeRight => '2 obok 3';

  @override
  String get exportTitle => 'Eksport i udostępnianie';

  @override
  String get formatLabel => 'FORMAT';

  @override
  String get formatPngSub => 'przezroczysty';

  @override
  String get formatJpgSub => 'spłaszczony';

  @override
  String get formatWebpSub => 'mniejszy';

  @override
  String get resolutionLabel => 'ROZDZIELCZOŚĆ';

  @override
  String exportOutput(
    int width,
    int height,
    String format,
    String transparent,
  ) {
    return 'Wynik · $width × $height px · $format$transparent';
  }

  @override
  String get transparentParenthetical => '(przezroczysty)';

  @override
  String get saveToDevice => 'Zapisz na urządzeniu';

  @override
  String get share => 'Udostępnij';

  @override
  String savedTo(String location) {
    return 'Zapisano · $location';
  }

  @override
  String get storageDenied =>
      'Zezwól na dostęp do pamięci, aby zapisać w galerii';

  @override
  String get saveFailed => 'Nie udało się zapisać obrazu';

  @override
  String get exportFailed => 'Eksport nie powiódł się - spróbuj ponownie';

  @override
  String get shareFailed => 'Udostępnianie nie powiodło się - spróbuj ponownie';

  @override
  String get exportGateTitle => 'Obejrzyj krótką reklamę, aby wyeksportować';

  @override
  String get exportGateMessage =>
      'Darmowy eksport jest wspierany krótką reklamą. Kup Pro, aby eksportować bez reklam na zawsze.';

  @override
  String get exportGateWatch => 'Obejrzyj i eksportuj';

  @override
  String get swatchWhite => 'biały';

  @override
  String get swatchBlack => 'czarny';

  @override
  String get swatchPink => 'różowy';

  @override
  String get swatchAmber => 'bursztynowy';

  @override
  String get swatchGreen => 'zielony';

  @override
  String get swatchCyan => 'cyjanowy';

  @override
  String get swatchViolet => 'fioletowy';

  @override
  String get swatchRose => 'jasnoróżowy';

  @override
  String get swatchOrange => 'pomarańczowy';
}
