import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('cs'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('pl'),
  ];

  /// The application name, shown as the OS task title.
  ///
  /// In en, this message translates to:
  /// **'Chromis'**
  String get appTitle;

  /// Tooltip on a screen's back button.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Accessibility label for the Home menu button.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get licenses;

  /// Default hint in the name prompt dialog.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameHint;

  /// No description provided for @cannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get cannotBeUndone;

  /// No description provided for @tryAgainInAMoment.
  ///
  /// In en, this message translates to:
  /// **'Try again in a moment.'**
  String get tryAgainInAMoment;

  /// Screen-reader label for the app's brand mark.
  ///
  /// In en, this message translates to:
  /// **'Chromis logo'**
  String get appLogo;

  /// A reason fragment, lower case on purpose - it is substituted INTO a sentence, e.g. "Couldn't open ad settings: please try again".
  ///
  /// In en, this message translates to:
  /// **'please try again'**
  String get pleaseTryAgain;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your projects'**
  String get homeTitle;

  /// No description provided for @homeTagline.
  ///
  /// In en, this message translates to:
  /// **'Chromis · Photo editor with AI cutout'**
  String get homeTagline;

  /// Section header above the recent-projects grid; upper case by design.
  ///
  /// In en, this message translates to:
  /// **'RECENT'**
  String get homeRecent;

  /// No description provided for @homeJoinDiscord.
  ///
  /// In en, this message translates to:
  /// **'Join our Discord'**
  String get homeJoinDiscord;

  /// No description provided for @homeEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap New project to import a photo.'**
  String get homeEmptyHint;

  /// No description provided for @noProjectsYet.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get noProjectsYet;

  /// No description provided for @newProject.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get newProject;

  /// No description provided for @homeNewProjectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Blank canvas or a photo grid'**
  String get homeNewProjectSubtitle;

  /// No description provided for @homeOpenPhoto.
  ///
  /// In en, this message translates to:
  /// **'Open a photo'**
  String get homeOpenPhoto;

  /// No description provided for @homeOpenPhotoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Canvas takes the photo\'s size'**
  String get homeOpenPhotoSubtitle;

  /// Tap target next to RECENT that opens All projects.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 project} other{{count} projects}}'**
  String projectCount(int count);

  /// Layer count on a saved-project tile.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 layer} other{{count} layers}}'**
  String layerCount(int count);

  /// No description provided for @renameProject.
  ///
  /// In en, this message translates to:
  /// **'Rename project'**
  String get renameProject;

  /// No description provided for @projectNameHint.
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get projectNameHint;

  /// Appended to a duplicated project's name, as in "Sunset copy".
  ///
  /// In en, this message translates to:
  /// **'copy'**
  String get copySuffix;

  /// No description provided for @deleteProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteProjectTitle(String name);

  /// No description provided for @allProjects.
  ///
  /// In en, this message translates to:
  /// **'All projects'**
  String get allProjects;

  /// No description provided for @searchProjects.
  ///
  /// In en, this message translates to:
  /// **'Search your projects'**
  String get searchProjects;

  /// No description provided for @projectsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your projects'**
  String get projectsLoadFailed;

  /// No description provided for @allProjectsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Create one from Home and it will show up here.'**
  String get allProjectsEmptyHint;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noMatches;

  /// No description provided for @noMatchesFor.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches \"{query}\".'**
  String noMatchesFor(String query);

  /// No description provided for @newProjectQuestion.
  ///
  /// In en, this message translates to:
  /// **'What are you making?'**
  String get newProjectQuestion;

  /// No description provided for @blankCanvas.
  ///
  /// In en, this message translates to:
  /// **'Blank canvas'**
  String get blankCanvas;

  /// No description provided for @blankCanvasSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One canvas, add photos and layers freely'**
  String get blankCanvasSubtitle;

  /// No description provided for @photoGrid.
  ///
  /// In en, this message translates to:
  /// **'Photo grid'**
  String get photoGrid;

  /// No description provided for @photoGridSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A collage of 2 to 5 photos in a layout'**
  String get photoGridSubtitle;

  /// No description provided for @drawerHome.
  ///
  /// In en, this message translates to:
  /// **'Home & projects'**
  String get drawerHome;

  /// Drawer header subtitle. The version is interpolated from AboutInfo, never written out.
  ///
  /// In en, this message translates to:
  /// **'Photo editor · v{version}'**
  String drawerSubtitle(String version);

  /// Settings section header for the light/dark theme choice.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Appearance option: follow the device.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get appearanceSystem;

  /// Sub-label under the "System default" appearance option.
  ///
  /// In en, this message translates to:
  /// **'Follow your phone’s light or dark setting'**
  String get appearanceSystemSub;

  /// Appearance option: the light theme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceLight;

  /// Sub-label under the "Light" appearance option.
  ///
  /// In en, this message translates to:
  /// **'Easier to read outdoors and on LCD screens'**
  String get appearanceLightSub;

  /// Appearance option: the dark theme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceDark;

  /// Sub-label under the "Dark" appearance option.
  ///
  /// In en, this message translates to:
  /// **'True black, which OLED screens draw as no light at all'**
  String get appearanceDarkSub;

  /// Explanatory note under the appearance picker.
  ///
  /// In en, this message translates to:
  /// **'Chromis follows your phone unless you pick one here. Your choice is remembered.'**
  String get appearanceNote;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageSystemSub.
  ///
  /// In en, this message translates to:
  /// **'Follow the language your phone is set to'**
  String get languageSystemSub;

  /// No description provided for @languageNote.
  ///
  /// In en, this message translates to:
  /// **'Chromis is in English unless your phone is set to a language it has been translated into. Your choice here is remembered.'**
  String get languageNote;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @onboardStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Start from a photo'**
  String get onboardStartTitle;

  /// No description provided for @onboardStartBody.
  ///
  /// In en, this message translates to:
  /// **'Open any photo, or a blank canvas at the size you need. Add layers, text, and comic bubbles.'**
  String get onboardStartBody;

  /// No description provided for @onboardCutoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Cut out the background'**
  String get onboardCutoutTitle;

  /// No description provided for @onboardCutoutBody.
  ///
  /// In en, this message translates to:
  /// **'Lift your subject off its background with one tap, or erase objects - all on your device, so your photos never leave your phone.'**
  String get onboardCutoutBody;

  /// No description provided for @onboardExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export & share'**
  String get onboardExportTitle;

  /// No description provided for @onboardExportBody.
  ///
  /// In en, this message translates to:
  /// **'Save a transparent PNG, JPG, or WebP at any resolution, then share it anywhere.'**
  String get onboardExportBody;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Cookies'**
  String get privacyTitle;

  /// No description provided for @privacyRowSub.
  ///
  /// In en, this message translates to:
  /// **'On-device editing · how ads work'**
  String get privacyRowSub;

  /// No description provided for @privacyBanner.
  ///
  /// In en, this message translates to:
  /// **'Your photos stay on your device. Ads are the one exception - explained below.'**
  String get privacyBanner;

  /// No description provided for @privacyOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Your photos are edited entirely on your device - nothing is uploaded.'**
  String get privacyOnDevice;

  /// No description provided for @privacyAiLocal.
  ///
  /// In en, this message translates to:
  /// **'AI background & object removal run locally; photos never leave your phone.'**
  String get privacyAiLocal;

  /// No description provided for @privacyNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'No accounts, no sign-in, no photo uploads.'**
  String get privacyNoAccounts;

  /// No description provided for @privacyAds.
  ///
  /// In en, this message translates to:
  /// **'The free app shows ads (Google AdMob), which use an advertising ID.'**
  String get privacyAds;

  /// No description provided for @privacyConsent.
  ///
  /// In en, this message translates to:
  /// **'Where required, a consent prompt (UMP) lets you choose personalised or non-personalised ads.'**
  String get privacyConsent;

  /// No description provided for @privacyWithdraw.
  ///
  /// In en, this message translates to:
  /// **'You can change or withdraw that consent any time - \"Ad privacy choices\" below reopens the form.'**
  String get privacyWithdraw;

  /// No description provided for @privacyPro.
  ///
  /// In en, this message translates to:
  /// **'The one-time Pro upgrade removes all ads - and the advertising ID with them.'**
  String get privacyPro;

  /// No description provided for @fullPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Full privacy policy'**
  String get fullPrivacyPolicy;

  /// No description provided for @questions.
  ///
  /// In en, this message translates to:
  /// **'Questions?'**
  String get questions;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get openSourceLicenses;

  /// No description provided for @licensesRowSub.
  ///
  /// In en, this message translates to:
  /// **'The great work we build on'**
  String get licensesRowSub;

  /// No description provided for @licensesIntro.
  ///
  /// In en, this message translates to:
  /// **'Chromis is built on wonderful open-source work. Thank you to everyone who made it.'**
  String get licensesIntro;

  /// No description provided for @viewFullLicenseTexts.
  ///
  /// In en, this message translates to:
  /// **'View full license texts'**
  String get viewFullLicenseTexts;

  /// No description provided for @licenseCategoryFonts.
  ///
  /// In en, this message translates to:
  /// **'Fonts'**
  String get licenseCategoryFonts;

  /// No description provided for @licenseCategoryAi.
  ///
  /// In en, this message translates to:
  /// **'On-device AI'**
  String get licenseCategoryAi;

  /// No description provided for @licenseCategoryEncoding.
  ///
  /// In en, this message translates to:
  /// **'Media encoding'**
  String get licenseCategoryEncoding;

  /// No description provided for @licenseCategoryMonetization.
  ///
  /// In en, this message translates to:
  /// **'Monetization'**
  String get licenseCategoryMonetization;

  /// No description provided for @licenseCategoryFramework.
  ///
  /// In en, this message translates to:
  /// **'Framework & packages'**
  String get licenseCategoryFramework;

  /// No description provided for @licenseUseDisplayFont.
  ///
  /// In en, this message translates to:
  /// **'Display / heading typeface'**
  String get licenseUseDisplayFont;

  /// No description provided for @licenseUseBodyFont.
  ///
  /// In en, this message translates to:
  /// **'UI / body typeface'**
  String get licenseUseBodyFont;

  /// No description provided for @licenseUseComicFont.
  ///
  /// In en, this message translates to:
  /// **'Comic caption font'**
  String get licenseUseComicFont;

  /// No description provided for @licenseUseCaptionFont.
  ///
  /// In en, this message translates to:
  /// **'Caption font'**
  String get licenseUseCaptionFont;

  /// No description provided for @licenseUseScriptFont.
  ///
  /// In en, this message translates to:
  /// **'Script caption font'**
  String get licenseUseScriptFont;

  /// No description provided for @licenseUseBgRemoval.
  ///
  /// In en, this message translates to:
  /// **'Background removal (Android)'**
  String get licenseUseBgRemoval;

  /// No description provided for @licenseUseRuntime.
  ///
  /// In en, this message translates to:
  /// **'Runs the bundled fallback model'**
  String get licenseUseRuntime;

  /// No description provided for @licenseUseOnDeviceAi.
  ///
  /// In en, this message translates to:
  /// **'On-device object & background removal'**
  String get licenseUseOnDeviceAi;

  /// No description provided for @licenseUseEncoding.
  ///
  /// In en, this message translates to:
  /// **'PNG / JPG / WebP encoding'**
  String get licenseUseEncoding;

  /// No description provided for @licenseUseAds.
  ///
  /// In en, this message translates to:
  /// **'Banner / rewarded ads + consent'**
  String get licenseUseAds;

  /// No description provided for @licenseUsePurchase.
  ///
  /// In en, this message translates to:
  /// **'One-time Go Pro (remove ads) purchase'**
  String get licenseUsePurchase;

  /// No description provided for @licenseUseFramework.
  ///
  /// In en, this message translates to:
  /// **'App framework'**
  String get licenseUseFramework;

  /// No description provided for @licenseUsePlugins.
  ///
  /// In en, this message translates to:
  /// **'Routing, storage, sharing, image picking'**
  String get licenseUsePlugins;

  /// No description provided for @licenseUseState.
  ///
  /// In en, this message translates to:
  /// **'State management'**
  String get licenseUseState;

  /// No description provided for @licenseUseClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste image from clipboard'**
  String get licenseUseClipboard;

  /// No description provided for @goPro.
  ///
  /// In en, this message translates to:
  /// **'Go Pro'**
  String get goPro;

  /// No description provided for @goProRemoveAds.
  ///
  /// In en, this message translates to:
  /// **'Go Pro · remove ads'**
  String get goProRemoveAds;

  /// No description provided for @goProRemoveAdsPlain.
  ///
  /// In en, this message translates to:
  /// **'Go Pro - remove ads'**
  String get goProRemoveAdsPlain;

  /// No description provided for @goProRowSub.
  ///
  /// In en, this message translates to:
  /// **'One-time upgrade - no ads, ever'**
  String get goProRowSub;

  /// No description provided for @goProHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove ads forever'**
  String get goProHeroTitle;

  /// No description provided for @goProHeroBody.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase. Every AI feature stays free - no ads, no watch-to-run.'**
  String get goProHeroBody;

  /// No description provided for @goProBenefitNoAds.
  ///
  /// In en, this message translates to:
  /// **'No banner or full-screen ads'**
  String get goProBenefitNoAds;

  /// No description provided for @goProBenefitNoRewarded.
  ///
  /// In en, this message translates to:
  /// **'Run AI Cut & object removal without a rewarded ad'**
  String get goProBenefitNoRewarded;

  /// No description provided for @goProBenefitOneTime.
  ///
  /// In en, this message translates to:
  /// **'One-time payment - no subscription'**
  String get goProBenefitOneTime;

  /// No description provided for @goProBenefitSupports.
  ///
  /// In en, this message translates to:
  /// **'Supports private, on-device photo editing'**
  String get goProBenefitSupports;

  /// No description provided for @goProOwned.
  ///
  /// In en, this message translates to:
  /// **'You\'re Pro - ads are off. Thank you!'**
  String get goProOwned;

  /// Buy button; the price comes localized from the store.
  ///
  /// In en, this message translates to:
  /// **'Upgrade - {price}'**
  String upgradeFor(String price);

  /// No description provided for @restorePurchase.
  ///
  /// In en, this message translates to:
  /// **'Restore purchase'**
  String get restorePurchase;

  /// No description provided for @oneTimeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase · temporarily unavailable'**
  String get oneTimeUnavailable;

  /// No description provided for @oneTimeRestores.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase · restores on any device'**
  String get oneTimeRestores;

  /// No description provided for @oneTimeNoSubscription.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase. No subscription.'**
  String get oneTimeNoSubscription;

  /// No description provided for @purchasesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Purchases are temporarily unavailable - please try again later.'**
  String get purchasesUnavailable;

  /// No description provided for @purchaseStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the purchase - please try again.'**
  String get purchaseStartFailed;

  /// No description provided for @purchaseStartFailedOwned.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the purchase - if you already bought Pro, tap Restore purchase.'**
  String get purchaseStartFailedOwned;

  /// No description provided for @checkingPreviousPurchase.
  ///
  /// In en, this message translates to:
  /// **'Checking for a previous purchase…'**
  String get checkingPreviousPurchase;

  /// No description provided for @playUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach Google Play - check your connection and try again.'**
  String get playUnreachable;

  /// No description provided for @purchaseFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'The purchase could not be completed'**
  String get purchaseFailedGeneric;

  /// No description provided for @removeAdsArrow.
  ///
  /// In en, this message translates to:
  /// **'Remove ads →'**
  String get removeAdsArrow;

  /// No description provided for @adsDeclinedExplainer.
  ///
  /// In en, this message translates to:
  /// **'You\'ve chosen not to allow ads, so there is no ad to watch - and ads are what keep Chromis free.\n\nAllow ads to carry on for free, or go Pro to use everything with no ads at all.'**
  String get adsDeclinedExplainer;

  /// No description provided for @reviewAdConsent.
  ///
  /// In en, this message translates to:
  /// **'Review ad consent'**
  String get reviewAdConsent;

  /// No description provided for @adPrivacyChoices.
  ///
  /// In en, this message translates to:
  /// **'Ad privacy choices'**
  String get adPrivacyChoices;

  /// No description provided for @adPrivacyChoicesSub.
  ///
  /// In en, this message translates to:
  /// **'Change the consent you gave for personalised ads'**
  String get adPrivacyChoicesSub;

  /// No description provided for @adSettingsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open ad settings: {error}'**
  String adSettingsFailed(String error);

  /// Default name of a new project.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitledProject;

  /// Default name of an imported photo layer; numbered from the second on ("Photo 2").
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photoLayerDefault;

  /// Default content and name of a new text layer.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get textLayerDefault;

  /// Name of a merged layer when there was nothing to take a name from.
  ///
  /// In en, this message translates to:
  /// **'Merged'**
  String get mergedLayerName;

  /// Parenthesised suffix on a merged layer's name, as in "Photo (merged)".
  ///
  /// In en, this message translates to:
  /// **'merged'**
  String get mergedLayerSuffix;

  /// No description provided for @saveRetrying.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save - your edits are safe, still trying'**
  String get saveRetrying;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @fillingBackground.
  ///
  /// In en, this message translates to:
  /// **'Filling in the background…'**
  String get fillingBackground;

  /// No description provided for @findingObject.
  ///
  /// In en, this message translates to:
  /// **'Finding the object…'**
  String get findingObject;

  /// No description provided for @mergingLayers.
  ///
  /// In en, this message translates to:
  /// **'Merging layers…'**
  String get mergingLayers;

  /// No description provided for @removingBackground.
  ///
  /// In en, this message translates to:
  /// **'Removing background…'**
  String get removingBackground;

  /// No description provided for @hideToolPanel.
  ///
  /// In en, this message translates to:
  /// **'Hide tool panel'**
  String get hideToolPanel;

  /// No description provided for @showToolPanel.
  ///
  /// In en, this message translates to:
  /// **'Show tool panel'**
  String get showToolPanel;

  /// No description provided for @cropOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the photo to crop'**
  String get cropOpenFailed;

  /// No description provided for @photoCropped.
  ///
  /// In en, this message translates to:
  /// **'Photo cropped'**
  String get photoCropped;

  /// No description provided for @editCrop.
  ///
  /// In en, this message translates to:
  /// **'Edit crop'**
  String get editCrop;

  /// No description provided for @cropPhoto.
  ///
  /// In en, this message translates to:
  /// **'Crop photo'**
  String get cropPhoto;

  /// No description provided for @resetCrop.
  ///
  /// In en, this message translates to:
  /// **'Reset crop'**
  String get resetCrop;

  /// No description provided for @crop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get crop;

  /// No description provided for @cancelCrop.
  ///
  /// In en, this message translates to:
  /// **'Cancel crop'**
  String get cancelCrop;

  /// No description provided for @previewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preview unavailable'**
  String get previewUnavailable;

  /// No description provided for @cropToRatio.
  ///
  /// In en, this message translates to:
  /// **'Crop to ratio'**
  String get cropToRatio;

  /// No description provided for @cropSheetHint.
  ///
  /// In en, this message translates to:
  /// **'Drag a freeform box, or center-crop to a ratio'**
  String get cropSheetHint;

  /// No description provided for @freeformCrop.
  ///
  /// In en, this message translates to:
  /// **'Freeform crop'**
  String get freeformCrop;

  /// Section label; upper case by design.
  ///
  /// In en, this message translates to:
  /// **'RATIOS'**
  String get ratiosSection;

  /// No description provided for @croppedTo.
  ///
  /// In en, this message translates to:
  /// **'Cropped to {width}×{height}'**
  String croppedTo(int width, int height);

  /// Adjust panel slider: the selected layer's size, shown as a percentage.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get scale;

  /// Adjust panel slider: the selected layer's angle, in degrees.
  ///
  /// In en, this message translates to:
  /// **'Rotation'**
  String get rotation;

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// No description provided for @contrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get contrast;

  /// No description provided for @saturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get saturation;

  /// No description provided for @hue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get hue;

  /// No description provided for @opacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get opacity;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @adjustEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Select a layer to resize, rotate or adjust it.\nOr tap Add to import a photo.'**
  String get adjustEmptyHint;

  /// No description provided for @effectsLink.
  ///
  /// In en, this message translates to:
  /// **'Filters, HDR, vignette, shadow…'**
  String get effectsLink;

  /// The same link as effectsLink, from a text or bubble layer - which has no filters, HDR or vignette.
  ///
  /// In en, this message translates to:
  /// **'Blend, shadow, outline…'**
  String get effectsLinkLayer;

  /// No description provided for @textEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Select a text layer, or add one.'**
  String get textEmptyHint;

  /// No description provided for @addText.
  ///
  /// In en, this message translates to:
  /// **'Add text'**
  String get addText;

  /// No description provided for @tapFontToPreview.
  ///
  /// In en, this message translates to:
  /// **'Tap a font to preview'**
  String get tapFontToPreview;

  /// No description provided for @typeYourCaption.
  ///
  /// In en, this message translates to:
  /// **'Type your caption…'**
  String get typeYourCaption;

  /// Section label; upper case by design.
  ///
  /// In en, this message translates to:
  /// **'OUTLINE'**
  String get outlineSection;

  /// Section label; upper case by design.
  ///
  /// In en, this message translates to:
  /// **'CUTOUT OUTLINE'**
  String get cutoutOutlineSection;

  /// No description provided for @autoColor.
  ///
  /// In en, this message translates to:
  /// **'Auto color'**
  String get autoColor;

  /// No description provided for @thickness.
  ///
  /// In en, this message translates to:
  /// **'Thickness'**
  String get thickness;

  /// No description provided for @outlineOpacity.
  ///
  /// In en, this message translates to:
  /// **'Outline opacity'**
  String get outlineOpacity;

  /// No description provided for @font.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get font;

  /// No description provided for @fontAdded.
  ///
  /// In en, this message translates to:
  /// **'Added font · {family}'**
  String fontAdded(String family);

  /// No description provided for @comicBubble.
  ///
  /// In en, this message translates to:
  /// **'Comic bubble'**
  String get comicBubble;

  /// No description provided for @bubble.
  ///
  /// In en, this message translates to:
  /// **'Bubble'**
  String get bubble;

  /// No description provided for @bubbleTextHint.
  ///
  /// In en, this message translates to:
  /// **'Bubble text…'**
  String get bubbleTextHint;

  /// No description provided for @fill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get fill;

  /// No description provided for @outline.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get outline;

  /// No description provided for @bubbleTailHint.
  ///
  /// In en, this message translates to:
  /// **'Drag the dot at the tail tip to aim it - any direction.'**
  String get bubbleTailHint;

  /// No description provided for @addABubble.
  ///
  /// In en, this message translates to:
  /// **'Add a bubble'**
  String get addABubble;

  /// No description provided for @addABubbleHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a format. The text, colours and tail are all editable afterwards - and so is this.'**
  String get addABubbleHint;

  /// No description provided for @addBubble.
  ///
  /// In en, this message translates to:
  /// **'Add bubble'**
  String get addBubble;

  /// No description provided for @bubbleAdded.
  ///
  /// In en, this message translates to:
  /// **'{format} bubble added - edit it in the panel'**
  String bubbleAdded(String format);

  /// Screen-reader label for a bubble-format tile.
  ///
  /// In en, this message translates to:
  /// **'{format} bubble - {description}'**
  String bubbleTileSemantics(String format, String description);

  /// No description provided for @bubbleSpeech.
  ///
  /// In en, this message translates to:
  /// **'Speech'**
  String get bubbleSpeech;

  /// No description provided for @bubbleThought.
  ///
  /// In en, this message translates to:
  /// **'Thought'**
  String get bubbleThought;

  /// No description provided for @bubbleShout.
  ///
  /// In en, this message translates to:
  /// **'Shout'**
  String get bubbleShout;

  /// No description provided for @bubbleCaption.
  ///
  /// In en, this message translates to:
  /// **'Caption'**
  String get bubbleCaption;

  /// No description provided for @bubbleWhisper.
  ///
  /// In en, this message translates to:
  /// **'Whisper'**
  String get bubbleWhisper;

  /// No description provided for @bubbleSpeechBlurb.
  ///
  /// In en, this message translates to:
  /// **'Rounded, with a tail'**
  String get bubbleSpeechBlurb;

  /// No description provided for @bubbleThoughtBlurb.
  ///
  /// In en, this message translates to:
  /// **'Cloud with a dot trail'**
  String get bubbleThoughtBlurb;

  /// No description provided for @bubbleShoutBlurb.
  ///
  /// In en, this message translates to:
  /// **'Spiky star burst'**
  String get bubbleShoutBlurb;

  /// No description provided for @bubbleCaptionBlurb.
  ///
  /// In en, this message translates to:
  /// **'Square narration box'**
  String get bubbleCaptionBlurb;

  /// No description provided for @bubbleWhisperBlurb.
  ///
  /// In en, this message translates to:
  /// **'Dashed line outline'**
  String get bubbleWhisperBlurb;

  /// No description provided for @notAPhotoGrid.
  ///
  /// In en, this message translates to:
  /// **'This project is not a photo grid.'**
  String get notAPhotoGrid;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// Section label; upper case by design.
  ///
  /// In en, this message translates to:
  /// **'PHOTOS'**
  String get photosSection;

  /// Section label; upper case by design.
  ///
  /// In en, this message translates to:
  /// **'LAYOUT'**
  String get layoutSection;

  /// No description provided for @border.
  ///
  /// In en, this message translates to:
  /// **'Border'**
  String get border;

  /// No description provided for @corners.
  ///
  /// In en, this message translates to:
  /// **'Corners'**
  String get corners;

  /// No description provided for @effectsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Select a layer to give it a look.\nFilters, HDR and vignette for photos; shadow, outline and blending for anything.'**
  String get effectsEmptyHint;

  /// Section label; upper case by design.
  ///
  /// In en, this message translates to:
  /// **'FILTER'**
  String get filterSection;

  /// No description provided for @strength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get strength;

  /// Section label; upper case by design.
  ///
  /// In en, this message translates to:
  /// **'HDR'**
  String get hdrSection;

  /// No description provided for @toneAndDetail.
  ///
  /// In en, this message translates to:
  /// **'Tone + detail'**
  String get toneAndDetail;

  /// Section label; upper case by design.
  ///
  /// In en, this message translates to:
  /// **'VIGNETTE'**
  String get vignetteSection;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @softness.
  ///
  /// In en, this message translates to:
  /// **'Softness'**
  String get softness;

  /// Section label; upper case by design.
  ///
  /// In en, this message translates to:
  /// **'SHADOW'**
  String get shadowSection;

  /// No description provided for @direction.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get direction;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @blur.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get blur;

  /// No description provided for @density.
  ///
  /// In en, this message translates to:
  /// **'Density'**
  String get density;

  /// Section label; upper case by design.
  ///
  /// In en, this message translates to:
  /// **'BLEND'**
  String get blendSection;

  /// No description provided for @pixels.
  ///
  /// In en, this message translates to:
  /// **'{count} px'**
  String pixels(int count);

  /// No description provided for @working.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get working;

  /// No description provided for @undoRemoval.
  ///
  /// In en, this message translates to:
  /// **'Undo removal'**
  String get undoRemoval;

  /// No description provided for @removeBackground.
  ///
  /// In en, this message translates to:
  /// **'Remove background'**
  String get removeBackground;

  /// No description provided for @removeAnObject.
  ///
  /// In en, this message translates to:
  /// **'Remove an object'**
  String get removeAnObject;

  /// No description provided for @removeObject.
  ///
  /// In en, this message translates to:
  /// **'Remove object'**
  String get removeObject;

  /// No description provided for @background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get background;

  /// No description provided for @object.
  ///
  /// In en, this message translates to:
  /// **'Object'**
  String get object;

  /// No description provided for @erase.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get erase;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @fillIn.
  ///
  /// In en, this message translates to:
  /// **'Fill in'**
  String get fillIn;

  /// No description provided for @fillExplainer.
  ///
  /// In en, this message translates to:
  /// **'Fill rebuilds the background from the rest of the photo.'**
  String get fillExplainer;

  /// No description provided for @eraseExplainer.
  ///
  /// In en, this message translates to:
  /// **'Erase cuts the object out to transparency.'**
  String get eraseExplainer;

  /// No description provided for @objectRemoveHint.
  ///
  /// In en, this message translates to:
  /// **'Tap an unwanted object on the photo to remove it - a stray item, a second subject, clutter. Tapping the main subject is safely ignored; undo brings anything back.'**
  String get objectRemoveHint;

  /// No description provided for @cutoutSelectPhoto.
  ///
  /// In en, this message translates to:
  /// **'Select a photo layer to cut out.'**
  String get cutoutSelectPhoto;

  /// No description provided for @cutoutHint.
  ///
  /// In en, this message translates to:
  /// **'One tap to isolate your subject. We\'ll auto-detect the edges - refine anything by hand in the Erase tool.'**
  String get cutoutHint;

  /// No description provided for @backgroundRestored.
  ///
  /// In en, this message translates to:
  /// **'Background restored'**
  String get backgroundRestored;

  /// Section label; upper case by design.
  ///
  /// In en, this message translates to:
  /// **'AI MODEL'**
  String get aiModelSection;

  /// No description provided for @whichAiModel.
  ///
  /// In en, this message translates to:
  /// **'Which AI model?'**
  String get whichAiModel;

  /// No description provided for @segBuiltinLabel.
  ///
  /// In en, this message translates to:
  /// **'Built-in AI'**
  String get segBuiltinLabel;

  /// No description provided for @segBuiltinTagline.
  ///
  /// In en, this message translates to:
  /// **'On-device · fast & private'**
  String get segBuiltinTagline;

  /// No description provided for @segBuiltinBlurb.
  ///
  /// In en, this message translates to:
  /// **'Runs on-device for fast, private cut-outs. Great for pets and people with clear edges - nothing leaves your phone.'**
  String get segBuiltinBlurb;

  /// No description provided for @segU2netTagline.
  ///
  /// In en, this message translates to:
  /// **'Open-source · sharper detail'**
  String get segU2netTagline;

  /// No description provided for @segU2netBlurb.
  ///
  /// In en, this message translates to:
  /// **'An open-source salient-object model bundled with the app. Works fully offline and is often sharper on fine detail like fur, hair and whiskers - a little slower to run.'**
  String get segU2netBlurb;

  /// No description provided for @aiGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock AI tools'**
  String get aiGateTitle;

  /// No description provided for @aiGateMessage.
  ///
  /// In en, this message translates to:
  /// **'Watch a short ad to use the AI tools for the rest of this editing session. Go Pro to use them without ads, forever.'**
  String get aiGateMessage;

  /// No description provided for @aiGateWatch.
  ///
  /// In en, this message translates to:
  /// **'Watch & unlock'**
  String get aiGateWatch;

  /// No description provided for @aiGateNotRewarded.
  ///
  /// In en, this message translates to:
  /// **'Watch the full ad to use AI, or Go Pro to remove ads'**
  String get aiGateNotRewarded;

  /// No description provided for @objectAiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Object removal AI isn\'t available on this device - use the Erase brush instead'**
  String get objectAiUnavailable;

  /// No description provided for @bgRemovalUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Background removal isn\'t available on this device yet'**
  String get bgRemovalUnavailable;

  /// No description provided for @layerGoneCutoutDiscarded.
  ///
  /// In en, this message translates to:
  /// **'That layer is gone - the cut-out was discarded'**
  String get layerGoneCutoutDiscarded;

  /// No description provided for @backgroundRemoved.
  ///
  /// In en, this message translates to:
  /// **'Background removed'**
  String get backgroundRemoved;

  /// No description provided for @backgroundRemovedWith.
  ///
  /// In en, this message translates to:
  /// **'Background removed · {engine}'**
  String backgroundRemovedWith(String engine);

  /// No description provided for @bgRemovalFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove the background - try again'**
  String get bgRemovalFailed;

  /// No description provided for @selectPhotoToCutOut.
  ///
  /// In en, this message translates to:
  /// **'Select a photo layer to cut out'**
  String get selectPhotoToCutOut;

  /// No description provided for @detectingSubject.
  ///
  /// In en, this message translates to:
  /// **'Detecting the subject & refining edges · on device'**
  String get detectingSubject;

  /// No description provided for @edgeFeather.
  ///
  /// In en, this message translates to:
  /// **'Edge feather'**
  String get edgeFeather;

  /// No description provided for @applyToLayer.
  ///
  /// In en, this message translates to:
  /// **'Apply to layer'**
  String get applyToLayer;

  /// No description provided for @tapObjectsToErase.
  ///
  /// In en, this message translates to:
  /// **'Tap objects on the photo to erase them'**
  String get tapObjectsToErase;

  /// No description provided for @tapObjectsToRemove.
  ///
  /// In en, this message translates to:
  /// **'Tap objects to remove'**
  String get tapObjectsToRemove;

  /// No description provided for @tapAnObjectToRemove.
  ///
  /// In en, this message translates to:
  /// **'Tap an object on the photo to remove it'**
  String get tapAnObjectToRemove;

  /// No description provided for @chooseAiEngine.
  ///
  /// In en, this message translates to:
  /// **'Choose an AI engine · runs on your device'**
  String get chooseAiEngine;

  /// No description provided for @autoRefineEdges.
  ///
  /// In en, this message translates to:
  /// **'Auto-refine edges'**
  String get autoRefineEdges;

  /// No description provided for @brushFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t apply the brush'**
  String get brushFailed;

  /// No description provided for @nothingToRemoveThere.
  ///
  /// In en, this message translates to:
  /// **'Nothing to remove there'**
  String get nothingToRemoveThere;

  /// No description provided for @objectRemoved.
  ///
  /// In en, this message translates to:
  /// **'Object removed - undo brings it back'**
  String get objectRemoved;

  /// No description provided for @objectRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove that - try again'**
  String get objectRemoveFailed;

  /// No description provided for @noObjectThere.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find an object there'**
  String get noObjectThere;

  /// No description provided for @thatLooksLikeSubject.
  ///
  /// In en, this message translates to:
  /// **'That looks like your subject - use Erase for fine edits'**
  String get thatLooksLikeSubject;

  /// No description provided for @fillUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t rebuild that area - erased instead'**
  String get fillUnavailable;

  /// No description provided for @objectFilled.
  ///
  /// In en, this message translates to:
  /// **'Object filled in - undo reverts'**
  String get objectFilled;

  /// No description provided for @eraseEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Select a photo layer to erase, or add a photo.'**
  String get eraseEmptyHint;

  /// No description provided for @brushOverCanvas.
  ///
  /// In en, this message translates to:
  /// **'Brush over the canvas'**
  String get brushOverCanvas;

  /// No description provided for @brushSize.
  ///
  /// In en, this message translates to:
  /// **'Brush size'**
  String get brushSize;

  /// No description provided for @softEdges.
  ///
  /// In en, this message translates to:
  /// **'Soft edges'**
  String get softEdges;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @newLayersToAllFrames.
  ///
  /// In en, this message translates to:
  /// **'New layers to all frames'**
  String get newLayersToAllFrames;

  /// No description provided for @onionSkin.
  ///
  /// In en, this message translates to:
  /// **'Onion skin (ghost previous)'**
  String get onionSkin;

  /// No description provided for @duplicateFrame.
  ///
  /// In en, this message translates to:
  /// **'Duplicate frame'**
  String get duplicateFrame;

  /// No description provided for @moveLeft.
  ///
  /// In en, this message translates to:
  /// **'Move left'**
  String get moveLeft;

  /// No description provided for @moveRight.
  ///
  /// In en, this message translates to:
  /// **'Move right'**
  String get moveRight;

  /// No description provided for @deleteFrame.
  ///
  /// In en, this message translates to:
  /// **'Delete frame'**
  String get deleteFrame;

  /// No description provided for @frameOf.
  ///
  /// In en, this message translates to:
  /// **'Frame {current} / {total}'**
  String frameOf(int current, int total);

  /// No description provided for @mergeDown.
  ///
  /// In en, this message translates to:
  /// **'Merge down'**
  String get mergeDown;

  /// No description provided for @flatten.
  ///
  /// In en, this message translates to:
  /// **'Flatten'**
  String get flatten;

  /// No description provided for @layersEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'No layers yet. Tap Add to import a photo or add text.'**
  String get layersEmptyHint;

  /// No description provided for @mergedTwoLayers.
  ///
  /// In en, this message translates to:
  /// **'Merged 2 layers'**
  String get mergedTwoLayers;

  /// No description provided for @flattenedLayers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Flattened 1 layer} other{Flattened {count} layers}}'**
  String flattenedLayers(int count);

  /// No description provided for @mergeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t merge those layers'**
  String get mergeFailed;

  /// No description provided for @importPhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import photo'**
  String get importPhotoFailed;

  /// No description provided for @noImageInClipboard.
  ///
  /// In en, this message translates to:
  /// **'No image in clipboard'**
  String get noImageInClipboard;

  /// No description provided for @pasteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not paste image'**
  String get pasteFailed;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get choosePhoto;

  /// No description provided for @pasteImage.
  ///
  /// In en, this message translates to:
  /// **'Paste image'**
  String get pasteImage;

  /// No description provided for @renameLayer.
  ///
  /// In en, this message translates to:
  /// **'Rename layer'**
  String get renameLayer;

  /// No description provided for @canvasSize.
  ///
  /// In en, this message translates to:
  /// **'Canvas size'**
  String get canvasSize;

  /// No description provided for @addLayer.
  ///
  /// In en, this message translates to:
  /// **'Add layer'**
  String get addLayer;

  /// No description provided for @aiCut.
  ///
  /// In en, this message translates to:
  /// **'AI Cut'**
  String get aiCut;

  /// No description provided for @seeThePrice.
  ///
  /// In en, this message translates to:
  /// **'See the price'**
  String get seeThePrice;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @oneTimeNoSubscriptionShort.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase, no subscription'**
  String get oneTimeNoSubscriptionShort;

  /// No description provided for @proBenefitNoAdsTitle.
  ///
  /// In en, this message translates to:
  /// **'No ads, anywhere'**
  String get proBenefitNoAdsTitle;

  /// No description provided for @proBenefitNoAdsBody.
  ///
  /// In en, this message translates to:
  /// **'The banner on Home and the full-screen ads both go away for good.'**
  String get proBenefitNoAdsBody;

  /// No description provided for @proBenefitAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI without the wait'**
  String get proBenefitAiTitle;

  /// No description provided for @proBenefitAiBody.
  ///
  /// In en, this message translates to:
  /// **'Background removal and object erase run straight away - no rewarded ad first.'**
  String get proBenefitAiBody;

  /// No description provided for @proBenefitExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export and share freely'**
  String get proBenefitExportTitle;

  /// No description provided for @proBenefitExportBody.
  ///
  /// In en, this message translates to:
  /// **'Save or share at any size without watching anything.'**
  String get proBenefitExportBody;

  /// No description provided for @proBenefitLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'Still on your device'**
  String get proBenefitLocalTitle;

  /// No description provided for @proBenefitLocalBody.
  ///
  /// In en, this message translates to:
  /// **'Pro changes nothing about your photos: every edit stays local, as it always was.'**
  String get proBenefitLocalBody;

  /// No description provided for @textLayer.
  ///
  /// In en, this message translates to:
  /// **'Text layer'**
  String get textLayer;

  /// No description provided for @bubbleLayer.
  ///
  /// In en, this message translates to:
  /// **'Bubble layer'**
  String get bubbleLayer;

  /// No description provided for @imageLayer.
  ///
  /// In en, this message translates to:
  /// **'Image layer'**
  String get imageLayer;

  /// No description provided for @imageLayerCutOut.
  ///
  /// In en, this message translates to:
  /// **'Image layer · cut out'**
  String get imageLayerCutOut;

  /// No description provided for @dragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder {name}'**
  String dragToReorder(String name);

  /// No description provided for @hideLayer.
  ///
  /// In en, this message translates to:
  /// **'Hide layer'**
  String get hideLayer;

  /// No description provided for @showLayer.
  ///
  /// In en, this message translates to:
  /// **'Show layer'**
  String get showLayer;

  /// No description provided for @duplicateLayer.
  ///
  /// In en, this message translates to:
  /// **'Duplicate layer'**
  String get duplicateLayer;

  /// No description provided for @deleteLayer.
  ///
  /// In en, this message translates to:
  /// **'Delete layer'**
  String get deleteLayer;

  /// No description provided for @deleteLayerNamed.
  ///
  /// In en, this message translates to:
  /// **'Delete layer {name}'**
  String deleteLayerNamed(String name);

  /// No description provided for @cutOut.
  ///
  /// In en, this message translates to:
  /// **'Cut out'**
  String get cutOut;

  /// No description provided for @tapToAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to add a photo'**
  String get tapToAddPhoto;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// Section label; upper case by design.
  ///
  /// In en, this message translates to:
  /// **'CUSTOM (PIXELS)'**
  String get customPixels;

  /// No description provided for @width.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get width;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @scaleLayersToFit.
  ///
  /// In en, this message translates to:
  /// **'Scale layers to fit'**
  String get scaleLayersToFit;

  /// No description provided for @scaleLayersToFitSub.
  ///
  /// In en, this message translates to:
  /// **'Resample the whole composition to the new size'**
  String get scaleLayersToFitSub;

  /// No description provided for @presetSquare.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get presetSquare;

  /// No description provided for @presetPortrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get presetPortrait;

  /// No description provided for @presetStory.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get presetStory;

  /// No description provided for @presetLandscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get presetLandscape;

  /// No description provided for @presetWide.
  ///
  /// In en, this message translates to:
  /// **'Wide'**
  String get presetWide;

  /// No description provided for @presetSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get presetSmall;

  /// Editor top-bar subtitle. {layers} is the already-pluralised layerCount string, e.g. "3 layers".
  ///
  /// In en, this message translates to:
  /// **'{layers} · auto-saved'**
  String layersAutoSaved(String layers);

  /// Progress line on the cut-out sheet; {engine} is the AI model's name.
  ///
  /// In en, this message translates to:
  /// **'{engine} is working…'**
  String engineWorking(String engine);

  /// No description provided for @toolLayers.
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get toolLayers;

  /// No description provided for @toolAdjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get toolAdjust;

  /// No description provided for @toolEffects.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get toolEffects;

  /// No description provided for @toolText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get toolText;

  /// No description provided for @toolErase.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get toolErase;

  /// No description provided for @toolErasePanel.
  ///
  /// In en, this message translates to:
  /// **'Manual erase'**
  String get toolErasePanel;

  /// No description provided for @toolCutout.
  ///
  /// In en, this message translates to:
  /// **'Cut out'**
  String get toolCutout;

  /// No description provided for @toolCutoutPanel.
  ///
  /// In en, this message translates to:
  /// **'AI Background Removal'**
  String get toolCutoutPanel;

  /// No description provided for @toolFrames.
  ///
  /// In en, this message translates to:
  /// **'Frames'**
  String get toolFrames;

  /// No description provided for @toolFramesPanel.
  ///
  /// In en, this message translates to:
  /// **'Animation frames'**
  String get toolFramesPanel;

  /// No description provided for @toolGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get toolGrid;

  /// No description provided for @toolGridPanel.
  ///
  /// In en, this message translates to:
  /// **'Photo grid'**
  String get toolGridPanel;

  /// No description provided for @filterOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get filterOriginal;

  /// No description provided for @filterVivid.
  ///
  /// In en, this message translates to:
  /// **'Vivid'**
  String get filterVivid;

  /// No description provided for @filterPunch.
  ///
  /// In en, this message translates to:
  /// **'Punch'**
  String get filterPunch;

  /// No description provided for @filterChrome.
  ///
  /// In en, this message translates to:
  /// **'Chrome'**
  String get filterChrome;

  /// No description provided for @filterWarm.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get filterWarm;

  /// No description provided for @filterCool.
  ///
  /// In en, this message translates to:
  /// **'Cool'**
  String get filterCool;

  /// No description provided for @filterSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get filterSunset;

  /// No description provided for @filterDawn.
  ///
  /// In en, this message translates to:
  /// **'Dawn'**
  String get filterDawn;

  /// No description provided for @filterDusk.
  ///
  /// In en, this message translates to:
  /// **'Dusk'**
  String get filterDusk;

  /// No description provided for @filterFade.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get filterFade;

  /// No description provided for @filterMatte.
  ///
  /// In en, this message translates to:
  /// **'Matte'**
  String get filterMatte;

  /// No description provided for @filterRetro.
  ///
  /// In en, this message translates to:
  /// **'Retro'**
  String get filterRetro;

  /// No description provided for @filterSepia.
  ///
  /// In en, this message translates to:
  /// **'Sepia'**
  String get filterSepia;

  /// No description provided for @filterMono.
  ///
  /// In en, this message translates to:
  /// **'Mono'**
  String get filterMono;

  /// No description provided for @filterNoir.
  ///
  /// In en, this message translates to:
  /// **'Noir'**
  String get filterNoir;

  /// No description provided for @blendNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get blendNormal;

  /// No description provided for @blendMultiply.
  ///
  /// In en, this message translates to:
  /// **'Multiply'**
  String get blendMultiply;

  /// No description provided for @blendScreen.
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get blendScreen;

  /// No description provided for @blendOverlay.
  ///
  /// In en, this message translates to:
  /// **'Overlay'**
  String get blendOverlay;

  /// No description provided for @blendDarken.
  ///
  /// In en, this message translates to:
  /// **'Darken'**
  String get blendDarken;

  /// No description provided for @blendLighten.
  ///
  /// In en, this message translates to:
  /// **'Lighten'**
  String get blendLighten;

  /// No description provided for @blendDodge.
  ///
  /// In en, this message translates to:
  /// **'Dodge'**
  String get blendDodge;

  /// No description provided for @blendBurn.
  ///
  /// In en, this message translates to:
  /// **'Burn'**
  String get blendBurn;

  /// No description provided for @blendHardLight.
  ///
  /// In en, this message translates to:
  /// **'Hard light'**
  String get blendHardLight;

  /// No description provided for @blendSoftLight.
  ///
  /// In en, this message translates to:
  /// **'Soft light'**
  String get blendSoftLight;

  /// No description provided for @blendDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get blendDifference;

  /// No description provided for @blendExclusion.
  ///
  /// In en, this message translates to:
  /// **'Exclusion'**
  String get blendExclusion;

  /// No description provided for @blendHue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get blendHue;

  /// No description provided for @blendSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get blendSaturation;

  /// No description provided for @blendColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get blendColor;

  /// No description provided for @blendLuminosity.
  ///
  /// In en, this message translates to:
  /// **'Luminosity'**
  String get blendLuminosity;

  /// Section label; upper case by design.
  ///
  /// In en, this message translates to:
  /// **'HOW MANY PHOTOS?'**
  String get gridHowManyPhotos;

  /// Section label in the grid setup sheet; upper case by design.
  ///
  /// In en, this message translates to:
  /// **'LAYOUT'**
  String get gridLayoutLabel;

  /// Section label; upper case by design.
  ///
  /// In en, this message translates to:
  /// **'SIZE'**
  String get gridSizeLabel;

  /// No description provided for @gridSetupHint.
  ///
  /// In en, this message translates to:
  /// **'Pick your photos next - you can change the layout, count and border any time.'**
  String get gridSetupHint;

  /// Screen-reader label for a photo-count chip.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String photoCount(int count);

  /// Screen-reader label for a grid-layout tile.
  ///
  /// In en, this message translates to:
  /// **'Layout {name}'**
  String gridLayoutNamed(String name);

  /// No description provided for @gridSideBySide.
  ///
  /// In en, this message translates to:
  /// **'Side by side'**
  String get gridSideBySide;

  /// No description provided for @gridStacked.
  ///
  /// In en, this message translates to:
  /// **'Stacked'**
  String get gridStacked;

  /// No description provided for @gridWideLeft.
  ///
  /// In en, this message translates to:
  /// **'Wide left'**
  String get gridWideLeft;

  /// No description provided for @gridTallTop.
  ///
  /// In en, this message translates to:
  /// **'Tall top'**
  String get gridTallTop;

  /// No description provided for @gridColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get gridColumns;

  /// No description provided for @gridRows.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get gridRows;

  /// No description provided for @gridBigLeft.
  ///
  /// In en, this message translates to:
  /// **'Big left'**
  String get gridBigLeft;

  /// No description provided for @gridBigTop.
  ///
  /// In en, this message translates to:
  /// **'Big top'**
  String get gridBigTop;

  /// No description provided for @gridTwoByTwo.
  ///
  /// In en, this message translates to:
  /// **'2 x 2'**
  String get gridTwoByTwo;

  /// No description provided for @gridTwoOverThree.
  ///
  /// In en, this message translates to:
  /// **'2 over 3'**
  String get gridTwoOverThree;

  /// No description provided for @gridThreeOverTwo.
  ///
  /// In en, this message translates to:
  /// **'3 over 2'**
  String get gridThreeOverTwo;

  /// No description provided for @gridTwoLeftThreeRight.
  ///
  /// In en, this message translates to:
  /// **'2 left, 3 right'**
  String get gridTwoLeftThreeRight;

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export & share'**
  String get exportTitle;

  /// Section label; upper case by design.
  ///
  /// In en, this message translates to:
  /// **'FORMAT'**
  String get formatLabel;

  /// No description provided for @formatPngSub.
  ///
  /// In en, this message translates to:
  /// **'transparent'**
  String get formatPngSub;

  /// No description provided for @formatJpgSub.
  ///
  /// In en, this message translates to:
  /// **'flattened'**
  String get formatJpgSub;

  /// No description provided for @formatWebpSub.
  ///
  /// In en, this message translates to:
  /// **'smaller'**
  String get formatWebpSub;

  /// Section label; upper case by design.
  ///
  /// In en, this message translates to:
  /// **'RESOLUTION'**
  String get resolutionLabel;

  /// Summary under the export controls. {transparent} is either empty or the parenthetical below, with a leading space.
  ///
  /// In en, this message translates to:
  /// **'Output · {width} × {height} px · {format}{transparent}'**
  String exportOutput(int width, int height, String format, String transparent);

  /// No description provided for @transparentParenthetical.
  ///
  /// In en, this message translates to:
  /// **'(transparent)'**
  String get transparentParenthetical;

  /// No description provided for @saveToDevice.
  ///
  /// In en, this message translates to:
  /// **'Save to device'**
  String get saveToDevice;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @savedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved · {location}'**
  String savedTo(String location);

  /// No description provided for @storageDenied.
  ///
  /// In en, this message translates to:
  /// **'Allow storage access to save to your gallery'**
  String get storageDenied;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the image'**
  String get saveFailed;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed - try again'**
  String get exportFailed;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Share failed - try again'**
  String get shareFailed;

  /// No description provided for @exportGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch a short ad to export'**
  String get exportGateTitle;

  /// No description provided for @exportGateMessage.
  ///
  /// In en, this message translates to:
  /// **'Free exports are supported by a short ad. Go Pro to export without ads, forever.'**
  String get exportGateMessage;

  /// No description provided for @exportGateWatch.
  ///
  /// In en, this message translates to:
  /// **'Watch & export'**
  String get exportGateWatch;

  /// Colour swatch name, spoken by a screen reader after the row label (Color / Fill / Outline). Nine swatches otherwise sound identical.
  ///
  /// In en, this message translates to:
  /// **'white'**
  String get swatchWhite;

  /// Colour swatch name, spoken by a screen reader after the row label (Color / Fill / Outline). Nine swatches otherwise sound identical.
  ///
  /// In en, this message translates to:
  /// **'black'**
  String get swatchBlack;

  /// Colour swatch name, spoken by a screen reader after the row label (Color / Fill / Outline). Nine swatches otherwise sound identical.
  ///
  /// In en, this message translates to:
  /// **'pink'**
  String get swatchPink;

  /// Colour swatch name, spoken by a screen reader after the row label (Color / Fill / Outline). Nine swatches otherwise sound identical.
  ///
  /// In en, this message translates to:
  /// **'amber'**
  String get swatchAmber;

  /// Colour swatch name, spoken by a screen reader after the row label (Color / Fill / Outline). Nine swatches otherwise sound identical.
  ///
  /// In en, this message translates to:
  /// **'green'**
  String get swatchGreen;

  /// Colour swatch name, spoken by a screen reader after the row label (Color / Fill / Outline). Nine swatches otherwise sound identical.
  ///
  /// In en, this message translates to:
  /// **'cyan'**
  String get swatchCyan;

  /// Colour swatch name, spoken by a screen reader after the row label (Color / Fill / Outline). Nine swatches otherwise sound identical.
  ///
  /// In en, this message translates to:
  /// **'violet'**
  String get swatchViolet;

  /// Colour swatch name, spoken by a screen reader after the row label (Color / Fill / Outline). Nine swatches otherwise sound identical.
  ///
  /// In en, this message translates to:
  /// **'rose'**
  String get swatchRose;

  /// Colour swatch name, spoken by a screen reader after the row label (Color / Fill / Outline). Nine swatches otherwise sound identical.
  ///
  /// In en, this message translates to:
  /// **'orange'**
  String get swatchOrange;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'cs',
    'de',
    'en',
    'es',
    'fr',
    'pl',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs':
      return AppLocalizationsCs();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
