#include <QApplication>
#include <QStyle>
#include <QTimer>
#include "AkvisTextControl.h"
#include <limits>

#ifdef __APPLE__
# undef qDebug
#endif

QT_BEGIN_NAMESPACE
Q_GUI_EXPORT extern int qt_defaultDpiY(); // in qfont.cpp
QT_END_NAMESPACE

#include <private/qtextdocumentfragment_p.h>
class TextDocumentFragmentHack { // !!! ОЧЕНЬ ГРЯЗНЫЙ ХАК !!!
public:
  TextDocumentFragmentHack( QTextDocumentFragment* fragment ) :
    d( ( (TextDocumentFragmentHack*)fragment )->d )
  {}
  QTextDocumentFragmentPrivate *d;
};
static QTextDocumentFragmentPrivate* hack_d_func( QTextDocumentFragment* p ) {
  TextDocumentFragmentHack tmp( p );
  return tmp.d;
}

  #include "private/qwidgettextcontrol_p_p.h"
  typedef QWidgetTextControlPrivate _QWidgetTextControlPrivate;

  class TextControlHack : public _QWidgetTextControl {
  public:
    Q_DECLARE_PRIVATE( QWidgetTextControl )

    _QWidgetTextControlPrivate* hack_d_func() { return d_func(); }
    const _QWidgetTextControlPrivate* const_hack_d_func() const { return d_func(); }
  };

