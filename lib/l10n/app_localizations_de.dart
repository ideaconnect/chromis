// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Chromis';

  @override
  String get back => 'Zurück';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get done => 'Fertig';

  @override
  String get delete => 'Löschen';

  @override
  String get rename => 'Umbenennen';

  @override
  String get duplicate => 'Duplizieren';

  @override
  String get open => 'Öffnen';

  @override
  String get close => 'Schließen';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get apply => 'Anwenden';

  @override
  String get add => 'Hinzufügen';

  @override
  String get remove => 'Entfernen';

  @override
  String get menu => 'Menü';

  @override
  String get settings => 'Einstellungen';

  @override
  String get about => 'Über';

  @override
  String get licenses => 'Lizenzen';

  @override
  String get nameHint => 'Name';

  @override
  String get cannotBeUndone => 'Das kann nicht rückgängig gemacht werden.';

  @override
  String get tryAgainInAMoment => 'Versuche es gleich noch einmal.';

  @override
  String get appLogo => 'Chromis-Logo';

  @override
  String get pleaseTryAgain => 'bitte versuche es erneut';

  @override
  String get homeTitle => 'Deine Projekte';

  @override
  String get homeTagline => 'Chromis · Fotoeditor mit KI-Freistellen';

  @override
  String get homeRecent => 'ZULETZT';

  @override
  String get homeJoinDiscord => 'Komm auf unseren Discord';

  @override
  String get homeEmptyHint =>
      'Tippe auf Neues Projekt, um ein Foto zu importieren.';

  @override
  String get noProjectsYet => 'Noch keine Projekte';

  @override
  String get newProject => 'Neues Projekt';

  @override
  String get homeNewProjectSubtitle => 'Leere Leinwand oder Fotoraster';

  @override
  String get homeOpenPhoto => 'Foto öffnen';

  @override
  String get homeOpenPhotoSubtitle => 'Leinwand übernimmt die Fotogröße';

  @override
  String projectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Projekte',
      one: '1 Projekt',
    );
    return '$_temp0';
  }

  @override
  String layerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ebenen',
      one: '1 Ebene',
    );
    return '$_temp0';
  }

  @override
  String get renameProject => 'Projekt umbenennen';

  @override
  String get projectNameHint => 'Projektname';

  @override
  String get copySuffix => '(Kopie)';

  @override
  String deleteProjectTitle(String name) {
    return '„$name“ löschen?';
  }

  @override
  String get allProjects => 'Alle Projekte';

  @override
  String get searchProjects => 'Deine Projekte durchsuchen';

  @override
  String get projectsLoadFailed =>
      'Deine Projekte konnten nicht geladen werden';

  @override
  String get allProjectsEmptyHint =>
      'Erstelle eines auf der Startseite - es erscheint dann hier.';

  @override
  String get noMatches => 'Keine Treffer';

  @override
  String noMatchesFor(String query) {
    return 'Nichts passt zu „$query“.';
  }

  @override
  String get newProjectQuestion => 'Was möchtest du erstellen?';

  @override
  String get blankCanvas => 'Leere Leinwand';

  @override
  String get blankCanvasSubtitle =>
      'Eine Leinwand - Fotos und Ebenen frei hinzufügen';

  @override
  String get photoGrid => 'Fotoraster';

  @override
  String get photoGridSubtitle =>
      'Eine Collage aus 2 bis 5 Fotos in einem Layout';

  @override
  String get drawerHome => 'Start & Projekte';

  @override
  String drawerSubtitle(String version) {
    return 'Fotoeditor · v$version';
  }

  @override
  String get appearance => 'Erscheinungsbild';

  @override
  String get appearanceSystem => 'Systemstandard';

  @override
  String get appearanceSystemSub =>
      'Der Hell-/Dunkel-Einstellung des Telefons folgen';

  @override
  String get appearanceLight => 'Hell';

  @override
  String get appearanceLightSub => 'Besser lesbar draußen und auf LCD-Displays';

  @override
  String get appearanceDark => 'Dunkel';

  @override
  String get appearanceDarkSub =>
      'Reines Schwarz, das OLED-Displays gar nicht leuchten lassen';

  @override
  String get appearanceNote =>
      'Chromis folgt dem Telefon, sofern du hier nichts wählst. Deine Wahl wird gespeichert.';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'Systemstandard';

  @override
  String get languageSystemSub => 'Die Sprache deines Handys verwenden';

  @override
  String get languageNote =>
      'Chromis ist auf Englisch, sofern dein Handy nicht auf eine Sprache eingestellt ist, in die es übersetzt wurde. Deine Auswahl hier wird gespeichert.';

  @override
  String get skip => 'Überspringen';

  @override
  String get next => 'Weiter';

  @override
  String get getStarted => 'Los geht\'s';

  @override
  String get onboardStartTitle => 'Mit einem Foto starten';

  @override
  String get onboardStartBody =>
      'Öffne ein beliebiges Foto oder eine leere Leinwand in der Größe, die du brauchst. Füge Ebenen, Text und Sprechblasen hinzu.';

  @override
  String get onboardCutoutTitle => 'Hintergrund freistellen';

  @override
  String get onboardCutoutBody =>
      'Stelle dein Motiv mit einem Fingertipp vom Hintergrund frei oder radiere Objekte weg - alles auf dem Gerät, deine Fotos verlassen dein Handy nie.';

  @override
  String get onboardExportTitle => 'Export & Teilen';

  @override
  String get onboardExportBody =>
      'Speichere ein transparentes PNG, JPG oder WebP in beliebiger Auflösung und teile es überall.';

  @override
  String get privacyTitle => 'Datenschutz & Cookies';

  @override
  String get privacyRowSub => 'Bearbeiten auf dem Gerät · Werbung erklärt';

  @override
  String get privacyBanner =>
      'Deine Fotos bleiben auf deinem Gerät. Werbung ist die einzige Ausnahme - unten erklärt.';

  @override
  String get privacyOnDevice =>
      'Deine Fotos werden vollständig auf deinem Gerät bearbeitet - nichts wird hochgeladen.';

  @override
  String get privacyAiLocal =>
      'KI-Hintergrund- & Objektentfernung laufen lokal; Fotos verlassen dein Handy nie.';

  @override
  String get privacyNoAccounts =>
      'Keine Konten, keine Anmeldung, keine Foto-Uploads.';

  @override
  String get privacyAds =>
      'Die kostenlose App zeigt Werbung (Google AdMob), die eine Werbe-ID nutzt.';

  @override
  String get privacyConsent =>
      'Wo erforderlich, kannst du in einem Einwilligungsdialog (UMP) zwischen personalisierter und nicht personalisierter Werbung wählen.';

  @override
  String get privacyWithdraw =>
      'Du kannst diese Einwilligung jederzeit ändern oder widerrufen - „Werbe-Datenschutzoptionen“ unten öffnet das Formular erneut.';

  @override
  String get privacyPro =>
      'Das einmalige Pro-Upgrade entfernt alle Werbung - und die Werbe-ID gleich mit.';

  @override
  String get fullPrivacyPolicy => 'Vollständige Datenschutzerklärung';

  @override
  String get questions => 'Fragen?';

  @override
  String get openSourceLicenses => 'Open-Source-Lizenzen';

  @override
  String get licensesRowSub => 'Die großartige Arbeit, auf der wir aufbauen';

  @override
  String get licensesIntro =>
      'Chromis baut auf wunderbarer Open-Source-Arbeit auf. Danke an alle, die sie möglich gemacht haben.';

  @override
  String get viewFullLicenseTexts => 'Vollständige Lizenztexte ansehen';

  @override
  String get licenseCategoryFonts => 'Schriften';

  @override
  String get licenseCategoryAi => 'KI auf dem Gerät';

  @override
  String get licenseCategoryEncoding => 'Medien-Encoding';

  @override
  String get licenseCategoryMonetization => 'Monetarisierung';

  @override
  String get licenseCategoryFramework => 'Framework & Pakete';

  @override
  String get licenseUseDisplayFont => 'Display-/Überschriftenschrift';

  @override
  String get licenseUseBodyFont => 'UI-/Fließtextschrift';

  @override
  String get licenseUseComicFont => 'Comic-Schrift für Bildtexte';

  @override
  String get licenseUseCaptionFont => 'Schrift für Bildtexte';

  @override
  String get licenseUseScriptFont => 'Schreibschrift für Bildtexte';

  @override
  String get licenseUseBgRemoval => 'Hintergrundentfernung (Android)';

  @override
  String get licenseUseRuntime => 'Führt das mitgelieferte Fallback-Modell aus';

  @override
  String get licenseUseOnDeviceAi =>
      'Objekt- & Hintergrundentfernung auf dem Gerät';

  @override
  String get licenseUseEncoding => 'PNG-/JPG-/WebP-Encoding';

  @override
  String get licenseUseAds => 'Banner-/Rewarded-Werbung + Einwilligung';

  @override
  String get licenseUsePurchase => 'Einmaliger Pro-Kauf (Werbung entfernen)';

  @override
  String get licenseUseFramework => 'App-Framework';

  @override
  String get licenseUsePlugins => 'Routing, Speicher, Teilen, Bildauswahl';

  @override
  String get licenseUseState => 'State-Management';

  @override
  String get licenseUseClipboard => 'Bild aus der Zwischenablage einfügen';

  @override
  String get goPro => 'Pro holen';

  @override
  String get goProRemoveAds => 'Pro holen · werbefrei';

  @override
  String get goProRemoveAdsPlain => 'Pro holen - werbefrei';

  @override
  String get goProRowSub => 'Einmaliges Upgrade - nie wieder Werbung';

  @override
  String get goProHeroTitle => 'Werbung für immer entfernen';

  @override
  String get goProHeroBody =>
      'Einmaliger Kauf. Alle KI-Funktionen bleiben kostenlos - keine Werbung, kein Werbevideo vorab.';

  @override
  String get goProBenefitNoAds => 'Keine Banner- oder Vollbildwerbung';

  @override
  String get goProBenefitNoRewarded =>
      'KI-Freistellen & Objektentfernung ohne Werbevideo';

  @override
  String get goProBenefitOneTime => 'Einmalzahlung - kein Abo';

  @override
  String get goProBenefitSupports =>
      'Unterstützt private Fotobearbeitung auf dem Gerät';

  @override
  String get goProOwned => 'Du bist Pro - Werbung ist aus. Danke!';

  @override
  String upgradeFor(String price) {
    return 'Upgrade - $price';
  }

  @override
  String get restorePurchase => 'Kauf wiederherstellen';

  @override
  String get oneTimeUnavailable => 'Einmaliger Kauf · derzeit nicht verfügbar';

  @override
  String get oneTimeRestores =>
      'Einmaliger Kauf · auf jedem Gerät wiederherstellbar';

  @override
  String get oneTimeNoSubscription => 'Einmaliger Kauf. Kein Abo.';

  @override
  String get purchasesUnavailable =>
      'Käufe sind derzeit nicht verfügbar - bitte versuche es später erneut.';

  @override
  String get purchaseStartFailed =>
      'Kauf konnte nicht gestartet werden - bitte versuche es erneut.';

  @override
  String get purchaseStartFailedOwned =>
      'Kauf konnte nicht gestartet werden - wenn du Pro schon gekauft hast, tippe auf „Kauf wiederherstellen“.';

  @override
  String get checkingPreviousPurchase => 'Suche nach einem früheren Kauf…';

  @override
  String get playUnreachable =>
      'Google Play ist nicht erreichbar - prüfe deine Verbindung und versuche es erneut.';

  @override
  String get purchaseFailedGeneric =>
      'Der Kauf konnte nicht abgeschlossen werden';

  @override
  String get removeAdsArrow => 'Werbung entfernen →';

  @override
  String get adsDeclinedExplainer =>
      'Du hast Werbung nicht zugelassen, also gibt es keine Werbung zum Ansehen - und nur Werbung hält Chromis kostenlos.\n\nLass Werbung zu, um kostenlos weiterzumachen, oder hol dir Pro und nutze alles ganz ohne Werbung.';

  @override
  String get reviewAdConsent => 'Werbeeinwilligung prüfen';

  @override
  String get adPrivacyChoices => 'Werbe-Datenschutzoptionen';

  @override
  String get adPrivacyChoicesSub =>
      'Ändere deine Einwilligung für personalisierte Werbung';

  @override
  String adSettingsFailed(String error) {
    return 'Werbeeinstellungen konnten nicht geöffnet werden: $error';
  }

  @override
  String get untitledProject => 'Ohne Titel';

  @override
  String get photoLayerDefault => 'Foto';

  @override
  String get textLayerDefault => 'Text';

  @override
  String get mergedLayerName => 'Zusammengeführt';

  @override
  String get mergedLayerSuffix => 'zusammengeführt';

  @override
  String get saveRetrying =>
      'Speichern fehlgeschlagen - deine Änderungen sind sicher, wir versuchen es weiter';

  @override
  String get speed => 'Tempo';

  @override
  String get fillingBackground => 'Hintergrund wird gefüllt…';

  @override
  String get findingObject => 'Objekt wird gesucht…';

  @override
  String get mergingLayers => 'Ebenen werden zusammengeführt…';

  @override
  String get removingBackground => 'Hintergrund wird entfernt…';

  @override
  String get hideToolPanel => 'Werkzeugbereich ausblenden';

  @override
  String get showToolPanel => 'Werkzeugbereich einblenden';

  @override
  String get cropOpenFailed =>
      'Foto konnte nicht zum Zuschneiden geöffnet werden';

  @override
  String get photoCropped => 'Foto zugeschnitten';

  @override
  String get editCrop => 'Zuschnitt bearbeiten';

  @override
  String get cropPhoto => 'Foto zuschneiden';

  @override
  String get resetCrop => 'Zuschnitt zurücksetzen';

  @override
  String get crop => 'Zuschneiden';

  @override
  String get cancelCrop => 'Zuschneiden abbrechen';

  @override
  String get previewUnavailable => 'Keine Vorschau verfügbar';

  @override
  String get cropToRatio => 'Auf Format zuschneiden';

  @override
  String get cropSheetHint =>
      'Ziehe einen freien Rahmen auf oder schneide mittig auf ein Format zu';

  @override
  String get freeformCrop => 'Freier Zuschnitt';

  @override
  String get ratiosSection => 'FORMATE';

  @override
  String croppedTo(int width, int height) {
    return 'Zugeschnitten auf $width×$height';
  }

  @override
  String get scale => 'Skalierung';

  @override
  String get rotation => 'Drehung';

  @override
  String get horizontal => 'Horizontal';

  @override
  String get vertical => 'Vertikal';

  @override
  String get brightness => 'Helligkeit';

  @override
  String get contrast => 'Kontrast';

  @override
  String get saturation => 'Sättigung';

  @override
  String get hue => 'Farbton';

  @override
  String get opacity => 'Deckkraft';

  @override
  String get size => 'Größe';

  @override
  String get color => 'Farbe';

  @override
  String get off => 'Aus';

  @override
  String get adjustEmptyHint =>
      'Wähle eine Ebene aus, um sie zu skalieren, zu drehen oder anzupassen.\nOder tippe auf Hinzufügen, um ein Foto zu importieren.';

  @override
  String get effectsLink => 'Filter, HDR, Vignette, Schatten…';

  @override
  String get effectsLinkLayer => 'Mischmodus, Schatten, Kontur…';

  @override
  String get textEmptyHint => 'Wähle eine Textebene aus oder füge eine hinzu.';

  @override
  String get addText => 'Text hinzufügen';

  @override
  String get tapFontToPreview => 'Antippen für Vorschau';

  @override
  String get typeYourCaption => 'Schreibe deinen Text…';

  @override
  String get outlineSection => 'KONTUR';

  @override
  String get cutoutOutlineSection => 'FREISTELLKONTUR';

  @override
  String get autoColor => 'Auto-Farbe';

  @override
  String get thickness => 'Dicke';

  @override
  String get outlineOpacity => 'Konturdeckkraft';

  @override
  String get font => 'Schrift';

  @override
  String fontAdded(String family) {
    return 'Schrift hinzugefügt · $family';
  }

  @override
  String get comicBubble => 'Comic-Sprechblase';

  @override
  String get bubble => 'Sprechblase';

  @override
  String get bubbleTextHint => 'Sprechblasentext…';

  @override
  String get fill => 'Füllung';

  @override
  String get outline => 'Kontur';

  @override
  String get bubbleTailHint =>
      'Ziehe den Punkt an der Spitze, um sie auszurichten - in jede Richtung.';

  @override
  String get addABubble => 'Sprechblase hinzufügen';

  @override
  String get addABubbleHint =>
      'Wähle eine Form. Text, Farben und Spitze sind danach änderbar - und die Form auch.';

  @override
  String get addBubble => 'Sprechblase hinzufügen';

  @override
  String bubbleAdded(String format) {
    return '$format hinzugefügt - im Werkzeugbereich bearbeiten';
  }

  @override
  String bubbleTileSemantics(String format, String description) {
    return '$format - $description';
  }

  @override
  String get bubbleSpeech => 'Sprechblase';

  @override
  String get bubbleThought => 'Denkblase';

  @override
  String get bubbleShout => 'Rufblase';

  @override
  String get bubbleCaption => 'Textkasten';

  @override
  String get bubbleWhisper => 'Flüsterblase';

  @override
  String get bubbleSpeechBlurb => 'Rund, mit Spitze';

  @override
  String get bubbleThoughtBlurb => 'Wolke mit Punktspur';

  @override
  String get bubbleShoutBlurb => 'Zackige Sternform';

  @override
  String get bubbleCaptionBlurb => 'Eckiger Erzählkasten';

  @override
  String get bubbleWhisperBlurb => 'Gestrichelte Kontur';

  @override
  String get notAPhotoGrid => 'Dieses Projekt ist kein Fotoraster.';

  @override
  String get shuffle => 'Mischen';

  @override
  String get photosSection => 'FOTOS';

  @override
  String get layoutSection => 'LAYOUT';

  @override
  String get border => 'Rahmen';

  @override
  String get corners => 'Ecken';

  @override
  String get effectsEmptyHint =>
      'Wähle eine Ebene, um ihr einen Look zu geben.\nFilter, HDR und Vignette für Fotos; Schatten, Kontur und Mischmodus für alles.';

  @override
  String get filterSection => 'FILTER';

  @override
  String get strength => 'Stärke';

  @override
  String get hdrSection => 'HDR';

  @override
  String get toneAndDetail => 'Ton + Detail';

  @override
  String get vignetteSection => 'VIGNETTE';

  @override
  String get amount => 'Intensität';

  @override
  String get softness => 'Weichheit';

  @override
  String get shadowSection => 'SCHATTEN';

  @override
  String get direction => 'Richtung';

  @override
  String get distance => 'Abstand';

  @override
  String get blur => 'Unschärfe';

  @override
  String get density => 'Dichte';

  @override
  String get blendSection => 'MISCHMODUS';

  @override
  String pixels(int count) {
    return '$count px';
  }

  @override
  String get working => 'Wird verarbeitet…';

  @override
  String get undoRemoval => 'Hintergrund zurückholen';

  @override
  String get removeBackground => 'Hintergrund entfernen';

  @override
  String get removeAnObject => 'Ein Objekt entfernen';

  @override
  String get removeObject => 'Objekt entfernen';

  @override
  String get background => 'Hintergrund';

  @override
  String get object => 'Objekt';

  @override
  String get erase => 'Radieren';

  @override
  String get restore => 'Wiederherstellen';

  @override
  String get fillIn => 'Füllen';

  @override
  String get fillExplainer =>
      'Füllen rekonstruiert den Hintergrund aus dem übrigen Foto.';

  @override
  String get eraseExplainer =>
      'Radieren entfernt das Objekt und macht die Fläche transparent.';

  @override
  String get objectRemoveHint =>
      'Tippe auf dem Foto auf ein störendes Objekt, um es zu entfernen - ein verirrtes Teil, ein zweites Motiv, Unordnung. Tippst du auf das Hauptmotiv, passiert nichts; Rückgängig holt alles zurück.';

  @override
  String get cutoutSelectPhoto => 'Wähle eine Fotoebene zum Freistellen.';

  @override
  String get cutoutHint =>
      'Ein Tippen stellt dein Motiv frei. Wir erkennen die Kanten automatisch - nachbessern kannst du von Hand im Werkzeug Radieren.';

  @override
  String get backgroundRestored => 'Hintergrund wiederhergestellt';

  @override
  String get aiModelSection => 'KI-MODELL';

  @override
  String get whichAiModel => 'Welches KI-Modell?';

  @override
  String get segBuiltinLabel => 'Integrierte KI';

  @override
  String get segBuiltinTagline => 'Auf dem Gerät · schnell & privat';

  @override
  String get segBuiltinBlurb =>
      'Läuft auf dem Gerät und stellt schnell und privat frei. Ideal für Haustiere und Menschen mit klaren Kanten - nichts verlässt dein Handy.';

  @override
  String get segU2netTagline => 'Open Source · schärfere Details';

  @override
  String get segU2netBlurb =>
      'Ein quelloffenes Modell zur Motiverkennung, das der App beiliegt. Arbeitet komplett offline und ist bei feinen Details wie Fell, Haaren und Schnurrhaaren oft schärfer - dafür etwas langsamer.';

  @override
  String get aiGateTitle => 'KI-Werkzeuge freischalten';

  @override
  String get aiGateMessage =>
      'Sieh dir eine kurze Werbung an, um die KI-Werkzeuge für den Rest dieser Bearbeitung zu nutzen. Mit Pro nutzt du sie für immer ohne Werbung.';

  @override
  String get aiGateWatch => 'Ansehen & freischalten';

  @override
  String get aiGateNotRewarded =>
      'Sieh dir die Werbung bis zum Ende an, um KI zu nutzen, oder hol dir Pro, um Werbung zu entfernen';

  @override
  String get objectAiUnavailable =>
      'Die KI zum Entfernen von Objekten ist auf diesem Gerät nicht verfügbar - nutze stattdessen den Radierpinsel';

  @override
  String get bgRemovalUnavailable =>
      'Die Hintergrundentfernung ist auf diesem Gerät noch nicht verfügbar';

  @override
  String get layerGoneCutoutDiscarded =>
      'Diese Ebene gibt es nicht mehr - die Freistellung wurde verworfen';

  @override
  String get backgroundRemoved => 'Hintergrund entfernt';

  @override
  String backgroundRemovedWith(String engine) {
    return 'Hintergrund entfernt · $engine';
  }

  @override
  String get bgRemovalFailed =>
      'Hintergrund konnte nicht entfernt werden - versuche es erneut';

  @override
  String get selectPhotoToCutOut => 'Wähle eine Fotoebene zum Freistellen';

  @override
  String get detectingSubject =>
      'Motiv wird erkannt & Kanten werden verfeinert · auf dem Gerät';

  @override
  String get edgeFeather => 'Weiche Kante';

  @override
  String get applyToLayer => 'Auf Ebene anwenden';

  @override
  String get tapObjectsToErase =>
      'Tippe auf Objekte im Foto, um sie zu radieren';

  @override
  String get tapObjectsToRemove => 'Tippe auf Objekte zum Entfernen';

  @override
  String get tapAnObjectToRemove =>
      'Tippe auf ein Objekt im Foto, um es zu entfernen';

  @override
  String get chooseAiEngine => 'KI-Engine wählen · läuft auf deinem Gerät';

  @override
  String get autoRefineEdges => 'Kanten automatisch verfeinern';

  @override
  String get brushFailed => 'Pinsel konnte nicht angewendet werden';

  @override
  String get nothingToRemoveThere => 'Dort gibt es nichts zu entfernen';

  @override
  String get objectRemoved => 'Objekt entfernt - Rückgängig holt es zurück';

  @override
  String get objectRemoveFailed =>
      'Das konnte nicht entfernt werden - versuche es erneut';

  @override
  String get noObjectThere => 'Dort wurde kein Objekt gefunden';

  @override
  String get thatLooksLikeSubject =>
      'Das sieht nach deinem Motiv aus - nutze Radieren für feine Korrekturen';

  @override
  String get fillUnavailable =>
      'Dieser Bereich ließ sich nicht rekonstruieren - stattdessen radiert';

  @override
  String get objectFilled => 'Objekt gefüllt - Rückgängig stellt es wieder her';

  @override
  String get eraseEmptyHint =>
      'Wähle eine Fotoebene zum Radieren oder füge ein Foto hinzu.';

  @override
  String get brushOverCanvas => 'Male über die Leinwand';

  @override
  String get brushSize => 'Pinselgröße';

  @override
  String get softEdges => 'Weiche Kanten';

  @override
  String get play => 'Abspielen';

  @override
  String get pause => 'Pause';

  @override
  String get newLayersToAllFrames => 'Neue Ebenen in alle Frames';

  @override
  String get onionSkin => 'Zwiebelhaut (Vorheriges andeuten)';

  @override
  String get duplicateFrame => 'Frame duplizieren';

  @override
  String get moveLeft => 'Nach links verschieben';

  @override
  String get moveRight => 'Nach rechts verschieben';

  @override
  String get deleteFrame => 'Frame löschen';

  @override
  String frameOf(int current, int total) {
    return 'Frame $current / $total';
  }

  @override
  String get mergeDown => 'Zusammenführen';

  @override
  String get flatten => 'Reduzieren';

  @override
  String get layersEmptyHint =>
      'Noch keine Ebenen. Tippe auf Hinzufügen, um ein Foto zu importieren oder Text hinzuzufügen.';

  @override
  String get mergedTwoLayers => '2 Ebenen zusammengeführt';

  @override
  String flattenedLayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ebenen reduziert',
      one: '1 Ebene reduziert',
    );
    return '$_temp0';
  }

  @override
  String get mergeFailed => 'Diese Ebenen ließen sich nicht zusammenführen';

  @override
  String get importPhotoFailed => 'Foto konnte nicht importiert werden';

  @override
  String get noImageInClipboard => 'Kein Bild in der Zwischenablage';

  @override
  String get pasteFailed => 'Bild konnte nicht eingefügt werden';

  @override
  String get takePhoto => 'Foto aufnehmen';

  @override
  String get choosePhoto => 'Foto auswählen';

  @override
  String get pasteImage => 'Bild einfügen';

  @override
  String get renameLayer => 'Ebene umbenennen';

  @override
  String get canvasSize => 'Leinwandgröße';

  @override
  String get addLayer => 'Foto';

  @override
  String get aiCut => 'Freistellen';

  @override
  String get seeThePrice => 'Preis ansehen';

  @override
  String get notNow => 'Jetzt nicht';

  @override
  String get oneTimeNoSubscriptionShort => 'Einmaliger Kauf, kein Abo';

  @override
  String get proBenefitNoAdsTitle => 'Keine Werbung, nirgends';

  @override
  String get proBenefitNoAdsBody =>
      'Das Banner auf der Startseite und die Vollbildwerbung verschwinden für immer.';

  @override
  String get proBenefitAiTitle => 'KI ohne Wartezeit';

  @override
  String get proBenefitAiBody =>
      'Hintergrund- und Objektentfernung starten sofort - ohne vorheriges Werbevideo.';

  @override
  String get proBenefitExportTitle => 'Frei exportieren und teilen';

  @override
  String get proBenefitExportBody =>
      'Speichere oder teile in jeder Größe, ohne etwas ansehen zu müssen.';

  @override
  String get proBenefitLocalTitle => 'Weiterhin auf deinem Gerät';

  @override
  String get proBenefitLocalBody =>
      'Pro ändert nichts an deinen Fotos: Jede Bearbeitung bleibt lokal, wie schon immer.';

  @override
  String get textLayer => 'Textebene';

  @override
  String get bubbleLayer => 'Sprechblasenebene';

  @override
  String get imageLayer => 'Bildebene';

  @override
  String get imageLayerCutOut => 'Bildebene · freigestellt';

  @override
  String dragToReorder(String name) {
    return '$name zum Umsortieren ziehen';
  }

  @override
  String get hideLayer => 'Ebene ausblenden';

  @override
  String get showLayer => 'Ebene einblenden';

  @override
  String get duplicateLayer => 'Ebene duplizieren';

  @override
  String get deleteLayer => 'Ebene löschen';

  @override
  String deleteLayerNamed(String name) {
    return 'Ebene $name löschen';
  }

  @override
  String get cutOut => 'Freigestellt';

  @override
  String get tapToAddPhoto => 'Tippe, um ein Foto hinzuzufügen';

  @override
  String get undo => 'Rückgängig';

  @override
  String get redo => 'Wiederholen';

  @override
  String get export => 'Export';

  @override
  String get customPixels => 'EIGENE GRÖSSE (PIXEL)';

  @override
  String get width => 'Breite';

  @override
  String get height => 'Höhe';

  @override
  String get create => 'Erstellen';

  @override
  String get scaleLayersToFit => 'Ebenen passend skalieren';

  @override
  String get scaleLayersToFitSub =>
      'Die gesamte Komposition für die neue Größe neu berechnen';

  @override
  String get presetSquare => 'Quadrat';

  @override
  String get presetPortrait => 'Hochformat';

  @override
  String get presetStory => 'Story';

  @override
  String get presetLandscape => 'Querformat';

  @override
  String get presetWide => 'Breit';

  @override
  String get presetSmall => 'Klein';

  @override
  String layersAutoSaved(String layers) {
    return '$layers · auto-gespeichert';
  }

  @override
  String engineWorking(String engine) {
    return '$engine arbeitet…';
  }

  @override
  String get toolLayers => 'Ebenen';

  @override
  String get toolAdjust => 'Anpassen';

  @override
  String get toolEffects => 'Effekte';

  @override
  String get toolText => 'Text';

  @override
  String get toolErase => 'Radieren';

  @override
  String get toolErasePanel => 'Manuelles Radieren';

  @override
  String get toolCutout => 'Freistellen';

  @override
  String get toolCutoutPanel => 'KI-Hintergrundfreistellung';

  @override
  String get toolFrames => 'Frames';

  @override
  String get toolFramesPanel => 'Animations-Frames';

  @override
  String get toolGrid => 'Raster';

  @override
  String get toolGridPanel => 'Fotoraster';

  @override
  String get filterOriginal => 'Original';

  @override
  String get filterVivid => 'Brillant';

  @override
  String get filterPunch => 'Kräftig';

  @override
  String get filterChrome => 'Chrom';

  @override
  String get filterWarm => 'Warm';

  @override
  String get filterCool => 'Kühl';

  @override
  String get filterSunset => 'Abendrot';

  @override
  String get filterDawn => 'Morgenrot';

  @override
  String get filterDusk => 'Dämmerung';

  @override
  String get filterFade => 'Verblasst';

  @override
  String get filterMatte => 'Matt';

  @override
  String get filterRetro => 'Retro';

  @override
  String get filterSepia => 'Sepia';

  @override
  String get filterMono => 'Mono';

  @override
  String get filterNoir => 'Noir';

  @override
  String get blendNormal => 'Normal';

  @override
  String get blendMultiply => 'Multiplizieren';

  @override
  String get blendScreen => 'Negativ multiplizieren';

  @override
  String get blendOverlay => 'Überlagern';

  @override
  String get blendDarken => 'Abdunkeln';

  @override
  String get blendLighten => 'Aufhellen';

  @override
  String get blendDodge => 'Abwedeln';

  @override
  String get blendBurn => 'Nachbelichten';

  @override
  String get blendHardLight => 'Hartes Licht';

  @override
  String get blendSoftLight => 'Weiches Licht';

  @override
  String get blendDifference => 'Differenz';

  @override
  String get blendExclusion => 'Ausschluss';

  @override
  String get blendHue => 'Farbton';

  @override
  String get blendSaturation => 'Sättigung';

  @override
  String get blendColor => 'Farbe';

  @override
  String get blendLuminosity => 'Luminanz';

  @override
  String get gridHowManyPhotos => 'WIE VIELE FOTOS?';

  @override
  String get gridLayoutLabel => 'LAYOUT';

  @override
  String get gridSizeLabel => 'GRÖSSE';

  @override
  String get gridSetupHint =>
      'Wähle als Nächstes deine Fotos - Layout, Anzahl und Rahmen kannst du jederzeit ändern.';

  @override
  String photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos',
      one: '1 Foto',
    );
    return '$_temp0';
  }

  @override
  String gridLayoutNamed(String name) {
    return 'Layout $name';
  }

  @override
  String get gridSideBySide => 'Links/rechts';

  @override
  String get gridStacked => 'Oben/unten';

  @override
  String get gridWideLeft => 'Breit links';

  @override
  String get gridTallTop => 'Hoch oben';

  @override
  String get gridColumns => 'Spalten';

  @override
  String get gridRows => 'Zeilen';

  @override
  String get gridBigLeft => 'Groß links';

  @override
  String get gridBigTop => 'Groß oben';

  @override
  String get gridTwoByTwo => '2 x 2';

  @override
  String get gridTwoOverThree => '2 über 3';

  @override
  String get gridThreeOverTwo => '3 über 2';

  @override
  String get gridTwoLeftThreeRight => '2 neben 3';

  @override
  String get exportTitle => 'Export & Teilen';

  @override
  String get formatLabel => 'FORMAT';

  @override
  String get formatPngSub => 'transparent';

  @override
  String get formatJpgSub => 'ohne Transparenz';

  @override
  String get formatWebpSub => 'kleiner';

  @override
  String get resolutionLabel => 'AUFLÖSUNG';

  @override
  String exportOutput(
    int width,
    int height,
    String format,
    String transparent,
  ) {
    return 'Ausgabe · $width × $height px · $format$transparent';
  }

  @override
  String get transparentParenthetical => '(transparent)';

  @override
  String get saveToDevice => 'Auf Gerät speichern';

  @override
  String get share => 'Teilen';

  @override
  String savedTo(String location) {
    return 'Gespeichert · $location';
  }

  @override
  String get storageDenied =>
      'Erlaube den Speicherzugriff, um in deiner Galerie zu speichern';

  @override
  String get saveFailed => 'Bild konnte nicht gespeichert werden';

  @override
  String get exportFailed => 'Export fehlgeschlagen - versuche es erneut';

  @override
  String get shareFailed => 'Teilen fehlgeschlagen - versuche es erneut';

  @override
  String get exportGateTitle => 'Kurze Werbung ansehen und exportieren';

  @override
  String get exportGateMessage =>
      'Kostenlose Exporte werden durch eine kurze Werbung ermöglicht. Hol dir Pro und exportiere für immer ohne Werbung.';

  @override
  String get exportGateWatch => 'Ansehen & exportieren';

  @override
  String get swatchWhite => 'Weiß';

  @override
  String get swatchBlack => 'Schwarz';

  @override
  String get swatchPink => 'Pink';

  @override
  String get swatchAmber => 'Bernstein';

  @override
  String get swatchGreen => 'Grün';

  @override
  String get swatchCyan => 'Cyan';

  @override
  String get swatchViolet => 'Violett';

  @override
  String get swatchRose => 'Rosé';

  @override
  String get swatchOrange => 'Orange';
}
