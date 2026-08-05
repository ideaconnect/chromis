// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Chromis';

  @override
  String get back => 'Retour';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get done => 'Terminé';

  @override
  String get delete => 'Supprimer';

  @override
  String get rename => 'Renommer';

  @override
  String get duplicate => 'Dupliquer';

  @override
  String get open => 'Ouvrir';

  @override
  String get close => 'Fermer';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get apply => 'Appliquer';

  @override
  String get add => 'Ajouter';

  @override
  String get remove => 'Retirer';

  @override
  String get menu => 'Menu';

  @override
  String get settings => 'Paramètres';

  @override
  String get about => 'À propos';

  @override
  String get licenses => 'Licences';

  @override
  String get nameHint => 'Nom';

  @override
  String get cannotBeUndone => 'Cette action est irréversible.';

  @override
  String get tryAgainInAMoment => 'Réessayez dans un instant.';

  @override
  String get appLogo => 'Logo Chromis';

  @override
  String get pleaseTryAgain => 'veuillez réessayer';

  @override
  String get homeTitle => 'Vos projets';

  @override
  String get homeTagline => 'Chromis · Éditeur photo avec détourage IA';

  @override
  String get homeRecent => 'RÉCENTS';

  @override
  String get homeJoinDiscord => 'Rejoindre notre Discord';

  @override
  String get homeEmptyHint => 'Touchez Nouveau projet pour importer une photo.';

  @override
  String get noProjectsYet => 'Aucun projet pour l\'instant';

  @override
  String get newProject => 'Nouveau projet';

  @override
  String get homeNewProjectSubtitle => 'Toile vierge ou grille photo';

  @override
  String get homeOpenPhoto => 'Ouvrir une photo';

  @override
  String get homeOpenPhotoSubtitle => 'La toile prend la taille de la photo';

  @override
  String projectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count projets',
      one: '$count projet',
    );
    return '$_temp0';
  }

  @override
  String layerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count calques',
      one: '$count calque',
    );
    return '$_temp0';
  }

  @override
  String get renameProject => 'Renommer le projet';

  @override
  String get projectNameHint => 'Nom du projet';

  @override
  String get copySuffix => '(copie)';

  @override
  String deleteProjectTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get allProjects => 'Tous les projets';

  @override
  String get searchProjects => 'Rechercher dans vos projets';

  @override
  String get projectsLoadFailed => 'Impossible de charger vos projets';

  @override
  String get allProjectsEmptyHint =>
      'Créez-en un depuis l\'accueil et il apparaîtra ici.';

  @override
  String get noMatches => 'Aucun résultat';

  @override
  String noMatchesFor(String query) {
    return 'Rien ne correspond à « $query ».';
  }

  @override
  String get newProjectQuestion => 'Que voulez-vous créer ?';

  @override
  String get blankCanvas => 'Toile vierge';

  @override
  String get blankCanvasSubtitle =>
      'Une toile, ajoutez photos et calques librement';

  @override
  String get photoGrid => 'Grille photo';

  @override
  String get photoGridSubtitle =>
      'Un collage de 2 à 5 photos dans une disposition';

  @override
  String get drawerHome => 'Accueil et projets';

  @override
  String drawerSubtitle(String version) {
    return 'Éditeur photo · v$version';
  }

  @override
  String get appearance => 'Apparence';

  @override
  String get appearanceSystem => 'Paramètre du système';

  @override
  String get appearanceSystemSub =>
      'Suivre le réglage clair ou sombre du téléphone';

  @override
  String get appearanceLight => 'Clair';

  @override
  String get appearanceLightSub =>
      'Plus lisible en extérieur et sur les écrans LCD';

  @override
  String get appearanceDark => 'Sombre';

  @override
  String get appearanceDarkSub =>
      'Noir pur, que les écrans OLED n’éclairent pas du tout';

  @override
  String get appearanceNote =>
      'Chromis suit le téléphone, sauf si vous en choisissez un ici. Votre choix est conservé.';

  @override
  String get language => 'Langue';

  @override
  String get languageSystem => 'Langue du système';

  @override
  String get languageSystemSub =>
      'Suivre la langue définie sur votre téléphone';

  @override
  String get languageNote =>
      'Chromis s\'affiche en anglais, sauf si votre téléphone est réglé sur une langue dans laquelle l\'application est traduite. Votre choix ici est mémorisé.';

  @override
  String get skip => 'Passer';

  @override
  String get next => 'Suivant';

  @override
  String get getStarted => 'Commencer';

  @override
  String get onboardStartTitle => 'Partez d\'une photo';

  @override
  String get onboardStartBody =>
      'Ouvrez une photo, ou une toile vierge à la taille voulue. Ajoutez des calques, du texte et des bulles de BD.';

  @override
  String get onboardCutoutTitle => 'Supprimez l\'arrière-plan';

  @override
  String get onboardCutoutBody =>
      'Détachez votre sujet de son arrière-plan d\'une seule touche, ou effacez des objets - le tout sur l\'appareil, vos photos ne quittent jamais votre téléphone.';

  @override
  String get onboardExportTitle => 'Exportez et partagez';

  @override
  String get onboardExportBody =>
      'Enregistrez un PNG transparent, un JPG ou un WebP à n\'importe quelle résolution, puis partagez-le partout.';

  @override
  String get privacyTitle => 'Confidentialité et cookies';

  @override
  String get privacyRowSub =>
      'Édition sur l\'appareil · fonctionnement des publicités';

  @override
  String get privacyBanner =>
      'Vos photos restent sur votre appareil. Les publicités sont la seule exception - expliquée ci-dessous.';

  @override
  String get privacyOnDevice =>
      'Vos photos sont modifiées entièrement sur votre appareil - rien n\'est envoyé en ligne.';

  @override
  String get privacyAiLocal =>
      'Le détourage et la suppression d\'objets par IA s\'exécutent localement ; vos photos ne quittent jamais votre téléphone.';

  @override
  String get privacyNoAccounts =>
      'Aucun compte, aucune connexion, aucun envoi de photos.';

  @override
  String get privacyAds =>
      'L\'application gratuite affiche des publicités (Google AdMob), qui utilisent un identifiant publicitaire.';

  @override
  String get privacyConsent =>
      'Lorsque cela est requis, une demande de consentement (UMP) vous permet de choisir entre des publicités personnalisées et non personnalisées.';

  @override
  String get privacyWithdraw =>
      'Vous pouvez modifier ou retirer ce consentement à tout moment - « Confidentialité des publicités » ci-dessous rouvre le formulaire.';

  @override
  String get privacyPro =>
      'L\'achat unique Pro supprime toutes les publicités - et l\'identifiant publicitaire avec elles.';

  @override
  String get fullPrivacyPolicy => 'Politique de confidentialité complète';

  @override
  String get questions => 'Des questions ?';

  @override
  String get openSourceLicenses => 'Licences open source';

  @override
  String get licensesRowSub => 'Les projets sur lesquels nous nous appuyons';

  @override
  String get licensesIntro =>
      'Chromis repose sur de formidables projets open source. Merci à toutes celles et ceux qui les ont créés.';

  @override
  String get viewFullLicenseTexts => 'Voir les textes complets des licences';

  @override
  String get licenseCategoryFonts => 'Polices';

  @override
  String get licenseCategoryAi => 'IA sur l\'appareil';

  @override
  String get licenseCategoryEncoding => 'Encodage des médias';

  @override
  String get licenseCategoryMonetization => 'Monétisation';

  @override
  String get licenseCategoryFramework => 'Framework et paquets';

  @override
  String get licenseUseDisplayFont => 'Police d\'affichage / de titres';

  @override
  String get licenseUseBodyFont => 'Police d\'interface / de texte';

  @override
  String get licenseUseComicFont => 'Police de légende BD';

  @override
  String get licenseUseCaptionFont => 'Police de légende';

  @override
  String get licenseUseScriptFont => 'Police de légende manuscrite';

  @override
  String get licenseUseBgRemoval => 'Détourage de l\'arrière-plan (Android)';

  @override
  String get licenseUseRuntime => 'Exécute le modèle de secours intégré';

  @override
  String get licenseUseOnDeviceAi =>
      'Détourage et suppression d\'objets sur l\'appareil';

  @override
  String get licenseUseEncoding => 'Encodage PNG / JPG / WebP';

  @override
  String get licenseUseAds =>
      'Publicités bannière / avec récompense + consentement';

  @override
  String get licenseUsePurchase => 'Achat unique Pro (sans publicité)';

  @override
  String get licenseUseFramework => 'Framework de l\'application';

  @override
  String get licenseUsePlugins =>
      'Navigation, stockage, partage, choix d\'images';

  @override
  String get licenseUseState => 'Gestion de l\'état';

  @override
  String get licenseUseClipboard => 'Coller une image depuis le presse-papiers';

  @override
  String get goPro => 'Passer Pro';

  @override
  String get goProRemoveAds => 'Passer Pro · sans pub';

  @override
  String get goProRemoveAdsPlain => 'Passer Pro - sans pub';

  @override
  String get goProRowSub => 'Achat unique - plus jamais de publicité';

  @override
  String get goProHeroTitle => 'Sans publicité, pour toujours';

  @override
  String get goProHeroBody =>
      'Achat unique. Toutes les fonctions IA restent gratuites - sans publicité, sans vidéo à regarder.';

  @override
  String get goProBenefitNoAds => 'Ni bannière, ni publicité plein écran';

  @override
  String get goProBenefitNoRewarded =>
      'Détourage IA et suppression d\'objets sans publicité à regarder';

  @override
  String get goProBenefitOneTime => 'Paiement unique - sans abonnement';

  @override
  String get goProBenefitSupports =>
      'Soutient l\'édition photo privée, sur l\'appareil';

  @override
  String get goProOwned =>
      'Vous êtes Pro - les publicités sont désactivées. Merci !';

  @override
  String upgradeFor(String price) {
    return 'Passer Pro - $price';
  }

  @override
  String get restorePurchase => 'Restaurer l\'achat';

  @override
  String get oneTimeUnavailable => 'Achat unique · temporairement indisponible';

  @override
  String get oneTimeRestores => 'Achat unique · restaurable sur tout appareil';

  @override
  String get oneTimeNoSubscription => 'Achat unique. Sans abonnement.';

  @override
  String get purchasesUnavailable =>
      'Les achats sont temporairement indisponibles - veuillez réessayer plus tard.';

  @override
  String get purchaseStartFailed =>
      'Impossible de démarrer l\'achat - veuillez réessayer.';

  @override
  String get purchaseStartFailedOwned =>
      'Impossible de démarrer l\'achat - si vous avez déjà acheté Pro, touchez Restaurer l\'achat.';

  @override
  String get checkingPreviousPurchase => 'Recherche d\'un achat précédent…';

  @override
  String get playUnreachable =>
      'Impossible de joindre Google Play - vérifiez votre connexion et réessayez.';

  @override
  String get purchaseFailedGeneric => 'L\'achat n\'a pas pu être finalisé';

  @override
  String get removeAdsArrow => 'Sans publicité →';

  @override
  String get adsDeclinedExplainer =>
      'Vous avez choisi de refuser les publicités : il n\'y a donc aucune publicité à regarder - et ce sont elles qui permettent à Chromis de rester gratuit.\n\nAcceptez les publicités pour continuer gratuitement, ou passez à Pro pour tout utiliser sans aucune publicité.';

  @override
  String get reviewAdConsent => 'Revoir le consentement';

  @override
  String get adPrivacyChoices => 'Confidentialité des publicités';

  @override
  String get adPrivacyChoicesSub =>
      'Modifier le consentement donné pour les publicités personnalisées';

  @override
  String adSettingsFailed(String error) {
    return 'Impossible d\'ouvrir les paramètres publicitaires : $error';
  }

  @override
  String get untitledProject => 'Sans titre';

  @override
  String get photoLayerDefault => 'Photo';

  @override
  String get textLayerDefault => 'Texte';

  @override
  String get mergedLayerName => 'Fusionné';

  @override
  String get mergedLayerSuffix => 'fusion';

  @override
  String get saveRetrying =>
      'Impossible d\'enregistrer - vos modifications sont intactes, on réessaie';

  @override
  String get speed => 'Vitesse';

  @override
  String get fillingBackground => 'Remplissage de l\'arrière-plan…';

  @override
  String get findingObject => 'Recherche de l\'objet…';

  @override
  String get mergingLayers => 'Fusion des calques…';

  @override
  String get removingBackground => 'Suppression de l\'arrière-plan…';

  @override
  String get hideToolPanel => 'Masquer le panneau d\'outils';

  @override
  String get showToolPanel => 'Afficher le panneau d\'outils';

  @override
  String get cropOpenFailed => 'Impossible d\'ouvrir la photo à recadrer';

  @override
  String get photoCropped => 'Photo recadrée';

  @override
  String get editCrop => 'Modifier le recadrage';

  @override
  String get cropPhoto => 'Recadrer la photo';

  @override
  String get resetCrop => 'Réinitialiser le recadrage';

  @override
  String get crop => 'Recadrer';

  @override
  String get cancelCrop => 'Annuler le recadrage';

  @override
  String get previewUnavailable => 'Aperçu indisponible';

  @override
  String get cropToRatio => 'Recadrer au format';

  @override
  String get cropSheetHint =>
      'Tracez un cadre libre ou recadrez au centre selon un format';

  @override
  String get freeformCrop => 'Recadrage libre';

  @override
  String get ratiosSection => 'FORMATS';

  @override
  String croppedTo(int width, int height) {
    return 'Toile recadrée en $width×$height';
  }

  @override
  String get scale => 'Échelle';

  @override
  String get rotation => 'Rotation';

  @override
  String get horizontal => 'Horizontal';

  @override
  String get vertical => 'Vertical';

  @override
  String get brightness => 'Luminosité';

  @override
  String get contrast => 'Contraste';

  @override
  String get saturation => 'Saturation';

  @override
  String get hue => 'Teinte';

  @override
  String get opacity => 'Opacité';

  @override
  String get size => 'Taille';

  @override
  String get color => 'Couleur';

  @override
  String get off => 'Désactivé';

  @override
  String get adjustEmptyHint =>
      'Sélectionnez un calque pour le redimensionner, le faire pivoter ou le régler.\nOu touchez Ajouter pour importer une photo.';

  @override
  String get effectsLink => 'Filtres, HDR, vignettage, ombre…';

  @override
  String get effectsLinkLayer => 'Fusion, ombre, contour…';

  @override
  String get textEmptyHint =>
      'Sélectionnez un calque de texte ou ajoutez-en un.';

  @override
  String get addText => 'Ajouter du texte';

  @override
  String get tapFontToPreview => 'Touchez pour l\'aperçu';

  @override
  String get typeYourCaption => 'Saisissez votre texte…';

  @override
  String get outlineSection => 'CONTOUR';

  @override
  String get cutoutOutlineSection => 'CONTOUR DU DÉTOURAGE';

  @override
  String get autoColor => 'Couleur auto';

  @override
  String get thickness => 'Épaisseur';

  @override
  String get outlineOpacity => 'Opacité du contour';

  @override
  String get font => 'Police';

  @override
  String fontAdded(String family) {
    return 'Police ajoutée · $family';
  }

  @override
  String get comicBubble => 'Bulle BD';

  @override
  String get bubble => 'Bulle';

  @override
  String get bubbleTextHint => 'Texte de la bulle…';

  @override
  String get fill => 'Remplissage';

  @override
  String get outline => 'Contour';

  @override
  String get bubbleTailHint =>
      'Faites glisser le point au bout de la queue pour l\'orienter - dans toutes les directions.';

  @override
  String get addABubble => 'Ajouter une bulle';

  @override
  String get addABubbleHint =>
      'Choisissez un format. Le texte, les couleurs et la queue restent modifiables ensuite - ce choix aussi.';

  @override
  String get addBubble => 'Ajouter une bulle';

  @override
  String bubbleAdded(String format) {
    return 'Bulle $format ajoutée - modifiez-la dans le panneau';
  }

  @override
  String bubbleTileSemantics(String format, String description) {
    return 'Bulle $format - $description';
  }

  @override
  String get bubbleSpeech => 'Dialogue';

  @override
  String get bubbleThought => 'Pensée';

  @override
  String get bubbleShout => 'Cri';

  @override
  String get bubbleCaption => 'Cartouche';

  @override
  String get bubbleWhisper => 'Chuchotement';

  @override
  String get bubbleSpeechBlurb => 'Arrondie, avec une queue';

  @override
  String get bubbleThoughtBlurb => 'Nuage avec une traînée de points';

  @override
  String get bubbleShoutBlurb => 'Explosion en étoile pointue';

  @override
  String get bubbleCaptionBlurb => 'Encadré de narration carré';

  @override
  String get bubbleWhisperBlurb => 'Contour en pointillés';

  @override
  String get notAPhotoGrid => 'Ce projet n\'est pas une grille photo.';

  @override
  String get shuffle => 'Mélanger';

  @override
  String get photosSection => 'PHOTOS';

  @override
  String get layoutSection => 'DISPOSITION';

  @override
  String get border => 'Bordure';

  @override
  String get corners => 'Coins';

  @override
  String get effectsEmptyHint =>
      'Sélectionnez un calque pour lui donner un style.\nFiltres, HDR et vignettage pour les photos ; ombre, contour et mode de fusion pour tous les calques.';

  @override
  String get filterSection => 'FILTRE';

  @override
  String get strength => 'Intensité';

  @override
  String get hdrSection => 'HDR';

  @override
  String get toneAndDetail => 'Tons + détail';

  @override
  String get vignetteSection => 'VIGNETTAGE';

  @override
  String get amount => 'Quantité';

  @override
  String get softness => 'Douceur';

  @override
  String get shadowSection => 'OMBRE';

  @override
  String get direction => 'Direction';

  @override
  String get distance => 'Distance';

  @override
  String get blur => 'Flou';

  @override
  String get density => 'Densité';

  @override
  String get blendSection => 'MODE DE FUSION';

  @override
  String pixels(int count) {
    return '$count px';
  }

  @override
  String get working => 'Traitement…';

  @override
  String get undoRemoval => 'Annuler la suppression';

  @override
  String get removeBackground => 'Supprimer l\'arrière-plan';

  @override
  String get removeAnObject => 'Supprimer un objet';

  @override
  String get removeObject => 'Supprimer l\'objet';

  @override
  String get background => 'Arrière-plan';

  @override
  String get object => 'Objet';

  @override
  String get erase => 'Effacer';

  @override
  String get restore => 'Restaurer';

  @override
  String get fillIn => 'Remplir';

  @override
  String get fillExplainer =>
      'Le remplissage reconstitue l\'arrière-plan à partir du reste de la photo.';

  @override
  String get eraseExplainer =>
      'L\'effacement découpe l\'objet et laisse une zone transparente.';

  @override
  String get objectRemoveHint =>
      'Touchez un objet indésirable sur la photo pour le supprimer - un élément parasite, un second sujet, du désordre. Toucher le sujet principal reste sans effet ; Annuler restaure tout.';

  @override
  String get cutoutSelectPhoto => 'Sélectionnez un calque photo à détourer.';

  @override
  String get cutoutHint =>
      'Une seule touche pour isoler votre sujet. Les contours sont détectés automatiquement - affinez-les à la main dans l\'outil Gomme.';

  @override
  String get backgroundRestored => 'Arrière-plan restauré';

  @override
  String get aiModelSection => 'MODÈLE IA';

  @override
  String get whichAiModel => 'Quel modèle IA ?';

  @override
  String get segBuiltinLabel => 'IA intégrée';

  @override
  String get segBuiltinTagline => 'Sur l\'appareil · rapide et privé';

  @override
  String get segBuiltinBlurb =>
      'S\'exécute sur l\'appareil pour des détourages rapides et privés. Idéale pour les animaux et les personnes aux contours nets - rien ne quitte votre téléphone.';

  @override
  String get segU2netTagline => 'Open source · détails plus nets';

  @override
  String get segU2netBlurb =>
      'Un modèle open source de détection du sujet, fourni avec l\'application. Fonctionne entièrement hors ligne et rend souvent mieux les détails fins comme les poils, les cheveux et les moustaches - un peu plus lent.';

  @override
  String get aiGateTitle => 'Débloquer les outils IA';

  @override
  String get aiGateMessage =>
      'Regardez une courte publicité pour utiliser les outils IA pendant le reste de cette session d\'édition. Passez à Pro pour en profiter sans publicité, à vie.';

  @override
  String get aiGateWatch => 'Regarder et débloquer';

  @override
  String get aiGateNotRewarded =>
      'Regardez la publicité en entier pour utiliser l\'IA, ou passez à Pro pour supprimer les publicités';

  @override
  String get objectAiUnavailable =>
      'L\'IA de suppression d\'objet n\'est pas disponible sur cet appareil - utilisez plutôt la Gomme';

  @override
  String get bgRemovalUnavailable =>
      'La suppression de l\'arrière-plan n\'est pas encore disponible sur cet appareil';

  @override
  String get layerGoneCutoutDiscarded =>
      'Ce calque n\'existe plus - le détourage a été abandonné';

  @override
  String get backgroundRemoved => 'Arrière-plan supprimé';

  @override
  String backgroundRemovedWith(String engine) {
    return 'Arrière-plan supprimé · $engine';
  }

  @override
  String get bgRemovalFailed =>
      'Impossible de supprimer l\'arrière-plan - réessayez';

  @override
  String get selectPhotoToCutOut => 'Sélectionnez un calque photo à détourer';

  @override
  String get detectingSubject =>
      'Détection du sujet et affinage des contours · sur l\'appareil';

  @override
  String get edgeFeather => 'Contour adouci';

  @override
  String get applyToLayer => 'Appliquer au calque';

  @override
  String get tapObjectsToErase => 'Touchez les objets à effacer sur la photo';

  @override
  String get tapObjectsToRemove => 'Touchez les objets à supprimer';

  @override
  String get tapAnObjectToRemove =>
      'Touchez un objet sur la photo pour le supprimer';

  @override
  String get chooseAiEngine =>
      'Choisissez un moteur IA · s\'exécute sur l\'appareil';

  @override
  String get autoRefineEdges => 'Affinage auto des contours';

  @override
  String get brushFailed => 'Impossible d\'appliquer le pinceau';

  @override
  String get nothingToRemoveThere => 'Rien à supprimer à cet endroit';

  @override
  String get objectRemoved => 'Objet supprimé - Annuler le restaure';

  @override
  String get objectRemoveFailed =>
      'Impossible de supprimer cet objet - réessayez';

  @override
  String get noObjectThere => 'Aucun objet trouvé à cet endroit';

  @override
  String get thatLooksLikeSubject =>
      'Cela ressemble à votre sujet - utilisez la Gomme pour les retouches fines';

  @override
  String get fillUnavailable =>
      'Impossible de reconstituer cette zone - objet effacé à la place';

  @override
  String get objectFilled => 'Objet rempli - Annuler restaure l\'original';

  @override
  String get eraseEmptyHint =>
      'Sélectionnez un calque photo sur lequel effacer, ou ajoutez une photo.';

  @override
  String get brushOverCanvas => 'Peignez sur la toile';

  @override
  String get brushSize => 'Taille du pinceau';

  @override
  String get softEdges => 'Bords doux';

  @override
  String get play => 'Lire';

  @override
  String get pause => 'Pause';

  @override
  String get newLayersToAllFrames => 'Nouveaux calques sur toutes les images';

  @override
  String get onionSkin => 'Pelure d\'oignon (image précédente)';

  @override
  String get duplicateFrame => 'Dupliquer l\'image';

  @override
  String get moveLeft => 'Déplacer à gauche';

  @override
  String get moveRight => 'Déplacer à droite';

  @override
  String get deleteFrame => 'Supprimer l\'image';

  @override
  String frameOf(int current, int total) {
    return 'Image $current / $total';
  }

  @override
  String get mergeDown => 'Fusionner vers le bas';

  @override
  String get flatten => 'Aplatir';

  @override
  String get layersEmptyHint =>
      'Aucun calque pour l\'instant. Touchez Ajouter pour importer une photo ou ajouter du texte.';

  @override
  String get mergedTwoLayers => '2 calques fusionnés';

  @override
  String flattenedLayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count calques aplatis',
      one: '$count calque aplati',
    );
    return '$_temp0';
  }

  @override
  String get mergeFailed => 'Impossible de fusionner ces calques';

  @override
  String get importPhotoFailed => 'Impossible d\'importer la photo';

  @override
  String get noImageInClipboard => 'Aucune image dans le presse-papiers';

  @override
  String get pasteFailed => 'Impossible de coller l\'image';

  @override
  String get takePhoto => 'Prendre une photo';

  @override
  String get choosePhoto => 'Choisir une photo';

  @override
  String get pasteImage => 'Coller une image';

  @override
  String get renameLayer => 'Renommer le calque';

  @override
  String get canvasSize => 'Taille de la toile';

  @override
  String get addLayer => 'Photo';

  @override
  String get aiCut => 'Détourage';

  @override
  String get seeThePrice => 'Voir le prix';

  @override
  String get notNow => 'Pas maintenant';

  @override
  String get oneTimeNoSubscriptionShort => 'Achat unique, sans abonnement';

  @override
  String get proBenefitNoAdsTitle => 'Aucune publicité, nulle part';

  @override
  String get proBenefitNoAdsBody =>
      'La bannière de l\'accueil et les publicités plein écran disparaissent définitivement.';

  @override
  String get proBenefitAiTitle => 'L\'IA sans attente';

  @override
  String get proBenefitAiBody =>
      'Le détourage de l\'arrière-plan et l\'effacement d\'objets démarrent aussitôt - aucune publicité à regarder d\'abord.';

  @override
  String get proBenefitExportTitle => 'Exporter et partager librement';

  @override
  String get proBenefitExportBody =>
      'Enregistrez ou partagez à n\'importe quelle taille, sans rien regarder.';

  @override
  String get proBenefitLocalTitle => 'Toujours sur votre appareil';

  @override
  String get proBenefitLocalBody =>
      'Pro ne change rien à vos photos. Chaque modification reste locale, comme toujours.';

  @override
  String get textLayer => 'Calque de texte';

  @override
  String get bubbleLayer => 'Calque de bulle';

  @override
  String get imageLayer => 'Calque d\'image';

  @override
  String get imageLayerCutOut => 'Calque d\'image · détouré';

  @override
  String dragToReorder(String name) {
    return 'Faire glisser pour réorganiser $name';
  }

  @override
  String get hideLayer => 'Masquer le calque';

  @override
  String get showLayer => 'Afficher le calque';

  @override
  String get duplicateLayer => 'Dupliquer le calque';

  @override
  String get deleteLayer => 'Supprimer le calque';

  @override
  String deleteLayerNamed(String name) {
    return 'Supprimer le calque $name';
  }

  @override
  String get cutOut => 'Détouré';

  @override
  String get tapToAddPhoto => 'Touchez pour ajouter une photo';

  @override
  String get undo => 'Annuler';

  @override
  String get redo => 'Rétablir';

  @override
  String get export => 'Exporter';

  @override
  String get customPixels => 'PERSONNALISÉ (PIXELS)';

  @override
  String get width => 'Largeur';

  @override
  String get height => 'Hauteur';

  @override
  String get create => 'Créer';

  @override
  String get scaleLayersToFit => 'Adapter les calques';

  @override
  String get scaleLayersToFitSub =>
      'Rééchantillonner toute la composition à la nouvelle taille';

  @override
  String get presetSquare => 'Carré';

  @override
  String get presetPortrait => 'Portrait';

  @override
  String get presetStory => 'Story';

  @override
  String get presetLandscape => 'Paysage';

  @override
  String get presetWide => 'Panoramique';

  @override
  String get presetSmall => 'Petit';

  @override
  String layersAutoSaved(String layers) {
    return '$layers · enregistrement auto';
  }

  @override
  String engineWorking(String engine) {
    return '$engine : traitement en cours…';
  }

  @override
  String get toolLayers => 'Calques';

  @override
  String get toolAdjust => 'Réglages';

  @override
  String get toolEffects => 'Effets';

  @override
  String get toolText => 'Texte';

  @override
  String get toolErase => 'Gomme';

  @override
  String get toolErasePanel => 'Gomme manuelle';

  @override
  String get toolCutout => 'Détourer';

  @override
  String get toolCutoutPanel => 'Détourage IA d\'arrière-plan';

  @override
  String get toolFrames => 'Images';

  @override
  String get toolFramesPanel => 'Images d\'animation';

  @override
  String get toolGrid => 'Grille';

  @override
  String get toolGridPanel => 'Grille photo';

  @override
  String get filterOriginal => 'Original';

  @override
  String get filterVivid => 'Éclatant';

  @override
  String get filterPunch => 'Impact';

  @override
  String get filterChrome => 'Chrome';

  @override
  String get filterWarm => 'Chaud';

  @override
  String get filterCool => 'Froid';

  @override
  String get filterSunset => 'Couchant';

  @override
  String get filterDawn => 'Aube';

  @override
  String get filterDusk => 'Crépuscule';

  @override
  String get filterFade => 'Délavé';

  @override
  String get filterMatte => 'Mat';

  @override
  String get filterRetro => 'Rétro';

  @override
  String get filterSepia => 'Sépia';

  @override
  String get filterMono => 'Mono';

  @override
  String get filterNoir => 'Noir';

  @override
  String get blendNormal => 'Normal';

  @override
  String get blendMultiply => 'Produit';

  @override
  String get blendScreen => 'Superposition';

  @override
  String get blendOverlay => 'Incrustation';

  @override
  String get blendDarken => 'Obscurcir';

  @override
  String get blendLighten => 'Éclaircir';

  @override
  String get blendDodge => 'Densité -';

  @override
  String get blendBurn => 'Densité +';

  @override
  String get blendHardLight => 'Lumière crue';

  @override
  String get blendSoftLight => 'Lumière tamisée';

  @override
  String get blendDifference => 'Différence';

  @override
  String get blendExclusion => 'Exclusion';

  @override
  String get blendHue => 'Teinte';

  @override
  String get blendSaturation => 'Saturation';

  @override
  String get blendColor => 'Couleur';

  @override
  String get blendLuminosity => 'Luminosité';

  @override
  String get gridHowManyPhotos => 'COMBIEN DE PHOTOS ?';

  @override
  String get gridLayoutLabel => 'DISPOSITION';

  @override
  String get gridSizeLabel => 'TAILLE';

  @override
  String get gridSetupHint =>
      'Choisissez ensuite vos photos. Disposition, nombre et bordure restent modifiables à tout moment.';

  @override
  String photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '$count photo',
    );
    return '$_temp0';
  }

  @override
  String gridLayoutNamed(String name) {
    return 'Disposition $name';
  }

  @override
  String get gridSideBySide => 'Côte à côte';

  @override
  String get gridStacked => 'Empilée';

  @override
  String get gridWideLeft => 'Large gauche';

  @override
  String get gridTallTop => 'Haute en haut';

  @override
  String get gridColumns => 'Colonnes';

  @override
  String get gridRows => 'Lignes';

  @override
  String get gridBigLeft => 'Grande gauche';

  @override
  String get gridBigTop => 'Grande en haut';

  @override
  String get gridTwoByTwo => '2 x 2';

  @override
  String get gridTwoOverThree => '2 sur 3';

  @override
  String get gridThreeOverTwo => '3 sur 2';

  @override
  String get gridTwoLeftThreeRight => '2 g. / 3 d.';

  @override
  String get exportTitle => 'Exporter et partager';

  @override
  String get formatLabel => 'FORMAT';

  @override
  String get formatPngSub => 'transparent';

  @override
  String get formatJpgSub => 'aplati';

  @override
  String get formatWebpSub => 'plus léger';

  @override
  String get resolutionLabel => 'RÉSOLUTION';

  @override
  String exportOutput(
    int width,
    int height,
    String format,
    String transparent,
  ) {
    return 'Sortie · $width × $height px · $format$transparent';
  }

  @override
  String get transparentParenthetical => '(transparent)';

  @override
  String get saveToDevice => 'Enregistrer sur l\'appareil';

  @override
  String get share => 'Partager';

  @override
  String savedTo(String location) {
    return 'Enregistré · $location';
  }

  @override
  String get storageDenied =>
      'Autorisez l\'accès au stockage pour enregistrer dans votre galerie';

  @override
  String get saveFailed => 'Impossible d\'enregistrer l\'image';

  @override
  String get exportFailed => 'Échec de l\'export - réessayez';

  @override
  String get shareFailed => 'Échec du partage - réessayez';

  @override
  String get exportGateTitle => 'Regardez une courte publicité pour exporter';

  @override
  String get exportGateMessage =>
      'Les exports gratuits sont financés par une courte publicité. Passez à Pro pour exporter sans publicité, à vie.';

  @override
  String get exportGateWatch => 'Regarder et exporter';

  @override
  String get swatchWhite => 'blanc';

  @override
  String get swatchBlack => 'noir';

  @override
  String get swatchPink => 'rose';

  @override
  String get swatchAmber => 'ambre';

  @override
  String get swatchGreen => 'vert';

  @override
  String get swatchCyan => 'cyan';

  @override
  String get swatchViolet => 'violet';

  @override
  String get swatchRose => 'rose pâle';

  @override
  String get swatchOrange => 'orange';
}
