// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Chromis';

  @override
  String get back => 'Back';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get done => 'Done';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get open => 'Open';

  @override
  String get close => 'Close';

  @override
  String get reset => 'Reset';

  @override
  String get apply => 'Apply';

  @override
  String get add => 'Add';

  @override
  String get remove => 'Remove';

  @override
  String get menu => 'Menu';

  @override
  String get settings => 'Settings';

  @override
  String get about => 'About';

  @override
  String get licenses => 'Licenses';

  @override
  String get nameHint => 'Name';

  @override
  String get cannotBeUndone => 'This can\'t be undone.';

  @override
  String get tryAgainInAMoment => 'Try again in a moment.';

  @override
  String get appLogo => 'Chromis logo';

  @override
  String get pleaseTryAgain => 'please try again';

  @override
  String get homeTitle => 'Your projects';

  @override
  String get homeTagline => 'Chromis · Photo editor with AI cutout';

  @override
  String get homeRecent => 'RECENT';

  @override
  String get homeJoinDiscord => 'Join our Discord';

  @override
  String get homeEmptyHint => 'Tap New project to import a photo.';

  @override
  String get noProjectsYet => 'No projects yet';

  @override
  String get newProject => 'New project';

  @override
  String get homeNewProjectSubtitle => 'Blank canvas or a photo grid';

  @override
  String get homeOpenPhoto => 'Open a photo';

  @override
  String get homeOpenPhotoSubtitle => 'Canvas takes the photo\'s size';

  @override
  String projectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count projects',
      one: '1 project',
    );
    return '$_temp0';
  }

  @override
  String layerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count layers',
      one: '1 layer',
    );
    return '$_temp0';
  }

  @override
  String get renameProject => 'Rename project';

  @override
  String get projectNameHint => 'Project name';

  @override
  String get copySuffix => 'copy';

  @override
  String deleteProjectTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get allProjects => 'All projects';

  @override
  String get searchProjects => 'Search your projects';

  @override
  String get projectsLoadFailed => 'Couldn\'t load your projects';

  @override
  String get allProjectsEmptyHint =>
      'Create one from Home and it will show up here.';

  @override
  String get noMatches => 'No matches';

  @override
  String noMatchesFor(String query) {
    return 'Nothing matches \"$query\".';
  }

  @override
  String get newProjectQuestion => 'What are you making?';

  @override
  String get blankCanvas => 'Blank canvas';

  @override
  String get blankCanvasSubtitle => 'One canvas, add photos and layers freely';

  @override
  String get photoGrid => 'Photo grid';

  @override
  String get photoGridSubtitle => 'A collage of 2 to 5 photos in a layout';

  @override
  String get drawerHome => 'Home & projects';

  @override
  String drawerSubtitle(String version) {
    return 'Photo editor · v$version';
  }

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceSystem => 'System default';

  @override
  String get appearanceSystemSub => 'Follow your phone’s light or dark setting';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceLightSub => 'Easier to read outdoors and on LCD screens';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get appearanceDarkSub =>
      'True black, which OLED screens draw as no light at all';

  @override
  String get appearanceNote =>
      'Chromis follows your phone unless you pick one here. Your choice is remembered.';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageSystemSub => 'Follow the language your phone is set to';

  @override
  String get languageNote =>
      'Chromis is in English unless your phone is set to a language it has been translated into. Your choice here is remembered.';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get started';

  @override
  String get onboardStartTitle => 'Start from a photo';

  @override
  String get onboardStartBody =>
      'Open any photo, or a blank canvas at the size you need. Add layers, text, and comic bubbles.';

  @override
  String get onboardCutoutTitle => 'Cut out the background';

  @override
  String get onboardCutoutBody =>
      'Lift your subject off its background with one tap, or erase objects - all on your device, so your photos never leave your phone.';

  @override
  String get onboardExportTitle => 'Export & share';

  @override
  String get onboardExportBody =>
      'Save a transparent PNG, JPG, or WebP at any resolution, then share it anywhere.';

  @override
  String get privacyTitle => 'Privacy & Cookies';

  @override
  String get privacyRowSub => 'On-device editing · how ads work';

  @override
  String get privacyBanner =>
      'Your photos stay on your device. Ads are the one exception - explained below.';

  @override
  String get privacyOnDevice =>
      'Your photos are edited entirely on your device - nothing is uploaded.';

  @override
  String get privacyAiLocal =>
      'AI background & object removal run locally; photos never leave your phone.';

  @override
  String get privacyNoAccounts => 'No accounts, no sign-in, no photo uploads.';

  @override
  String get privacyAds =>
      'The free app shows ads (Google AdMob), which use an advertising ID.';

  @override
  String get privacyConsent =>
      'Where required, a consent prompt (UMP) lets you choose personalised or non-personalised ads.';

  @override
  String get privacyWithdraw =>
      'You can change or withdraw that consent any time - \"Ad privacy choices\" below reopens the form.';

  @override
  String get privacyPro =>
      'The one-time Pro upgrade removes all ads - and the advertising ID with them.';

  @override
  String get fullPrivacyPolicy => 'Full privacy policy';

  @override
  String get questions => 'Questions?';

  @override
  String get openSourceLicenses => 'Open-source licenses';

  @override
  String get licensesRowSub => 'The great work we build on';

  @override
  String get licensesIntro =>
      'Chromis is built on wonderful open-source work. Thank you to everyone who made it.';

  @override
  String get viewFullLicenseTexts => 'View full license texts';

  @override
  String get licenseCategoryFonts => 'Fonts';

  @override
  String get licenseCategoryAi => 'On-device AI';

  @override
  String get licenseCategoryEncoding => 'Media encoding';

  @override
  String get licenseCategoryMonetization => 'Monetization';

  @override
  String get licenseCategoryFramework => 'Framework & packages';

  @override
  String get licenseUseDisplayFont => 'Display / heading typeface';

  @override
  String get licenseUseBodyFont => 'UI / body typeface';

  @override
  String get licenseUseComicFont => 'Comic caption font';

  @override
  String get licenseUseCaptionFont => 'Caption font';

  @override
  String get licenseUseScriptFont => 'Script caption font';

  @override
  String get licenseUseBgRemoval => 'Background removal (Android)';

  @override
  String get licenseUseRuntime => 'Runs the bundled fallback model';

  @override
  String get licenseUseOnDeviceAi => 'On-device object & background removal';

  @override
  String get licenseUseEncoding => 'PNG / JPG / WebP encoding';

  @override
  String get licenseUseAds => 'Banner / rewarded ads + consent';

  @override
  String get licenseUsePurchase => 'One-time Go Pro (remove ads) purchase';

  @override
  String get licenseUseFramework => 'App framework';

  @override
  String get licenseUsePlugins => 'Routing, storage, sharing, image picking';

  @override
  String get licenseUseState => 'State management';

  @override
  String get licenseUseClipboard => 'Paste image from clipboard';

  @override
  String get goPro => 'Go Pro';

  @override
  String get goProRemoveAds => 'Go Pro · remove ads';

  @override
  String get goProRemoveAdsPlain => 'Go Pro - remove ads';

  @override
  String get goProRowSub => 'One-time upgrade - no ads, ever';

  @override
  String get goProHeroTitle => 'Remove ads forever';

  @override
  String get goProHeroBody =>
      'One-time purchase. Every AI feature stays free - no ads, no watch-to-run.';

  @override
  String get goProBenefitNoAds => 'No banner or full-screen ads';

  @override
  String get goProBenefitNoRewarded =>
      'Run AI Cut & object removal without a rewarded ad';

  @override
  String get goProBenefitOneTime => 'One-time payment - no subscription';

  @override
  String get goProBenefitSupports =>
      'Supports private, on-device photo editing';

  @override
  String get goProOwned => 'You\'re Pro - ads are off. Thank you!';

  @override
  String upgradeFor(String price) {
    return 'Upgrade - $price';
  }

  @override
  String get restorePurchase => 'Restore purchase';

  @override
  String get oneTimeUnavailable =>
      'One-time purchase · temporarily unavailable';

  @override
  String get oneTimeRestores => 'One-time purchase · restores on any device';

  @override
  String get oneTimeNoSubscription => 'One-time purchase. No subscription.';

  @override
  String get purchasesUnavailable =>
      'Purchases are temporarily unavailable - please try again later.';

  @override
  String get purchaseStartFailed =>
      'Couldn\'t start the purchase - please try again.';

  @override
  String get purchaseStartFailedOwned =>
      'Couldn\'t start the purchase - if you already bought Pro, tap Restore purchase.';

  @override
  String get checkingPreviousPurchase => 'Checking for a previous purchase…';

  @override
  String get playUnreachable =>
      'Couldn\'t reach Google Play - check your connection and try again.';

  @override
  String get purchaseFailedGeneric => 'The purchase could not be completed';

  @override
  String get removeAdsArrow => 'Remove ads →';

  @override
  String get adsDeclinedExplainer =>
      'You\'ve chosen not to allow ads, so there is no ad to watch - and ads are what keep Chromis free.\n\nAllow ads to carry on for free, or go Pro to use everything with no ads at all.';

  @override
  String get reviewAdConsent => 'Review ad consent';

  @override
  String get adPrivacyChoices => 'Ad privacy choices';

  @override
  String get adPrivacyChoicesSub =>
      'Change the consent you gave for personalised ads';

  @override
  String adSettingsFailed(String error) {
    return 'Couldn\'t open ad settings: $error';
  }

  @override
  String get untitledProject => 'Untitled';

  @override
  String get photoLayerDefault => 'Photo';

  @override
  String get textLayerDefault => 'Text';

  @override
  String get mergedLayerName => 'Merged';

  @override
  String get mergedLayerSuffix => 'merged';

  @override
  String get saveRetrying =>
      'Couldn\'t save - your edits are safe, still trying';

  @override
  String get speed => 'Speed';

  @override
  String get fillingBackground => 'Filling in the background…';

  @override
  String get findingObject => 'Finding the object…';

  @override
  String get mergingLayers => 'Merging layers…';

  @override
  String get removingBackground => 'Removing background…';

  @override
  String get hideToolPanel => 'Hide tool panel';

  @override
  String get showToolPanel => 'Show tool panel';

  @override
  String get cropOpenFailed => 'Couldn\'t open the photo to crop';

  @override
  String get photoCropped => 'Photo cropped';

  @override
  String get editCrop => 'Edit crop';

  @override
  String get cropPhoto => 'Crop photo';

  @override
  String get resetCrop => 'Reset crop';

  @override
  String get crop => 'Crop';

  @override
  String get cancelCrop => 'Cancel crop';

  @override
  String get previewUnavailable => 'Preview unavailable';

  @override
  String get cropToRatio => 'Crop to ratio';

  @override
  String get cropSheetHint => 'Drag a freeform box, or center-crop to a ratio';

  @override
  String get freeformCrop => 'Freeform crop';

  @override
  String get ratiosSection => 'RATIOS';

  @override
  String croppedTo(int width, int height) {
    return 'Cropped to $width×$height';
  }

  @override
  String get scale => 'Scale';

  @override
  String get rotation => 'Rotation';

  @override
  String get brightness => 'Brightness';

  @override
  String get contrast => 'Contrast';

  @override
  String get saturation => 'Saturation';

  @override
  String get hue => 'Hue';

  @override
  String get opacity => 'Opacity';

  @override
  String get size => 'Size';

  @override
  String get color => 'Color';

  @override
  String get off => 'Off';

  @override
  String get adjustEmptyHint =>
      'Select a layer to resize, rotate or adjust it.\nOr tap Add to import a photo.';

  @override
  String get effectsLink => 'Filters, HDR, vignette, shadow…';

  @override
  String get effectsLinkLayer => 'Blend, shadow, outline…';

  @override
  String get textEmptyHint => 'Select a text layer, or add one.';

  @override
  String get addText => 'Add text';

  @override
  String get tapFontToPreview => 'Tap a font to preview';

  @override
  String get typeYourCaption => 'Type your caption…';

  @override
  String get outlineSection => 'OUTLINE';

  @override
  String get cutoutOutlineSection => 'CUTOUT OUTLINE';

  @override
  String get autoColor => 'Auto color';

  @override
  String get thickness => 'Thickness';

  @override
  String get outlineOpacity => 'Outline opacity';

  @override
  String get font => 'Font';

  @override
  String fontAdded(String family) {
    return 'Added font · $family';
  }

  @override
  String get comicBubble => 'Comic bubble';

  @override
  String get bubble => 'Bubble';

  @override
  String get bubbleTextHint => 'Bubble text…';

  @override
  String get fill => 'Fill';

  @override
  String get outline => 'Outline';

  @override
  String get bubbleTailHint =>
      'Drag the dot at the tail tip to aim it - any direction.';

  @override
  String get addABubble => 'Add a bubble';

  @override
  String get addABubbleHint =>
      'Pick a format. The text, colours and tail are all editable afterwards - and so is this.';

  @override
  String get addBubble => 'Add bubble';

  @override
  String bubbleAdded(String format) {
    return '$format bubble added - edit it in the panel';
  }

  @override
  String bubbleTileSemantics(String format, String description) {
    return '$format bubble - $description';
  }

  @override
  String get bubbleSpeech => 'Speech';

  @override
  String get bubbleThought => 'Thought';

  @override
  String get bubbleShout => 'Shout';

  @override
  String get bubbleCaption => 'Caption';

  @override
  String get bubbleWhisper => 'Whisper';

  @override
  String get bubbleSpeechBlurb => 'Rounded, with a tail';

  @override
  String get bubbleThoughtBlurb => 'Cloud with a dot trail';

  @override
  String get bubbleShoutBlurb => 'Spiky star burst';

  @override
  String get bubbleCaptionBlurb => 'Square narration box';

  @override
  String get bubbleWhisperBlurb => 'Dashed line outline';

  @override
  String get notAPhotoGrid => 'This project is not a photo grid.';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get photosSection => 'PHOTOS';

  @override
  String get layoutSection => 'LAYOUT';

  @override
  String get border => 'Border';

  @override
  String get corners => 'Corners';

  @override
  String get effectsEmptyHint =>
      'Select a layer to give it a look.\nFilters, HDR and vignette for photos; shadow, outline and blending for anything.';

  @override
  String get filterSection => 'FILTER';

  @override
  String get strength => 'Strength';

  @override
  String get hdrSection => 'HDR';

  @override
  String get toneAndDetail => 'Tone + detail';

  @override
  String get vignetteSection => 'VIGNETTE';

  @override
  String get amount => 'Amount';

  @override
  String get softness => 'Softness';

  @override
  String get shadowSection => 'SHADOW';

  @override
  String get direction => 'Direction';

  @override
  String get distance => 'Distance';

  @override
  String get blur => 'Blur';

  @override
  String get density => 'Density';

  @override
  String get blendSection => 'BLEND';

  @override
  String pixels(int count) {
    return '$count px';
  }

  @override
  String get working => 'Working…';

  @override
  String get undoRemoval => 'Undo removal';

  @override
  String get removeBackground => 'Remove background';

  @override
  String get removeAnObject => 'Remove an object';

  @override
  String get removeObject => 'Remove object';

  @override
  String get background => 'Background';

  @override
  String get object => 'Object';

  @override
  String get erase => 'Erase';

  @override
  String get restore => 'Restore';

  @override
  String get fillIn => 'Fill in';

  @override
  String get fillExplainer =>
      'Fill rebuilds the background from the rest of the photo.';

  @override
  String get eraseExplainer => 'Erase cuts the object out to transparency.';

  @override
  String get objectRemoveHint =>
      'Tap an unwanted object on the photo to remove it - a stray item, a second subject, clutter. Tapping the main subject is safely ignored; undo brings anything back.';

  @override
  String get cutoutSelectPhoto => 'Select a photo layer to cut out.';

  @override
  String get cutoutHint =>
      'One tap to isolate your subject. We\'ll auto-detect the edges - refine anything by hand in the Erase tool.';

  @override
  String get backgroundRestored => 'Background restored';

  @override
  String get aiModelSection => 'AI MODEL';

  @override
  String get whichAiModel => 'Which AI model?';

  @override
  String get segBuiltinLabel => 'Built-in AI';

  @override
  String get segBuiltinTagline => 'On-device · fast & private';

  @override
  String get segBuiltinBlurb =>
      'Runs on-device for fast, private cut-outs. Great for pets and people with clear edges - nothing leaves your phone.';

  @override
  String get segU2netTagline => 'Open-source · sharper detail';

  @override
  String get segU2netBlurb =>
      'An open-source salient-object model bundled with the app. Works fully offline and is often sharper on fine detail like fur, hair and whiskers - a little slower to run.';

  @override
  String get aiGateTitle => 'Unlock AI tools';

  @override
  String get aiGateMessage =>
      'Watch a short ad to use the AI tools for the rest of this editing session. Go Pro to use them without ads, forever.';

  @override
  String get aiGateWatch => 'Watch & unlock';

  @override
  String get aiGateNotRewarded =>
      'Watch the full ad to use AI, or Go Pro to remove ads';

  @override
  String get objectAiUnavailable =>
      'Object removal AI isn\'t available on this device - use the Erase brush instead';

  @override
  String get bgRemovalUnavailable =>
      'Background removal isn\'t available on this device yet';

  @override
  String get layerGoneCutoutDiscarded =>
      'That layer is gone - the cut-out was discarded';

  @override
  String get backgroundRemoved => 'Background removed';

  @override
  String backgroundRemovedWith(String engine) {
    return 'Background removed · $engine';
  }

  @override
  String get bgRemovalFailed => 'Couldn\'t remove the background - try again';

  @override
  String get selectPhotoToCutOut => 'Select a photo layer to cut out';

  @override
  String get detectingSubject =>
      'Detecting the subject & refining edges · on device';

  @override
  String get edgeFeather => 'Edge feather';

  @override
  String get applyToLayer => 'Apply to layer';

  @override
  String get tapObjectsToErase => 'Tap objects on the photo to erase them';

  @override
  String get tapObjectsToRemove => 'Tap objects to remove';

  @override
  String get tapAnObjectToRemove => 'Tap an object on the photo to remove it';

  @override
  String get chooseAiEngine => 'Choose an AI engine · runs on your device';

  @override
  String get autoRefineEdges => 'Auto-refine edges';

  @override
  String get brushFailed => 'Couldn\'t apply the brush';

  @override
  String get nothingToRemoveThere => 'Nothing to remove there';

  @override
  String get objectRemoved => 'Object removed - undo brings it back';

  @override
  String get objectRemoveFailed => 'Couldn\'t remove that - try again';

  @override
  String get noObjectThere => 'Couldn\'t find an object there';

  @override
  String get thatLooksLikeSubject =>
      'That looks like your subject - use Erase for fine edits';

  @override
  String get fillUnavailable => 'Couldn\'t rebuild that area - erased instead';

  @override
  String get objectFilled => 'Object filled in - undo reverts';

  @override
  String get eraseEmptyHint => 'Select a photo layer to erase, or add a photo.';

  @override
  String get brushOverCanvas => 'Brush over the canvas';

  @override
  String get brushSize => 'Brush size';

  @override
  String get softEdges => 'Soft edges';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get newLayersToAllFrames => 'New layers to all frames';

  @override
  String get onionSkin => 'Onion skin (ghost previous)';

  @override
  String get duplicateFrame => 'Duplicate frame';

  @override
  String get moveLeft => 'Move left';

  @override
  String get moveRight => 'Move right';

  @override
  String get deleteFrame => 'Delete frame';

  @override
  String frameOf(int current, int total) {
    return 'Frame $current / $total';
  }

  @override
  String get mergeDown => 'Merge down';

  @override
  String get flatten => 'Flatten';

  @override
  String get layersEmptyHint =>
      'No layers yet. Tap Add to import a photo or add text.';

  @override
  String get mergedTwoLayers => 'Merged 2 layers';

  @override
  String flattenedLayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Flattened $count layers',
      one: 'Flattened 1 layer',
    );
    return '$_temp0';
  }

  @override
  String get mergeFailed => 'Couldn\'t merge those layers';

  @override
  String get importPhotoFailed => 'Could not import photo';

  @override
  String get noImageInClipboard => 'No image in clipboard';

  @override
  String get pasteFailed => 'Could not paste image';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get choosePhoto => 'Choose photo';

  @override
  String get pasteImage => 'Paste image';

  @override
  String get renameLayer => 'Rename layer';

  @override
  String get canvasSize => 'Canvas size';

  @override
  String get addLayer => 'Add layer';

  @override
  String get aiCut => 'AI Cut';

  @override
  String get seeThePrice => 'See the price';

  @override
  String get notNow => 'Not now';

  @override
  String get oneTimeNoSubscriptionShort => 'One-time purchase, no subscription';

  @override
  String get proBenefitNoAdsTitle => 'No ads, anywhere';

  @override
  String get proBenefitNoAdsBody =>
      'The banner on Home and the full-screen ads both go away for good.';

  @override
  String get proBenefitAiTitle => 'AI without the wait';

  @override
  String get proBenefitAiBody =>
      'Background removal and object erase run straight away - no rewarded ad first.';

  @override
  String get proBenefitExportTitle => 'Export and share freely';

  @override
  String get proBenefitExportBody =>
      'Save or share at any size without watching anything.';

  @override
  String get proBenefitLocalTitle => 'Still on your device';

  @override
  String get proBenefitLocalBody =>
      'Pro changes nothing about your photos: every edit stays local, as it always was.';

  @override
  String get textLayer => 'Text layer';

  @override
  String get bubbleLayer => 'Bubble layer';

  @override
  String get imageLayer => 'Image layer';

  @override
  String get imageLayerCutOut => 'Image layer · cut out';

  @override
  String dragToReorder(String name) {
    return 'Drag to reorder $name';
  }

  @override
  String get hideLayer => 'Hide layer';

  @override
  String get showLayer => 'Show layer';

  @override
  String get duplicateLayer => 'Duplicate layer';

  @override
  String get deleteLayer => 'Delete layer';

  @override
  String deleteLayerNamed(String name) {
    return 'Delete layer $name';
  }

  @override
  String get cutOut => 'Cut out';

  @override
  String get tapToAddPhoto => 'Tap to add a photo';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get export => 'Export';

  @override
  String get customPixels => 'CUSTOM (PIXELS)';

  @override
  String get width => 'Width';

  @override
  String get height => 'Height';

  @override
  String get create => 'Create';

  @override
  String get scaleLayersToFit => 'Scale layers to fit';

  @override
  String get scaleLayersToFitSub =>
      'Resample the whole composition to the new size';

  @override
  String get presetSquare => 'Square';

  @override
  String get presetPortrait => 'Portrait';

  @override
  String get presetStory => 'Story';

  @override
  String get presetLandscape => 'Landscape';

  @override
  String get presetWide => 'Wide';

  @override
  String get presetSmall => 'Small';

  @override
  String layersAutoSaved(String layers) {
    return '$layers · auto-saved';
  }

  @override
  String engineWorking(String engine) {
    return '$engine is working…';
  }

  @override
  String get toolLayers => 'Layers';

  @override
  String get toolAdjust => 'Adjust';

  @override
  String get toolEffects => 'Effects';

  @override
  String get toolText => 'Text';

  @override
  String get toolErase => 'Erase';

  @override
  String get toolErasePanel => 'Manual erase';

  @override
  String get toolCutout => 'Cut out';

  @override
  String get toolCutoutPanel => 'AI Background Removal';

  @override
  String get toolFrames => 'Frames';

  @override
  String get toolFramesPanel => 'Animation frames';

  @override
  String get toolGrid => 'Grid';

  @override
  String get toolGridPanel => 'Photo grid';

  @override
  String get filterOriginal => 'Original';

  @override
  String get filterVivid => 'Vivid';

  @override
  String get filterPunch => 'Punch';

  @override
  String get filterChrome => 'Chrome';

  @override
  String get filterWarm => 'Warm';

  @override
  String get filterCool => 'Cool';

  @override
  String get filterSunset => 'Sunset';

  @override
  String get filterDawn => 'Dawn';

  @override
  String get filterDusk => 'Dusk';

  @override
  String get filterFade => 'Fade';

  @override
  String get filterMatte => 'Matte';

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
  String get blendMultiply => 'Multiply';

  @override
  String get blendScreen => 'Screen';

  @override
  String get blendOverlay => 'Overlay';

  @override
  String get blendDarken => 'Darken';

  @override
  String get blendLighten => 'Lighten';

  @override
  String get blendDodge => 'Dodge';

  @override
  String get blendBurn => 'Burn';

  @override
  String get blendHardLight => 'Hard light';

  @override
  String get blendSoftLight => 'Soft light';

  @override
  String get blendDifference => 'Difference';

  @override
  String get blendExclusion => 'Exclusion';

  @override
  String get blendHue => 'Hue';

  @override
  String get blendSaturation => 'Saturation';

  @override
  String get blendColor => 'Color';

  @override
  String get blendLuminosity => 'Luminosity';

  @override
  String get gridHowManyPhotos => 'HOW MANY PHOTOS?';

  @override
  String get gridLayoutLabel => 'LAYOUT';

  @override
  String get gridSizeLabel => 'SIZE';

  @override
  String get gridSetupHint =>
      'Pick your photos next - you can change the layout, count and border any time.';

  @override
  String photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String gridLayoutNamed(String name) {
    return 'Layout $name';
  }

  @override
  String get gridSideBySide => 'Side by side';

  @override
  String get gridStacked => 'Stacked';

  @override
  String get gridWideLeft => 'Wide left';

  @override
  String get gridTallTop => 'Tall top';

  @override
  String get gridColumns => 'Columns';

  @override
  String get gridRows => 'Rows';

  @override
  String get gridBigLeft => 'Big left';

  @override
  String get gridBigTop => 'Big top';

  @override
  String get gridTwoByTwo => '2 x 2';

  @override
  String get gridTwoOverThree => '2 over 3';

  @override
  String get gridThreeOverTwo => '3 over 2';

  @override
  String get gridTwoLeftThreeRight => '2 left, 3 right';

  @override
  String get exportTitle => 'Export & share';

  @override
  String get formatLabel => 'FORMAT';

  @override
  String get formatPngSub => 'transparent';

  @override
  String get formatJpgSub => 'flattened';

  @override
  String get formatWebpSub => 'smaller';

  @override
  String get resolutionLabel => 'RESOLUTION';

  @override
  String exportOutput(
    int width,
    int height,
    String format,
    String transparent,
  ) {
    return 'Output · $width × $height px · $format$transparent';
  }

  @override
  String get transparentParenthetical => '(transparent)';

  @override
  String get saveToDevice => 'Save to device';

  @override
  String get share => 'Share';

  @override
  String savedTo(String location) {
    return 'Saved · $location';
  }

  @override
  String get storageDenied => 'Allow storage access to save to your gallery';

  @override
  String get saveFailed => 'Couldn\'t save the image';

  @override
  String get exportFailed => 'Export failed - try again';

  @override
  String get shareFailed => 'Share failed - try again';

  @override
  String get exportGateTitle => 'Watch a short ad to export';

  @override
  String get exportGateMessage =>
      'Free exports are supported by a short ad. Go Pro to export without ads, forever.';

  @override
  String get exportGateWatch => 'Watch & export';

  @override
  String get swatchWhite => 'white';

  @override
  String get swatchBlack => 'black';

  @override
  String get swatchPink => 'pink';

  @override
  String get swatchAmber => 'amber';

  @override
  String get swatchGreen => 'green';

  @override
  String get swatchCyan => 'cyan';

  @override
  String get swatchViolet => 'violet';

  @override
  String get swatchRose => 'rose';

  @override
  String get swatchOrange => 'orange';
}
