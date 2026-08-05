// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Chromis';

  @override
  String get back => 'Atrás';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get done => 'Listo';

  @override
  String get delete => 'Eliminar';

  @override
  String get rename => 'Cambiar nombre';

  @override
  String get duplicate => 'Duplicar';

  @override
  String get open => 'Abrir';

  @override
  String get close => 'Cerrar';

  @override
  String get reset => 'Restablecer';

  @override
  String get apply => 'Aplicar';

  @override
  String get add => 'Añadir';

  @override
  String get remove => 'Quitar';

  @override
  String get menu => 'Menú';

  @override
  String get settings => 'Configuración';

  @override
  String get about => 'Acerca de';

  @override
  String get licenses => 'Licencias';

  @override
  String get nameHint => 'Nombre';

  @override
  String get cannotBeUndone => 'Esto no se puede deshacer.';

  @override
  String get tryAgainInAMoment => 'Inténtalo de nuevo en un momento.';

  @override
  String get appLogo => 'Logo de Chromis';

  @override
  String get pleaseTryAgain => 'inténtalo de nuevo';

  @override
  String get homeTitle => 'Tus proyectos';

  @override
  String get homeTagline => 'Chromis · Editor de fotos: quita el fondo con IA';

  @override
  String get homeRecent => 'RECIENTES';

  @override
  String get homeJoinDiscord => 'Únete a nuestro Discord';

  @override
  String get homeEmptyHint => 'Toca Nuevo proyecto para importar una foto.';

  @override
  String get noProjectsYet => 'Aún no hay proyectos';

  @override
  String get newProject => 'Nuevo proyecto';

  @override
  String get homeNewProjectSubtitle => 'Lienzo en blanco o cuadrícula de fotos';

  @override
  String get homeOpenPhoto => 'Abrir una foto';

  @override
  String get homeOpenPhotoSubtitle => 'El lienzo toma el tamaño de la foto';

  @override
  String projectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count proyectos',
      one: '1 proyecto',
    );
    return '$_temp0';
  }

  @override
  String layerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capas',
      one: '1 capa',
    );
    return '$_temp0';
  }

  @override
  String get renameProject => 'Cambiar nombre del proyecto';

  @override
  String get projectNameHint => 'Nombre del proyecto';

  @override
  String get copySuffix => '(copia)';

  @override
  String deleteProjectTitle(String name) {
    return '¿Eliminar \"$name\"?';
  }

  @override
  String get allProjects => 'Todos los proyectos';

  @override
  String get searchProjects => 'Busca en tus proyectos';

  @override
  String get projectsLoadFailed => 'No se pudieron cargar tus proyectos';

  @override
  String get allProjectsEmptyHint => 'Crea uno desde Inicio y aparecerá aquí.';

  @override
  String get noMatches => 'Sin resultados';

  @override
  String noMatchesFor(String query) {
    return 'Nada coincide con \"$query\".';
  }

  @override
  String get newProjectQuestion => '¿Qué vas a crear?';

  @override
  String get blankCanvas => 'Lienzo en blanco';

  @override
  String get blankCanvasSubtitle => 'Un lienzo; añade fotos y capas a tu gusto';

  @override
  String get photoGrid => 'Cuadrícula de fotos';

  @override
  String get photoGridSubtitle => 'Un collage de 2 a 5 fotos en un diseño';

  @override
  String get drawerHome => 'Inicio y proyectos';

  @override
  String drawerSubtitle(String version) {
    return 'Editor de fotos · v$version';
  }

  @override
  String get appearance => 'Apariencia';

  @override
  String get appearanceSystem => 'Predeterminado del sistema';

  @override
  String get appearanceSystemSub =>
      'Seguir el ajuste claro u oscuro del teléfono';

  @override
  String get appearanceLight => 'Claro';

  @override
  String get appearanceLightSub =>
      'Más legible al aire libre y en pantallas LCD';

  @override
  String get appearanceDark => 'Oscuro';

  @override
  String get appearanceDarkSub =>
      'Negro puro, que las pantallas OLED no iluminan';

  @override
  String get appearanceNote =>
      'Chromis sigue al teléfono salvo que elijas algo aquí. Tu elección se recuerda.';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Predeterminado del sistema';

  @override
  String get languageSystemSub => 'Usa el idioma configurado en tu teléfono';

  @override
  String get languageNote =>
      'Chromis está en inglés a menos que tu teléfono esté configurado en un idioma al que se haya traducido. Se recuerda la opción que elijas aquí.';

  @override
  String get skip => 'Omitir';

  @override
  String get next => 'Siguiente';

  @override
  String get getStarted => 'Empezar';

  @override
  String get onboardStartTitle => 'Empieza con una foto';

  @override
  String get onboardStartBody =>
      'Abre cualquier foto o un lienzo en blanco del tamaño que necesites. Añade capas, texto y globos de cómic.';

  @override
  String get onboardCutoutTitle => 'Quita el fondo';

  @override
  String get onboardCutoutBody =>
      'Separa tu sujeto del fondo con un toque, o borra objetos: todo en el dispositivo, para que tus fotos nunca salgan de tu teléfono.';

  @override
  String get onboardExportTitle => 'Exporta y comparte';

  @override
  String get onboardExportBody =>
      'Guarda un PNG transparente, JPG o WebP en cualquier resolución y compártelo donde quieras.';

  @override
  String get privacyTitle => 'Privacidad y cookies';

  @override
  String get privacyRowSub =>
      'Edición en el dispositivo · cómo funcionan los anuncios';

  @override
  String get privacyBanner =>
      'Tus fotos se quedan en tu dispositivo. Los anuncios son la única excepción: te lo explicamos abajo.';

  @override
  String get privacyOnDevice =>
      'Tus fotos se editan por completo en tu dispositivo: no se sube nada.';

  @override
  String get privacyAiLocal =>
      'La IA para quitar el fondo y objetos funciona localmente; tus fotos nunca salen de tu teléfono.';

  @override
  String get privacyNoAccounts =>
      'Sin cuentas, sin iniciar sesión, sin subir fotos.';

  @override
  String get privacyAds =>
      'La app gratuita muestra anuncios (Google AdMob), que usan un identificador de publicidad.';

  @override
  String get privacyConsent =>
      'Donde es obligatorio, un aviso de consentimiento (UMP) te deja elegir anuncios personalizados o no personalizados.';

  @override
  String get privacyWithdraw =>
      'Puedes cambiar o retirar ese consentimiento cuando quieras: \"Opciones de privacidad de anuncios\", más abajo, vuelve a abrir el formulario.';

  @override
  String get privacyPro =>
      'La mejora Pro de pago único quita todos los anuncios, y con ellos el identificador de publicidad.';

  @override
  String get fullPrivacyPolicy => 'Política de privacidad completa';

  @override
  String get questions => '¿Preguntas?';

  @override
  String get openSourceLicenses => 'Licencias de código abierto';

  @override
  String get licensesRowSub => 'El gran trabajo en el que nos apoyamos';

  @override
  String get licensesIntro =>
      'Chromis está construido sobre un maravilloso trabajo de código abierto. Gracias a todos los que lo hicieron posible.';

  @override
  String get viewFullLicenseTexts => 'Ver los textos completos';

  @override
  String get licenseCategoryFonts => 'Fuentes';

  @override
  String get licenseCategoryAi => 'IA en el dispositivo';

  @override
  String get licenseCategoryEncoding => 'Codificación de medios';

  @override
  String get licenseCategoryMonetization => 'Monetización';

  @override
  String get licenseCategoryFramework => 'Framework y paquetes';

  @override
  String get licenseUseDisplayFont => 'Tipografía de títulos';

  @override
  String get licenseUseBodyFont => 'Tipografía de interfaz y texto';

  @override
  String get licenseUseComicFont => 'Fuente de carteles de cómic';

  @override
  String get licenseUseCaptionFont => 'Fuente de carteles';

  @override
  String get licenseUseScriptFont => 'Fuente cursiva para carteles';

  @override
  String get licenseUseBgRemoval => 'Quitar el fondo (Android)';

  @override
  String get licenseUseRuntime => 'Ejecuta el modelo alternativo incluido';

  @override
  String get licenseUseOnDeviceAi => 'Quitar objetos y fondo en el dispositivo';

  @override
  String get licenseUseEncoding => 'Codificación PNG / JPG / WebP';

  @override
  String get licenseUseAds =>
      'Anuncios de banner / recompensados + consentimiento';

  @override
  String get licenseUsePurchase => 'Compra única Pro (quitar anuncios)';

  @override
  String get licenseUseFramework => 'Framework de la app';

  @override
  String get licenseUsePlugins =>
      'Navegación, almacenamiento, compartir, selección de imágenes';

  @override
  String get licenseUseState => 'Gestión de estado';

  @override
  String get licenseUseClipboard => 'Pegar imagen desde el portapapeles';

  @override
  String get goPro => 'Hazte Pro';

  @override
  String get goProRemoveAds => 'Hazte Pro · sin anuncios';

  @override
  String get goProRemoveAdsPlain => 'Hazte Pro - sin anuncios';

  @override
  String get goProRowSub => 'Mejora de pago único: sin anuncios, nunca';

  @override
  String get goProHeroTitle => 'Quita los anuncios para siempre';

  @override
  String get goProHeroBody =>
      'Compra única. Todas las funciones de IA siguen siendo gratis: sin anuncios y sin tener que ver nada.';

  @override
  String get goProBenefitNoAds => 'Sin banners ni anuncios a pantalla completa';

  @override
  String get goProBenefitNoRewarded =>
      'Usa la IA para quitar el fondo y los objetos sin ver un anuncio';

  @override
  String get goProBenefitOneTime => 'Pago único: sin suscripción';

  @override
  String get goProBenefitSupports =>
      'Apoya la edición de fotos privada y en el dispositivo';

  @override
  String get goProOwned =>
      'Eres Pro: los anuncios están desactivados. ¡Gracias!';

  @override
  String upgradeFor(String price) {
    return 'Mejorar - $price';
  }

  @override
  String get restorePurchase => 'Restaurar compra';

  @override
  String get oneTimeUnavailable => 'Compra única · no disponible temporalmente';

  @override
  String get oneTimeRestores =>
      'Compra única · se restaura en cualquier dispositivo';

  @override
  String get oneTimeNoSubscription => 'Compra única. Sin suscripción.';

  @override
  String get purchasesUnavailable =>
      'Las compras no están disponibles temporalmente. Inténtalo de nuevo más tarde.';

  @override
  String get purchaseStartFailed =>
      'No se pudo iniciar la compra. Inténtalo de nuevo.';

  @override
  String get purchaseStartFailedOwned =>
      'No se pudo iniciar la compra. Si ya compraste Pro, toca Restaurar compra.';

  @override
  String get checkingPreviousPurchase => 'Buscando una compra anterior…';

  @override
  String get playUnreachable =>
      'No se pudo conectar con Google Play. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get purchaseFailedGeneric => 'No se pudo completar la compra';

  @override
  String get removeAdsArrow => 'Quitar anuncios →';

  @override
  String get adsDeclinedExplainer =>
      'Has elegido no permitir anuncios, así que no hay ningún anuncio que ver, y los anuncios son lo que mantiene Chromis gratis.\n\nPermite los anuncios para seguir gratis, o hazte Pro para usarlo todo sin ningún anuncio.';

  @override
  String get reviewAdConsent => 'Revisar consentimiento';

  @override
  String get adPrivacyChoices => 'Opciones de privacidad de anuncios';

  @override
  String get adPrivacyChoicesSub =>
      'Cambia el consentimiento que diste para los anuncios personalizados';

  @override
  String adSettingsFailed(String error) {
    return 'No se pudo abrir la configuración de anuncios: $error';
  }

  @override
  String get untitledProject => 'Sin título';

  @override
  String get photoLayerDefault => 'Foto';

  @override
  String get textLayerDefault => 'Texto';

  @override
  String get mergedLayerName => 'Combinada';

  @override
  String get mergedLayerSuffix => 'combinación';

  @override
  String get saveRetrying =>
      'No se pudo guardar: tus cambios están a salvo, seguimos intentándolo';

  @override
  String get speed => 'Velocidad';

  @override
  String get fillingBackground => 'Rellenando el fondo…';

  @override
  String get findingObject => 'Buscando el objeto…';

  @override
  String get mergingLayers => 'Combinando capas…';

  @override
  String get removingBackground => 'Quitando el fondo…';

  @override
  String get hideToolPanel => 'Ocultar panel de herramientas';

  @override
  String get showToolPanel => 'Mostrar panel de herramientas';

  @override
  String get cropOpenFailed => 'No se pudo abrir la foto para recortar';

  @override
  String get photoCropped => 'Foto recortada';

  @override
  String get editCrop => 'Editar recorte';

  @override
  String get cropPhoto => 'Recortar foto';

  @override
  String get resetCrop => 'Restablecer recorte';

  @override
  String get crop => 'Recortar';

  @override
  String get cancelCrop => 'Cancelar recorte';

  @override
  String get previewUnavailable => 'Vista previa no disponible';

  @override
  String get cropToRatio => 'Recortar a proporción';

  @override
  String get cropSheetHint =>
      'Arrastra un marco libre o recorta desde el centro a una proporción';

  @override
  String get freeformCrop => 'Recorte libre';

  @override
  String get ratiosSection => 'PROPORCIONES';

  @override
  String croppedTo(int width, int height) {
    return 'Lienzo recortado a $width×$height';
  }

  @override
  String get scale => 'Escala';

  @override
  String get rotation => 'Rotación';

  @override
  String get horizontal => 'Horizontal';

  @override
  String get vertical => 'Vertical';

  @override
  String get brightness => 'Brillo';

  @override
  String get contrast => 'Contraste';

  @override
  String get saturation => 'Saturación';

  @override
  String get hue => 'Tono';

  @override
  String get opacity => 'Opacidad';

  @override
  String get size => 'Tamaño';

  @override
  String get color => 'Color';

  @override
  String get off => 'Desactivado';

  @override
  String get adjustEmptyHint =>
      'Selecciona una capa para escalarla, girarla o ajustarla.\nO toca Añadir para importar una foto.';

  @override
  String get effectsLink => 'Filtros, HDR, viñeta, sombra…';

  @override
  String get effectsLinkLayer => 'Fusión, sombra, contorno…';

  @override
  String get textEmptyHint => 'Selecciona una capa de texto o añade una.';

  @override
  String get addText => 'Añadir texto';

  @override
  String get tapFontToPreview => 'Toca una fuente para verla';

  @override
  String get typeYourCaption => 'Escribe tu texto…';

  @override
  String get outlineSection => 'CONTORNO';

  @override
  String get cutoutOutlineSection => 'CONTORNO DEL SUJETO';

  @override
  String get autoColor => 'Color automático';

  @override
  String get thickness => 'Grosor';

  @override
  String get outlineOpacity => 'Opacidad del contorno';

  @override
  String get font => 'Fuente';

  @override
  String fontAdded(String family) {
    return 'Fuente añadida · $family';
  }

  @override
  String get comicBubble => 'Globo de cómic';

  @override
  String get bubble => 'Globo';

  @override
  String get bubbleTextHint => 'Texto del globo…';

  @override
  String get fill => 'Relleno';

  @override
  String get outline => 'Contorno';

  @override
  String get bubbleTailHint =>
      'Arrastra el punto del extremo de la cola para apuntarla en cualquier dirección.';

  @override
  String get addABubble => 'Añadir un globo';

  @override
  String get addABubbleHint =>
      'Elige un formato. El texto, los colores y la cola se pueden editar después, y esto también.';

  @override
  String get addBubble => 'Añadir globo';

  @override
  String bubbleAdded(String format) {
    return 'Globo de $format añadido: edítalo en el panel';
  }

  @override
  String bubbleTileSemantics(String format, String description) {
    return 'Globo de $format: $description';
  }

  @override
  String get bubbleSpeech => 'Diálogo';

  @override
  String get bubbleThought => 'Pensamiento';

  @override
  String get bubbleShout => 'Grito';

  @override
  String get bubbleCaption => 'Narración';

  @override
  String get bubbleWhisper => 'Susurro';

  @override
  String get bubbleSpeechBlurb => 'Redondeado, con cola';

  @override
  String get bubbleThoughtBlurb => 'Nube con rastro de puntos';

  @override
  String get bubbleShoutBlurb => 'Estrella con picos';

  @override
  String get bubbleCaptionBlurb => 'Caja de narración cuadrada';

  @override
  String get bubbleWhisperBlurb => 'Contorno de línea discontinua';

  @override
  String get notAPhotoGrid => 'Este proyecto no es una cuadrícula de fotos.';

  @override
  String get shuffle => 'Mezclar';

  @override
  String get photosSection => 'FOTOS';

  @override
  String get layoutSection => 'DISEÑO';

  @override
  String get border => 'Borde';

  @override
  String get corners => 'Esquinas';

  @override
  String get effectsEmptyHint =>
      'Selecciona una capa para darle un estilo.\nFiltros, HDR y viñeta para fotos; sombra, contorno y fusión para cualquier capa.';

  @override
  String get filterSection => 'FILTRO';

  @override
  String get strength => 'Intensidad';

  @override
  String get hdrSection => 'HDR';

  @override
  String get toneAndDetail => 'Tonos + detalle';

  @override
  String get vignetteSection => 'VIÑETA';

  @override
  String get amount => 'Cantidad';

  @override
  String get softness => 'Suavidad';

  @override
  String get shadowSection => 'SOMBRA';

  @override
  String get direction => 'Dirección';

  @override
  String get distance => 'Distancia';

  @override
  String get blur => 'Desenfoque';

  @override
  String get density => 'Densidad';

  @override
  String get blendSection => 'FUSIÓN';

  @override
  String pixels(int count) {
    return '$count px';
  }

  @override
  String get working => 'Procesando…';

  @override
  String get undoRemoval => 'Restaurar el fondo';

  @override
  String get removeBackground => 'Quitar el fondo';

  @override
  String get removeAnObject => 'Quitar un objeto';

  @override
  String get removeObject => 'Quitar objeto';

  @override
  String get background => 'Fondo';

  @override
  String get object => 'Objeto';

  @override
  String get erase => 'Borrar';

  @override
  String get restore => 'Restaurar';

  @override
  String get fillIn => 'Rellenar';

  @override
  String get fillExplainer =>
      'Rellenar reconstruye el fondo con el resto de la foto.';

  @override
  String get eraseExplainer => 'Borrar quita el objeto y deja transparencia.';

  @override
  String get objectRemoveHint =>
      'Toca en la foto un objeto que sobre para quitarlo: algo suelto, un segundo sujeto, desorden. Si tocas el sujeto principal, no pasa nada; deshacer lo devuelve todo.';

  @override
  String get cutoutSelectPhoto =>
      'Selecciona una capa de foto para quitar el fondo.';

  @override
  String get cutoutHint =>
      'Un toque para aislar tu sujeto. Detectamos los bordes automáticamente: afina lo que quieras a mano en la herramienta Borrar.';

  @override
  String get backgroundRestored => 'Fondo restaurado';

  @override
  String get aiModelSection => 'MODELO DE IA';

  @override
  String get whichAiModel => '¿Qué modelo de IA?';

  @override
  String get segBuiltinLabel => 'IA integrada';

  @override
  String get segBuiltinTagline => 'En el dispositivo · rápida y privada';

  @override
  String get segBuiltinBlurb =>
      'Se ejecuta en el dispositivo para quitar el fondo de forma rápida y privada. Ideal para mascotas y personas con bordes definidos: nada sale de tu teléfono.';

  @override
  String get segU2netTagline => 'Código abierto · más nitidez';

  @override
  String get segU2netBlurb =>
      'Un modelo de código abierto para objetos destacados, incluido en la app. Funciona totalmente sin conexión y suele ser más nítido en detalles finos como pelaje, cabello y bigotes, aunque es algo más lento.';

  @override
  String get aiGateTitle => 'Desbloquea las herramientas de IA';

  @override
  String get aiGateMessage =>
      'Ve un anuncio corto para usar las herramientas de IA durante el resto de esta sesión de edición. Hazte Pro para usarlas sin anuncios, para siempre.';

  @override
  String get aiGateWatch => 'Ver y desbloquear';

  @override
  String get aiGateNotRewarded =>
      'Ve el anuncio completo para usar la IA, o hazte Pro para quitar anuncios';

  @override
  String get objectAiUnavailable =>
      'La IA para quitar objetos no está disponible en este dispositivo: usa el pincel Borrar';

  @override
  String get bgRemovalUnavailable =>
      'Quitar el fondo aún no está disponible en este dispositivo';

  @override
  String get layerGoneCutoutDiscarded =>
      'Esa capa ya no existe: se descartó el resultado';

  @override
  String get backgroundRemoved => 'Fondo quitado';

  @override
  String backgroundRemovedWith(String engine) {
    return 'Fondo quitado · $engine';
  }

  @override
  String get bgRemovalFailed =>
      'No se pudo quitar el fondo: inténtalo de nuevo';

  @override
  String get selectPhotoToCutOut =>
      'Selecciona una capa de foto para quitar el fondo';

  @override
  String get detectingSubject =>
      'Detectando el sujeto y afinando bordes · en el dispositivo';

  @override
  String get edgeFeather => 'Suavizar bordes';

  @override
  String get applyToLayer => 'Aplicar a la capa';

  @override
  String get tapObjectsToErase => 'Toca objetos en la foto para borrarlos';

  @override
  String get tapObjectsToRemove => 'Toca objetos para quitarlos';

  @override
  String get tapAnObjectToRemove => 'Toca un objeto en la foto para quitarlo';

  @override
  String get chooseAiEngine =>
      'Elige un motor de IA · se ejecuta en tu dispositivo';

  @override
  String get autoRefineEdges => 'Afinar bordes automáticamente';

  @override
  String get brushFailed => 'No se pudo aplicar el pincel';

  @override
  String get nothingToRemoveThere => 'Ahí no hay nada que quitar';

  @override
  String get objectRemoved => 'Objeto quitado: deshaz para recuperarlo';

  @override
  String get objectRemoveFailed => 'No se pudo quitar eso: inténtalo de nuevo';

  @override
  String get noObjectThere => 'No se encontró ningún objeto ahí';

  @override
  String get thatLooksLikeSubject =>
      'Eso parece tu sujeto: usa Borrar para ajustes finos';

  @override
  String get fillUnavailable =>
      'No se pudo reconstruir esa zona: se borró en su lugar';

  @override
  String get objectFilled => 'Objeto rellenado: deshaz para revertir';

  @override
  String get eraseEmptyHint =>
      'Selecciona una capa de foto para borrar o añade una foto.';

  @override
  String get brushOverCanvas => 'Pinta sobre el lienzo';

  @override
  String get brushSize => 'Tamaño del pincel';

  @override
  String get softEdges => 'Bordes suaves';

  @override
  String get play => 'Reproducir';

  @override
  String get pause => 'Pausar';

  @override
  String get newLayersToAllFrames => 'Capas nuevas en todos los fotogramas';

  @override
  String get onionSkin => 'Papel cebolla (anterior atenuado)';

  @override
  String get duplicateFrame => 'Duplicar fotograma';

  @override
  String get moveLeft => 'Mover a la izquierda';

  @override
  String get moveRight => 'Mover a la derecha';

  @override
  String get deleteFrame => 'Eliminar fotograma';

  @override
  String frameOf(int current, int total) {
    return 'Fotograma $current / $total';
  }

  @override
  String get mergeDown => 'Combinar abajo';

  @override
  String get flatten => 'Acoplar';

  @override
  String get layersEmptyHint =>
      'Aún no hay capas. Toca Añadir para importar una foto o añadir texto.';

  @override
  String get mergedTwoLayers => '2 capas combinadas';

  @override
  String flattenedLayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capas acopladas',
      one: '1 capa acoplada',
    );
    return '$_temp0';
  }

  @override
  String get mergeFailed => 'No se pudieron combinar esas capas';

  @override
  String get importPhotoFailed => 'No se pudo importar la foto';

  @override
  String get noImageInClipboard => 'No hay ninguna imagen en el portapapeles';

  @override
  String get pasteFailed => 'No se pudo pegar la imagen';

  @override
  String get takePhoto => 'Tomar foto';

  @override
  String get choosePhoto => 'Elegir foto';

  @override
  String get pasteImage => 'Pegar imagen';

  @override
  String get renameLayer => 'Cambiar nombre de la capa';

  @override
  String get canvasSize => 'Tamaño del lienzo';

  @override
  String get addLayer => 'Foto';

  @override
  String get aiCut => 'Sin fondo';

  @override
  String get seeThePrice => 'Ver el precio';

  @override
  String get notNow => 'Ahora no';

  @override
  String get oneTimeNoSubscriptionShort => 'Compra única, sin suscripción';

  @override
  String get proBenefitNoAdsTitle => 'Sin anuncios, en ninguna parte';

  @override
  String get proBenefitNoAdsBody =>
      'El banner de Inicio y los anuncios a pantalla completa desaparecen para siempre.';

  @override
  String get proBenefitAiTitle => 'IA sin esperas';

  @override
  String get proBenefitAiBody =>
      'Quitar el fondo y borrar objetos funcionan al instante, sin ver antes un anuncio.';

  @override
  String get proBenefitExportTitle => 'Exporta y comparte sin límites';

  @override
  String get proBenefitExportBody =>
      'Guarda o comparte en cualquier tamaño sin ver ningún anuncio.';

  @override
  String get proBenefitLocalTitle => 'Sigue en tu dispositivo';

  @override
  String get proBenefitLocalBody =>
      'Pro no cambia nada de tus fotos: cada edición sigue siendo local, como siempre.';

  @override
  String get textLayer => 'Capa de texto';

  @override
  String get bubbleLayer => 'Capa de globo';

  @override
  String get imageLayer => 'Capa de imagen';

  @override
  String get imageLayerCutOut => 'Capa de imagen · sin fondo';

  @override
  String dragToReorder(String name) {
    return 'Arrastra para reordenar $name';
  }

  @override
  String get hideLayer => 'Ocultar capa';

  @override
  String get showLayer => 'Mostrar capa';

  @override
  String get duplicateLayer => 'Duplicar capa';

  @override
  String get deleteLayer => 'Eliminar capa';

  @override
  String deleteLayerNamed(String name) {
    return 'Eliminar la capa $name';
  }

  @override
  String get cutOut => 'Fondo quitado';

  @override
  String get tapToAddPhoto => 'Toca para añadir una foto';

  @override
  String get undo => 'Deshacer';

  @override
  String get redo => 'Rehacer';

  @override
  String get export => 'Exportar';

  @override
  String get customPixels => 'PERSONALIZADO (PÍXELES)';

  @override
  String get width => 'Ancho';

  @override
  String get height => 'Alto';

  @override
  String get create => 'Crear';

  @override
  String get scaleLayersToFit => 'Escalar capas para que encajen';

  @override
  String get scaleLayersToFitSub =>
      'Vuelve a muestrear toda la composición al nuevo tamaño';

  @override
  String get presetSquare => 'Cuadrado';

  @override
  String get presetPortrait => 'Vertical';

  @override
  String get presetStory => 'Historia';

  @override
  String get presetLandscape => 'Horizontal';

  @override
  String get presetWide => 'Panorámico';

  @override
  String get presetSmall => 'Pequeño';

  @override
  String layersAutoSaved(String layers) {
    return '$layers · guardado automático';
  }

  @override
  String engineWorking(String engine) {
    return '$engine está procesando…';
  }

  @override
  String get toolLayers => 'Capas';

  @override
  String get toolAdjust => 'Ajustar';

  @override
  String get toolEffects => 'Efectos';

  @override
  String get toolText => 'Texto';

  @override
  String get toolErase => 'Borrar';

  @override
  String get toolErasePanel => 'Borrado manual';

  @override
  String get toolCutout => 'Sin fondo';

  @override
  String get toolCutoutPanel => 'Quitar el fondo con IA';

  @override
  String get toolFrames => 'Fotogramas';

  @override
  String get toolFramesPanel => 'Fotogramas de animación';

  @override
  String get toolGrid => 'Cuadrícula';

  @override
  String get toolGridPanel => 'Cuadrícula de fotos';

  @override
  String get filterOriginal => 'Original';

  @override
  String get filterVivid => 'Vívido';

  @override
  String get filterPunch => 'Impacto';

  @override
  String get filterChrome => 'Cromo';

  @override
  String get filterWarm => 'Cálido';

  @override
  String get filterCool => 'Frío';

  @override
  String get filterSunset => 'Atardecer';

  @override
  String get filterDawn => 'Amanecer';

  @override
  String get filterDusk => 'Anochecer';

  @override
  String get filterFade => 'Desvaído';

  @override
  String get filterMatte => 'Mate';

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
  String get blendMultiply => 'Multiplicar';

  @override
  String get blendScreen => 'Trama';

  @override
  String get blendOverlay => 'Superponer';

  @override
  String get blendDarken => 'Oscurecer';

  @override
  String get blendLighten => 'Aclarar';

  @override
  String get blendDodge => 'Sobreexponer';

  @override
  String get blendBurn => 'Subexponer';

  @override
  String get blendHardLight => 'Luz fuerte';

  @override
  String get blendSoftLight => 'Luz suave';

  @override
  String get blendDifference => 'Diferencia';

  @override
  String get blendExclusion => 'Exclusión';

  @override
  String get blendHue => 'Tono';

  @override
  String get blendSaturation => 'Saturación';

  @override
  String get blendColor => 'Color';

  @override
  String get blendLuminosity => 'Luminosidad';

  @override
  String get gridHowManyPhotos => '¿CUÁNTAS FOTOS?';

  @override
  String get gridLayoutLabel => 'DISEÑO';

  @override
  String get gridSizeLabel => 'TAMAÑO';

  @override
  String get gridSetupHint =>
      'Elige tus fotos a continuación: puedes cambiar el diseño, la cantidad y el borde cuando quieras.';

  @override
  String photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String gridLayoutNamed(String name) {
    return 'Diseño $name';
  }

  @override
  String get gridSideBySide => 'Lado a lado';

  @override
  String get gridStacked => 'Apiladas';

  @override
  String get gridWideLeft => 'Ancha izq.';

  @override
  String get gridTallTop => 'Alta arriba';

  @override
  String get gridColumns => 'Columnas';

  @override
  String get gridRows => 'Filas';

  @override
  String get gridBigLeft => 'Grande izq.';

  @override
  String get gridBigTop => 'Grande arriba';

  @override
  String get gridTwoByTwo => '2 x 2';

  @override
  String get gridTwoOverThree => '2 sobre 3';

  @override
  String get gridThreeOverTwo => '3 sobre 2';

  @override
  String get gridTwoLeftThreeRight => '2 izq. 3 der.';

  @override
  String get exportTitle => 'Exportar y compartir';

  @override
  String get formatLabel => 'FORMATO';

  @override
  String get formatPngSub => 'transparente';

  @override
  String get formatJpgSub => 'acoplado';

  @override
  String get formatWebpSub => 'más pequeño';

  @override
  String get resolutionLabel => 'RESOLUCIÓN';

  @override
  String exportOutput(
    int width,
    int height,
    String format,
    String transparent,
  ) {
    return 'Salida · $width × $height px · $format$transparent';
  }

  @override
  String get transparentParenthetical => '(transparente)';

  @override
  String get saveToDevice => 'Guardar en el dispositivo';

  @override
  String get share => 'Compartir';

  @override
  String savedTo(String location) {
    return 'Guardado · $location';
  }

  @override
  String get storageDenied =>
      'Permite el acceso al almacenamiento para guardar en tu galería';

  @override
  String get saveFailed => 'No se pudo guardar la imagen';

  @override
  String get exportFailed => 'Error al exportar: inténtalo de nuevo';

  @override
  String get shareFailed => 'Error al compartir: inténtalo de nuevo';

  @override
  String get exportGateTitle => 'Ve un anuncio corto para exportar';

  @override
  String get exportGateMessage =>
      'Las exportaciones gratuitas se financian con un anuncio corto. Hazte Pro para exportar sin anuncios, para siempre.';

  @override
  String get exportGateWatch => 'Ver y exportar';

  @override
  String get swatchWhite => 'blanco';

  @override
  String get swatchBlack => 'negro';

  @override
  String get swatchPink => 'rosa';

  @override
  String get swatchAmber => 'ámbar';

  @override
  String get swatchGreen => 'verde';

  @override
  String get swatchCyan => 'cian';

  @override
  String get swatchViolet => 'violeta';

  @override
  String get swatchRose => 'rosa palo';

  @override
  String get swatchOrange => 'naranja';
}