namespace Akvis {

static _QWidgetTextControlPrivate* hack_d_func( AkvisTextControl* p ) {
  return ( ( TextControlHack*) p )->hack_d_func();
}

static const _QWidgetTextControlPrivate* hack_d_func( const AkvisTextControl* p ) {
  return ( ( const TextControlHack*) p )->const_hack_d_func();
}


//-----------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------
sDefaultParamsTC::sDefaultParamsTC() :
  fontFamily( "Arial" ), fontSize( 10 ), fontWeight( QFont::Normal ), fontItalic( false ),
  fontColor( Qt::black ), 
  fontCapitalization( QFont::MixedCase ), fontVertAlignment( QTextCharFormat::AlignNormal ),
  fontUnderline( false ), fontStrikeOut( false ), fontAntialias( true  ), horzAlign( Qt::AlignLeft ), 
  marginLeft ( 0 ), marginRight( 0 ), intendFirstLine( 0 )
{}

void sDefaultParamsTC::FillTo( bool isFixedBounds, QTextCharFormat& charFmt, QTextBlockFormat& blockFmt ) const {
  charFmt.setFontFamily         ( fontFamily );
  charFmt.setFontPointSize      ( float( fontSize ) );
  charFmt.setFontWeight         ( fontWeight );
  charFmt.setFontItalic         ( fontItalic );
  charFmt.setForeground         ( QBrush( fontColor ) );
  charFmt.setFontCapitalization ( QFont::Capitalization( fontCapitalization ) );
  charFmt.setVerticalAlignment  ( QTextCharFormat::VerticalAlignment( fontVertAlignment ) );
  charFmt.setFontUnderline      ( fontUnderline );
  charFmt.setFontStrikeOut      ( fontStrikeOut );
  charFmt.setFontStyleStrategy  ( QFont::StyleStrategy( QFont::PreferQuality | ( fontAntialias ? QFont::PreferAntialias : QFont::NoAntialias ) ) );
  if( !isFixedBounds ) {
    blockFmt.setAlignment   ( Qt::AlignLeft );
    blockFmt.setLeftMargin  ( 0 );
    blockFmt.setRightMargin ( 0 );
    blockFmt.setTextIndent  ( 0 );
  }
  else {
    blockFmt.setAlignment   ( Qt::Alignment( horzAlign ) );
    blockFmt.setLeftMargin  ( marginLeft );
    blockFmt.setRightMargin ( marginRight );
    blockFmt.setTextIndent  ( intendFirstLine );
  }
  blockFmt.setTopMargin   ( 0 );
  blockFmt.setBottomMargin( 0 );
}

void sDefaultParamsTC::SetFrom( const QTextCharFormat& charFmt, const QTextBlockFormat& blockFmt ) {
  // charFmt
  fontFamily         = charFmt.fontFamily();
  fontSize           = (int)charFmt.fontPointSize();
  fontWeight         = charFmt.fontWeight();
  fontItalic         = charFmt.fontItalic();
  fontColor          = charFmt.foreground().color();
  fontVertAlignment  = charFmt.verticalAlignment();
  fontUnderline      = charFmt.fontUnderline();
  fontStrikeOut      = charFmt.fontStrikeOut();
  fontCapitalization = charFmt.fontCapitalization();
  if( fontCapitalization == QFont::SmallCaps ) {
    fontCapitalization = QFont::MixedCase;
  }
  // blockFmt
  horzAlign       = blockFmt.alignment();
  marginLeft      = blockFmt.leftMargin();
  marginRight     = blockFmt.rightMargin();
  intendFirstLine = blockFmt.textIndent();
}



//-----------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------
AkvisTextControl::AkvisTextControl( QTextDocument *doc, QObject *parent, sDefaultParamsTC& defaultParams ) :
  _QWidgetTextControl( doc, parent ), m_DefaultParams( defaultParams )
{}

bool AkvisTextControl::IsCaretOn() const {
  return hack_d_func( this )->cursorOn;
}

bool AkvisTextControl::hasSelection() const {
  return hack_d_func( this )->cursor.hasSelection();
}

void AkvisTextControl::clearSelection() {
  _QWidgetTextControlPrivate *d = hack_d_func( this );
  Q_ASSERT( d->cursor.hasSelection() );
  QTextCursor oldSelection( d->cursor );
  d->cursor.clearSelection();
  d->selectionChanged( true );
  d->repaintOldAndNewSelection( oldSelection );
}

void AkvisTextControl::setHasFocus() {
  hack_d_func( this )->hasFocus = true;
}

void AkvisTextControl::setBlinkingCaretEnabled( bool enable ) {
  hack_d_func( this )->setCursorVisible( enable );
}

void AkvisTextControl::setCursorPosition( const QPointF &pos ) {
  hack_d_func( this )->setCursorPosition( pos );
}

void AkvisTextControl::timerEvent( QTimerEvent* e ) {
  _QWidgetTextControlPrivate *d = hack_d_func( this );
  if( e->timerId() == d->cursorBlinkTimer.timerId() ) {
    d->cursorOn = !d->cursorOn;
    if( d->cursor.hasSelection() && !QApplication::style()->styleHint( QStyle::SH_BlinkCursorWhenTextSelected ) ) {
      d->cursorOn = false;
    }
    emit blinkCaret( d->cursorOn );
    return;
  }
  _QWidgetTextControl::timerEvent( e );
}

template < class T >
static bool RemoveTags( T& fmt ) {
  bool changed = false;
  if( fmt.hasProperty( QTextFormat::BackgroundBrush ) ) {
    fmt.clearProperty(QTextFormat::BackgroundBrush);
    changed = true;
  }
  if( fmt.hasProperty( QTextFormat::BackgroundImageUrl ) ) {
    fmt.clearProperty(QTextFormat::BackgroundImageUrl );
    changed = true;
  }
  if( fmt.hasProperty( QTextFormat::ImageName ) ) {
    fmt.clearProperty(QTextFormat::ImageName );
    changed = true;
  }
  if( fmt.hasProperty( QTextFormat::AnchorHref ) ) {
    fmt.clearProperty(QTextFormat::AnchorHref );
    changed = true;
  }
  return changed;
}

bool ValidateProperties( QTextCharFormat& charFmt ) {
  #if 0
  auto PR = charFmt.properties();
  for( auto I = PR.begin(); I != PR.end(); ++I ) {
    QTextFormat::Property    key = (QTextFormat::Property)I.key();
    QTextFormat::FormatType type = (QTextFormat::FormatType)I.value().type();
    qDebug( "%X, %d\n", key, type );
 }
 #endif

  bool changed = RemoveTags( charFmt );
  if( charFmt.fontCapitalization() == QFont::SmallCaps ) {
    charFmt.setFontCapitalization( QFont::MixedCase );
    changed = true;
  }
  if( !charFmt.hasProperty( QTextFormat::FontFamily ) ) {
    charFmt.setFontFamily( charFmt.font().family() );
    changed = true;
  }
  else {
    QString family( charFmt.fontFamily() );
    if( family.contains( ',' ) ) {
      QStringList families( family.split( ',', QString::SkipEmptyParts ) );
      if( families.isEmpty() )
        charFmt.setFontFamily( charFmt.font().family() );
      else {
        charFmt.setFontFamily( families[0] );
      }
      changed = true;
    }
  }
  return changed;
}

static bool Validate( QTextCharFormat& charFmt, const QTextCharFormat& defFmt ) {
  bool changed = ValidateProperties( charFmt );
  QFont::StyleStrategy ss = defFmt.fontStyleStrategy();
  if( ( charFmt.fontStyleStrategy() & ( QFont::PreferAntialias | QFont::NoAntialias ) ) != ( ss & ( QFont::PreferAntialias | QFont::NoAntialias ) ) ) {
    charFmt.setFontStyleStrategy( ss );
    changed = true;
  }

  if( charFmt.hasProperty( QTextFormat::FontPointSize ) ) {
    return changed;
  }
  // Требуется явно добавить размер шрифта
  double pointSize = 0; int pixelSize = 0;
  if( charFmt.hasProperty( QTextFormat::FontSizeAdjustment ) ) {
    charFmt.clearProperty( QTextFormat::FontSizeAdjustment );
  }
  if( charFmt.hasProperty( QTextFormat::FontPixelSize ) ) {
    pixelSize = charFmt.intProperty( QTextFormat::FontPixelSize );
    charFmt.clearProperty( QTextFormat::FontPixelSize );
  }
  if( pixelSize <= 0 ) {
    pointSize = defFmt.doubleProperty( QTextFormat::FontPointSize );
    if( pointSize <= 0 ) {
      pointSize = charFmt.font().pointSizeF();
      if( pointSize < 0 ) {
        pixelSize = charFmt.font().pixelSize();
      }
    }
  }
  if( pointSize <= 0 ) {
    pointSize = ( pixelSize <= 0 ? 9 : pixelSize * 72.0 / qt_defaultDpiY() );
  }
  charFmt.setFontPointSize( pointSize );
  return true;
}

void AkvisTextControl::insertFromMimeData( const QMimeData *source ) {
  _QWidgetTextControlPrivate *d = hack_d_func( this );
  
  if(!( d->interactionFlags & Qt::TextEditable ) || !source ) return;

  bool hasData = false, planeText = false;
  QTextDocumentFragment fragment;

  if( source->hasFormat( "application/x-qrichtext" ) && d->acceptRichText ) {
    // x-qrichtext is always UTF-8 (taken from Qt3 since we don't use it anymore).
    QString richtext = QString::fromUtf8( source->data( "application/x-qrichtext" ) );
    richtext.prepend( "<meta name=\"qrichtext\" content=\"1\" />" );
    fragment = QTextDocumentFragment::fromHtml( richtext );
    hasData  = true;
  } 
  else if( source->hasHtml() && d->acceptRichText ) {
    QString html = source->html();
    // Грузим только QT формат, а то заколебало получать не пойми что
    if( html.contains( "<meta name=\"qrichtext\" content=\"1\" />" ) ) {
      fragment = QTextDocumentFragment::fromHtml( html );
      hasData = true;
    }
  }
  if( !hasData && source->hasText() ) {
    QString text = source->text();
    if( !text.isNull() ) {
      fragment = QTextDocumentFragment::fromPlainText( text );
      hasData = planeText = true;
    }
  }

  if( hasData ) {
    QTextDocument *tmpDoc = hack_d_func( &fragment )->doc;

    auto &cursor = d->cursor;
    QTextBlockFormat defBlockFmt = cursor.blockFormat();
    QTextCharFormat  defCharFmt  = cursor.charFormat();

    cursor.beginEditBlock();
    bool firstBlock = true;
    for( QTextBlock block = tmpDoc->begin(); block.isValid(); block = block.next() ) {
      if( firstBlock )
        firstBlock = false; // первый фрагмент вставляем в текущий блок
      else if( planeText )
        cursor.insertBlock();
      else {
        QTextBlockFormat blockFmt( block.blockFormat() );
        RemoveTags( blockFmt );
        QTextCharFormat charFmt( block.charFormat() );
        Validate( charFmt, defCharFmt );
        cursor.insertBlock( blockFmt, charFmt );
      }
      if( block.length() == 1 ) continue; // only a linefeed

      for( auto I = block.begin(); !I.atEnd(); ++I ) {
        const auto frag = I.fragment();
        if (!frag.isValid()) continue;
        if( !planeText ) {
          QTextCharFormat charFmt = frag.charFormat();
          if( Validate( charFmt, defCharFmt ) ) {
            cursor.setCharFormat( charFmt );
          }
        }
        cursor.insertText( frag.text() );
      }
    }

    cursor.endEditBlock();
  }      
  
  ensureCursorVisible();
}


} // namespace Akvis
